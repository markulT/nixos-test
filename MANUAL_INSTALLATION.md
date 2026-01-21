# Manual Installation Steps

This guide covers manual installation steps when the automated script encounters issues (e.g., mounting errors).

## Prerequisites

- Partitions have been created successfully (verify with `lsblk`)
- You're booted into the NixOS installer ISO
- You have root/sudo access

## Step-by-Step Manual Installation

### 1. Mount the Partitions

```bash
# Mount root partition first
mount /dev/vda2 /mnt

# Create boot directory inside mounted root, then mount boot
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot

# Verify mounts are correct
mount | grep /mnt
```

You should see both `/mnt` and `/mnt/boot` mounted.

### 2. Copy the Configuration

```bash
# Find your config (should be in /etc/nixos-config)
ls -la /etc/nixos-config/

# Copy to the mounted system
mkdir -p /mnt/etc/nixos
cp -r /etc/nixos-config/* /mnt/etc/nixos/

# Verify files were copied
ls -la /mnt/etc/nixos/
```

### 3. Fix Configuration Issues

#### Remove Invalid Options

```bash
# Remove the invalid hardware.graphics option (not available in NixOS 24.05)
sudo sed -i '/hardware.graphics = {/,/};/d' /mnt/etc/nixos/configuration.nix

# Fix the font packages (nerd-fonts doesn't exist, use nerdfonts)
sudo sed -i 's/pkgs\.nerd-fonts\.droid-sans-mono/nerdfonts/g' /mnt/etc/nixos/configuration.nix
sudo sed -i 's/pkgs\.nerd-fonts\._0xproto//g' /mnt/etc/nixos/configuration.nix
```

#### Fix Bootloader (UEFI vs BIOS)

**For UEFI (default - recommended):**
The configuration already uses `systemd-boot` which is correct for UEFI. No changes needed.

**For BIOS (SeaBIOS):**
If your VM uses BIOS instead of UEFI, you need to change the bootloader:

```bash
# Edit the configuration
sudo nano /mnt/etc/nixos/configuration.nix
```

Find this section:
```nix
  # 1. --- BOOTLOADER ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
```

Replace it with:
```nix
  # 1. --- BOOTLOADER ---
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";  # Device-agnostic for BIOS
  boot.loader.grub.efiSupport = false;  # Disable EFI support for BIOS
  boot.loader.grub.useOSProber = true;
```

**Or use sed to fix it automatically:**
```bash
# Replace systemd-boot with GRUB
sudo sed -i 's/boot.loader.systemd-boot.enable = true;/boot.loader.grub.enable = true;/g' /mnt/etc/nixos/configuration.nix

# Replace EFI line with GRUB BIOS settings (manual edit is easier)
sudo sed -i 's/boot.loader.efi.canTouchEfiVariables = true;/boot.loader.grub.device = "nodev";/g' /mnt/etc/nixos/configuration.nix
# Then manually add: boot.loader.grub.efiSupport = false; after the device line
```

**Alternative: If you want to specify the exact device:**
```nix
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-VIRTUAL_DISK";  # Use disk ID
  # Or
  boot.loader.grub.device = "/dev/vda";  # Direct device (if you're sure)
```

### 4. Verify disko-config.nix

```bash
# Make sure it uses the correct disk device
grep device /mnt/etc/nixos/disko-config.nix
```

Should show: `device = "/dev/vda";` (or your disk device)

### 5. Install NixOS

```bash
# Run the installation
nixos-install --no-root-password
```

This will take several minutes. The installation will:
- Build the system configuration
- Install packages
- Set up the bootloader
- Create the system

### 6. Post-Installation

#### Set Root Password (Optional)

```bash
nixos-enter --root /mnt -c passwd root
```

#### Reboot

```bash
reboot
```

After reboot, you should boot into your new NixOS system!

## Troubleshooting

### "mount: /mnt/boot: mount point does not exist"

This happens when you try to mount boot before mounting root. Solution:
1. Mount root first: `mount /dev/vda2 /mnt`
2. Create boot directory: `mkdir -p /mnt/boot`
3. Mount boot: `mount /dev/vda1 /mnt/boot`

### "The option 'hardware.graphics' does not exist"

This option was removed in NixOS 24.05. Remove it from configuration:
```bash
sudo sed -i '/hardware.graphics = {/,/};/d' /mnt/etc/nixos/configuration.nix
```

### "error: attribute 'nerd-fonts' missing"

Use `nerdfonts` instead:
```bash
sudo sed -i 's/pkgs\.nerd-fonts\./nerdfonts/g' /mnt/etc/nixos/configuration.nix
```

### System Stuck at Boot

If the system hangs at boot, it's likely a bootloader issue:
- **BIOS boot** requires GRUB (not systemd-boot)
- **UEFI boot** can use systemd-boot or GRUB

Check your VM firmware settings and match the bootloader accordingly.

### Verify Partition Layout

```bash
# Check partitions
lsblk

# Check filesystem labels
ls -la /dev/disk/by-label/
```

Should show:
- `NIXBOOT` → boot partition
- `NIXROOT` → root partition

## Quick Reference

```bash
# Complete manual installation (after partitions are created)
mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot
cp -r /etc/nixos-config/* /mnt/etc/nixos/
sudo sed -i '/hardware.graphics = {/,/};/d' /mnt/etc/nixos/configuration.nix
sudo sed -i 's/pkgs\.nerd-fonts\./nerdfonts/g' /mnt/etc/nixos/configuration.nix
# Fix bootloader if using BIOS (see step 3 above)
nixos-install --no-root-password
nixos-enter --root /mnt -c passwd root  # Optional
reboot
```

