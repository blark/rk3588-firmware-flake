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

    # Disable default environment storage and enable SPI flash
    sed -i '/CONFIG_ENV_IS_NOWHERE/d' .config
    sed -i '/CONFIG_ENV_IS_IN_MMC/d' .config
    sed -i '/CONFIG_ENV_IS_IN_FAT/d' .config
    sed -i '/CONFIG_ENV_IS_IN_EXT4/d' .config

    cat >> .config <<'EOF'
CONFIG_CMD_WGET=y
CONFIG_PCI_INIT_R=y
CONFIG_PROT_TCP_SACK=y
# Network console for remote access
CONFIG_NETCONSOLE=y
CONFIG_NETCONSOLE_BUFFER_SIZE=512
# Console multiplexing for multiple devices (serial,nc)
CONFIG_CONSOLE_MUX=y
CONFIG_SYS_CONSOLE_IS_IN_ENV=y
# Allow overwriting protected environment variables
CONFIG_ENV_OVERWRITE=y
# Longer boot delay for netconsole setup
CONFIG_BOOTDELAY=10
# Environment storage in SPI flash
# CONFIG_ENV_IS_NOWHERE is not set
# CONFIG_ENV_IS_IN_MMC is not set
# CONFIG_ENV_IS_IN_FAT is not set
# CONFIG_ENV_IS_IN_EXT4 is not set
CONFIG_ENV_IS_IN_SPI_FLASH=y
CONFIG_SYS_REDUNDAND_ENVIRONMENT=y
CONFIG_ENV_OFFSET=0x3f0000
CONFIG_ENV_OFFSET_REDUND=0x3f8000
CONFIG_ENV_SIZE=0x8000
CONFIG_ENV_SECT_SIZE=0x1000
# Boot configuration
CONFIG_USE_BOOTCOMMAND=y
CONFIG_BOOTCOMMAND="dhcp; wget 0x60000000 ''${fit}; bootm"
CONFIG_USE_PREBOOT=y
CONFIG_PREBOOT="setenv autoload no; setenv serverip 192.168.1.83; setenv httpdstp 8080; setenv fit /rock5b.fit"
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
