# flake.nix — Single flake, multiple packages. Darwin only *aliases* Linux builds to
# force remote aarch64-linux builders (keeps toolchains consistent and reproducible).
{
  description = "RK3588 firmware toolchain (TF-A, rkbin, U-Boot)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # Old nixpkgs for GCC 11 (needed for TF-A - newer GCC breaks CPU init)
  inputs.nixpkgs-gcc11.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs, nixpkgs-gcc11 }:
  let
    # We intentionally build everything with Linux toolchains:
    pkgsA64 = nixpkgs.legacyPackages."aarch64-linux";
    pkgsX86 = nixpkgs.legacyPackages."x86_64-linux";
    # Old nixpkgs for GCC 11 (TF-A needs it)
    pkgsGcc11 = nixpkgs-gcc11.legacyPackages."aarch64-linux";

    # Derivations are defined in pkgs/*.nix; we pass in the toolchains they must use.
    linuxPkgs = import ./pkgs {
      inherit pkgsA64 pkgsX86 pkgsGcc11;
    };
  in
  {
    # Real builds live here (aarch64-linux). Mac users will offload to a remote builder.
    packages."aarch64-linux" = linuxPkgs // {
      # Make `nix build .` do something obvious.
      default = linuxPkgs.tf-a;
    };

    # On macOS, expose the same outputs but *point at the Linux derivations*.
    # This avoids accidental Darwin-native builds and enforces the Linux toolchain.
    packages."aarch64-darwin" = {
      tf-a   = self.packages."aarch64-linux".tf-a;
      rkbin  = self.packages."aarch64-linux".rkbin;
      uboot  = self.packages."aarch64-linux".uboot;
      default = self.packages."aarch64-linux".tf-a;
    };
  };
}
