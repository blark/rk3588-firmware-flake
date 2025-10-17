# pkgs/uboot.nix — U-Boot for Rock 5B (RK3588)
#
# Purpose:
#   Build a reproducible U-Boot image wired to:
#     - TF-A (BL31) from our tf-a derivation
#     - rkbin DDR/TPL blob from our rkbin derivation
#
# Why these choices:
#   - swig: rebuild dtc/pylibfdt bindings (U-Boot calls SWIG during build)
#   - pkg-config + gnutls: CONFIG_CMD_WGET needs TLS headers/libs discovered via pkg-config
#   - BL31/ROCKCHIP_TPL: pass exact firmware paths for reproducible images
#
# Notes:
#   Disable CONFIG_CMD_WGET if TLS is not needed and drop pkg-config + gnutls.

{ stdenv, fetchgit, gcc, bison, flex, python3, python3Packages
, bc, openssl, dtc, which, swig, pkg-config, gnutls
, tf-a, rkbin }:

stdenv.mkDerivation {
  pname = "uboot-rock5b-rk3588";
  version = "2024.01";

  # Pinned source ensures deterministic builds
  src = fetchgit {
    url = "https://gitlab.collabora.com/hardware-enablement/rockchip-3588/u-boot.git";
    rev = "79dc2821375cdb0004e1bdb34a36188f89c6f548";
    sha256 = "sha256-FffrKos8Wb0Ylq8Sn9+jezn4u7+ItUVw/ZIjJwPZhUE=";
    fetchSubmodules = true;
  };

  # Host tools used by the build system (not linked into target image)
  nativeBuildInputs = [
    gcc bison flex
    python3 python3Packages.setuptools python3Packages.pyelftools
    bc openssl dtc which
    swig
    pkg-config
  ];

  # Libraries required when CONFIG_CMD_WGET=y (TLS)
  buildInputs = [ gnutls ];

  # Remove stale SWIG outputs and force binman to use python3
  postPatch = ''
    rm -f scripts/dtc/pylibfdt/libfdt_wrap.c scripts/dtc/pylibfdt/libfdt.py || true
    patchShebangs tools scripts
    sed -i 's|\./tools/binman/binman|${python3}/bin/python3 &|g' Makefile
    sed -i 's|\$(srctree)/tools/binman/binman|${python3}/bin/python3 &|g' Makefile
  '';

  # Pass exact firmware and tool paths via environment variables
  preConfigure = ''
    export BL31=${tf-a}/bl31.elf
    export ROCKCHIP_TPL=${rkbin}/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin
    export SWIG=${swig}/bin/swig
  '';

  # Base defconfig + minimal tweaks; use Kconfig to resolve deps
  configurePhase = ''
    make rock5b-rk3588_defconfig
    cat >> .config <<EOF
    CONFIG_CMD_WGET=y
    CONFIG_PCI_INIT_R=y
    EOF
    make olddefconfig
  '';

  # Build using explicit firmware paths and swig binary
  buildPhase = ''
    make -j$NIX_BUILD_CORES \
      BL31=${tf-a}/bl31.elf \
      ROCKCHIP_TPL=${rkbin}/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin \
      SWIG=${swig}/bin/swig
  '';

  # Copy expected artifacts into $out; tolerate missing variants
  installPhase = ''
    mkdir -p $out
    cp -v u-boot.bin u-boot.itb $out/ || true
    cp -v u-boot-rockchip*.bin $out/ || true
    cp -v idbloader.img $out/ || true
  '';
}
