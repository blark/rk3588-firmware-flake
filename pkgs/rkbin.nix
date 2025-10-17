# pkgs/rkbin.nix — Build rkbin artifacts via the vendor tool on x86_64-linux.
# Notes:
# - boot_merger is a Python wrapper that shells out; ensure it’s runnable.
# - autoPatchelfHook + glibc/zlib help when upstream ships ELF helpers.
# - We run the merge in buildPhase, then install just the useful outputs.
{ stdenv, fetchgit, python3, autoPatchelfHook, glibc, zlib }:

stdenv.mkDerivation {
  pname = "rkbin-rk3588";
  version = "unstable";

  src = fetchgit {
    url = "https://gitlab.collabora.com/hardware-enablement/rockchip-3588/rkbin.git";
    #rev = "7c35e21";
    #sha256 = "sha256-KBmO++Z1AfIKvAmx7CzXScww16Stvq2BWr2raPiR6Q8=";
    rev = "74213af1e952c4683d2e35952507133b61394862";
    sha256 = "sha256-gNCZwJd9pjisk6vmvtRNyGSBFfAYOADTa5Nd6Zk+qEk=";
  };

  nativeBuildInputs = [ python3 autoPatchelfHook ];
  buildInputs = [ glibc zlib ];

  patchPhase = ''
    patchShebangs tools/boot_merger
  '';

  buildPhase = ''
    ./tools/boot_merger RKBOOT/RK3588MINIALL.ini
  '';

  installPhase = ''
    mkdir -p $out
    cp -v bin/rk35/rk3588_*.bin $out/
    cp -v rk3588_spl_loader* $out/
  '';
}
