# RK3588 (Rock 5B) Firmware – Nix Flake

Minimal, reproducible builds for Rock 5B firmware components:

* **tf-a** — ARM Trusted Firmware-A (BL31)
* **rkbin** — Rockchip DDR/TPL blobs & tools
* **uboot** — U-Boot for Rock 5B integrated with TF-A + rkbin

Builds for Linux/ARM64 (tf-a, uboot) and Linux/x86_64 (rkbin); macOS aliases to Linux outputs and offloads to remote builders.

![Rock 5B U-Boot](rock5b-uboot.png)

---

## Requirements

* Nix with Flakes enabled
* Remote builders: `aarch64-linux` (tf-a, uboot) and `x86_64-linux` (rkbin)

> Configuring Nix remote builders is beyond the scope of this document. See the [Nix manual](https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html) for details.

---

## Quick start

```bash
# Build all required components in one command
nix build .#tf-a .#rkbin .#uboot

# Outputs
ls result*
```

> Files needed for flashing: `result-1/rk3588_spl_loader_v1.19.113.bin` (rkbin) and `result-2/u-boot-rockchip-spi.bin` (uboot)

---

## Customization

Add U-Boot configuration options in `pkgs/uboot.nix` by modifying the `configurePhase`:

```nix
# Base defconfig + minimal tweaks; use Kconfig to resolve deps
configurePhase = ''
  make rock5b-rk3588_defconfig
  cat >> .config <<EOF
  CONFIG_CMD_WGET=y
  CONFIG_PCI_INIT_R=y
  EOF
  make olddefconfig
'';
```

---

## Flashing

Put the Rock 5B into Maskrom mode, then use [rkdeveloptool](https://github.com/rockchip-linux/rkdeveloptool):

```bash
# List devices (verify Maskrom mode)
sudo ./rkdeveloptool ld
# DevNo=1 Vid=0x2207,Pid=0x350b,LocationID=103    Maskrom

# Clear SPI (only needed after failed flash)
sudo ./rkdeveloptool ef

# Download bootloader to Rock 5B
sudo ./rkdeveloptool db result-1/rk3588_spl_loader_v1.19.113.bin

# Write U-Boot image to SPI
sudo ./rkdeveloptool wl 0 result-2/u-boot-rockchip-spi.bin

# Reset device (reboot to normal mode)
sudo ./rkdeveloptool rd
```

---

## Layout

```
flake.nix
pkgs/
  default.nix   # wires packages and toolchains
  tf-a.nix      # builds BL31
  rkbin.nix     # builds rkbin on x86_64-linux
  uboot.nix     # builds U-Boot; passes BL31/ROCKCHIP_TPL/SWIG to build
```

---

## Acknowledgments

* [yrzr's Rock 5B U-Boot build notes](https://yrzr.github.io/notes-build-uboot-for-rock5b/#fn:6) for guidance on the build process
* [Collabora](https://www.collabora.com/) for their hardware enablement and U-Boot work on RK3588
