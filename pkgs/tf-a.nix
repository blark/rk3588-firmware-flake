# pkgs/tf-a.nix — Minimal TF-A build for RK3588.
# Rationale:
# - Pin repo + commit for reproducibility.
# - Use GCC as assembler to avoid binutils AS flag drift.
# - Install only BL31 to keep the store small.
{ stdenv, fetchgit, gcc, dtc }:

stdenv.mkDerivation {
  pname = "tf-a-rk3588";
  version = "unstable";

  src = fetchgit {
    url = "https://gitlab.collabora.com/hardware-enablement/rockchip-3588/trusted-firmware-a.git";
    rev = "049971ce2782633725c0350f0c607b923077c955";     # pin exact commit
    sha256 = "sha256-vgisUSH/SEzxGQaPdWZczx8M7cgIaMmmM0BvhyzV33M="; # replace with real SRI hash
    fetchSubmodules = true;                                 # TF-A occasionally uses submodules
  };

  # TF-A only needs a C toolchain and DTC.
  nativeBuildInputs = [ gcc dtc ];

  # GCC as AS avoids AS flags incompatibilities; PLAT selects RK3588; only build BL31.
  makeFlags  = [ "PLAT=rk3588" "AS=${gcc}/bin/gcc" ];
  buildFlags = [ "bl31" ];

  installPhase = ''
    mkdir -p $out
    cp build/rk3588/release/bl31/bl31.elf $out/
  '';
}
