# pkgs/default.nix — Central wiring. Keeps imports small and dependencies explicit.
# Each sub-file is a minimal, focused derivation.
{ pkgsA64, pkgsX86 }:

let
  # TF-A is pure aarch64 build.
  tf-a  = pkgsA64.callPackage ./tf-a.nix { };

  # rkbin provides Rockchip blobs/tools; tool is x86-only, so we build it on x86_64-linux.
  rkbin = pkgsX86.callPackage ./rkbin.nix { };

  # U-Boot needs both TF-A (BL31 path) and rkbin (DDR/TPL). We pass them in explicitly.
  uboot = pkgsA64.callPackage ./uboot.nix {
    inherit tf-a rkbin;
  };
in {
  inherit tf-a rkbin uboot;
}
