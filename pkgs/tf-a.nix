# pkgs/tf-a.nix — Minimal TF-A build for RK3588.
# Rationale:
# - Pin repo + commit for reproducibility.
# - MUST use GCC 11 (newer GCC breaks CPU initialization).
# - Use native aarch64-linux gcc.
# - Install only BL31 to keep the store small.
{ lib, stdenv, fetchgit, dtc, gcc }:

let
  gitRev = "049971ce2782633725c0350f0c607b923077c955";
  shortRev = lib.substring 0 8 gitRev;
in
stdenv.mkDerivation {
  pname = "tf-a-rk3588";
  version = "unstable";

  # Disable all Nix hardening - it can break bare-metal firmware
  hardeningDisable = [ "all" ];

  # Disable fixup phases that might strip or modify the firmware binary
  dontStrip = true;
  dontPatchELF = true;

  src = fetchgit {
    url = "https://gitlab.collabora.com/hardware-enablement/rockchip-3588/trusted-firmware-a.git";
    rev = gitRev;
    sha256 = "sha256-vgisUSH/SEzxGQaPdWZczx8M7cgIaMmmM0BvhyzV33M="; # replace with real SRI hash
    fetchSubmodules = true;                                 # TF-A occasionally uses submodules
  };

  # TF-A needs gcc and DTC.
  # Using native aarch64-linux gcc (not bare-metal cross-compiler)
  nativeBuildInputs = [ gcc dtc ];

  # Clear potentially problematic environment variables from Nix stdenv
  # Keep CC since we're setting it explicitly in makeFlags
  preBuild = ''
    unset CFLAGS CXXFLAGS LDFLAGS NIX_CFLAGS_COMPILE NIX_LDFLAGS
    unset CPP AS AR LD OC OD

    # Set build identifier (shows in BL31 boot banner)
    export BUILD_STRING="${shortRev}-nix-$(date +%Y%m%d)"
  '';

  # PLAT selects RK3588; only build BL31.
  # Explicitly set CC=gcc to use native compiler (we're building on aarch64-linux)
  # This overrides TF-A's default of trying aarch64-none-elf-gcc first
  makeFlags  = [
    "PLAT=rk3588"
    "CC=gcc"
  ];
  buildFlags = [ "bl31" ];

  installPhase = ''
    mkdir -p $out
    cp build/rk3588/release/bl31/bl31.elf $out/
  '';
}
