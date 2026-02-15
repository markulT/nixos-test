# Bootloader Configuration

This configuration supports both **Legacy BIOS** and **UEFI** boot modes.

## How to Choose

Edit `configuration.nix` and uncomment the bootloader you want:

```nix
imports = [
  ./hardware-configuration.nix
  ./firewall.nix
  # Choose your bootloader (comment/uncomment one):
  ./bootloader-bios.nix   # For VirtualBox/KVM on Linux hosts (Legacy BIOS)
  # ./bootloader-efi.nix  # For Windows/macOS hosts or modern UEFI systems
];
```

## Which One Should I Use?

### Use `bootloader-bios.nix` (Legacy BIOS) if:
- ✅ You're running on **VirtualBox on Linux** (Fedora, Ubuntu, etc.)
- ✅ You're running on **KVM/virt-manager**
- ✅ You experience boot freezes or "No bootable device" errors with EFI

### Use `bootloader-efi.nix` (UEFI) if:
- ✅ You're running on **VirtualBox on Windows or macOS**
- ✅ You're installing on **real hardware** (most modern PCs)
- ✅ You want to dual-boot with Windows

## Switching Between Them

To switch after installation:

1. Edit `/etc/nixos/configuration.nix`
2. Comment out the current bootloader and uncomment the other one
3. Run: `sudo nixos-rebuild switch`
4. Reboot

**Note:** When switching from BIOS→EFI or EFI→BIOS, you may need to reinstall the system as the disk partition layout differs between the two modes.
