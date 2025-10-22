# NixOS Automated Installation Guide

This repository contains automated installation scripts for NixOS using disko for partition management.

## Super Quick Start (Recommended)

### One-Command Installation

1. Boot into NixOS installer

2. Get this configuration on the installer (choose one method):
   
   **Clone via Git:**
   ```bash
   nix-shell -p git
   git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /tmp/nixos-config
   cd /tmp/nixos-config
   ```
   
   **Or HTTP Server (no SSH, no git needed):**
   
   On your host:
   ```bash
   cd /path/to/this/repo
   python3 -m http.server 8000
   ```
   
   In the installer:
   ```bash
   wget -r -np -nH --cut-dirs=0 http://HOST_IP:8000/
   cd NixOS-server-configuration
   ```

3. Run the installation:
   ```bash
   sudo ./quick-install.sh
   ```
   
   That's it! The script will:
   - ✅ Auto-detect your disk (or you can specify: `sudo ./quick-install.sh /dev/vda`)
   - ✅ Run disko to partition and mount
   - ✅ Copy configuration to the new partition
   - ✅ Install NixOS
   - ✅ Done!

4. After installation completes, reboot:
   ```bash
   reboot
   ```

## Alternative Methods

### Method 1: Using the Full Installation Script

1. Boot into NixOS installer
2. Enable nix experimental features:
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
   ```

3. Get this repository on the installer:
   
   **Option A: Clone via Git (if internet available)**
   ```bash
   git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /tmp/nixos-config
   cd /tmp/nixos-config
   ```
   
   **Option B: HTTP Server (no SSH needed)**
   
   On your host machine:
   ```bash
   cd /path/to/this/repo
   python3 -m http.server 8000
   ```
   
   In the VM installer:
   ```bash
   # Replace HOST_IP with your host machine's IP
   wget -r -np -nH --cut-dirs=0 http://HOST_IP:8000/
   cd NixOS-server-configuration
   ```
   
   **Option C: USB Drive**
   - Copy this repo to a USB drive
   - Mount it in the VM and copy files

4. Run the installation script:
   ```bash
   sudo ./install.sh
   ```
   
   Or with custom options:
   ```bash
   # Specify disk and hostname
   sudo ./install.sh --disk /dev/nvme0n1 --hostname my-server
   
   # Skip confirmation prompt (use with caution!)
   sudo ./install.sh --no-confirm
   
   # Clone from remote repository
   sudo ./install.sh --repo https://github.com/user/nixos-config.git
   ```

5. Reboot and enjoy your new system!

### Method 2: Manual Installation

If you prefer to run commands manually:

1. Enable nix experimental features:
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
   ```

2. Get configuration files (see Method 1, step 3)

3. Run disko to partition and mount:
   ```bash
   sudo nix run github:nix-community/disko -- \
       --mode zap_create_mount \
       disko-config.nix
   ```

4. Copy configuration to target:
   ```bash
   sudo mkdir -p /mnt/etc/nixos
   sudo cp -r ./* /mnt/etc/nixos/
   ```

5. Install NixOS:
   ```bash
   sudo nixos-install --flake /mnt/etc/nixos#nixos-vm
   ```

6. Set root password when prompted

7. Reboot:
   ```bash
   sudo reboot
   ```

## Configuration Details

### Disk Layout (disko-config.nix)

- **Boot partition**: 512MB, EFI (vfat)
- **Root partition**: Remaining space, ext4

Default disk: `/dev/sda`

To change the disk device, either:
- Use the `--disk` flag with the install script
- Edit `disko-config.nix` and change the `device` field

### System Configuration

- **Default hostname**: `nixos-vm`
- **Default user**: `alice`
- **Desktop environment**: Hyprland (Wayland)
- **Display manager**: greetd with tuigreet
- **Shell**: fish
- **Virtualization**: Docker, VMware guest tools

## Troubleshooting

### "No space left on device" error

This usually happens when:
1. Previous installation failed and filled up the installer's filesystem
2. Trying to install on the wrong partition

**Solution**: Clean up failed installation:
```bash
sudo rm -rf /mnt/nixos
sudo rm -rf /tmp/nixos-*
sudo umount -R /mnt 2>/dev/null || true
sudo nix-collect-garbage -d
```

### "Experimental feature 'nix-command' is disabled"

**Solution**: Enable experimental features:
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
```

Or run commands with the flag:
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko ...
```

### SSH Key Issues with Shared Clipboard

Instead of using SSH, try:
1. **HTTP server method** (see Quick Start)
2. **USB drive** to transfer files
3. **Git clone** directly in the installer

### Wrong Disk Device

Check available disks:
```bash
lsblk
```

Common disk devices:
- SATA/SCSI: `/dev/sda`, `/dev/sdb`, etc.
- NVMe: `/dev/nvme0n1`, `/dev/nvme1n1`, etc.
- VirtIO (VMs): `/dev/vda`, `/dev/vdb`, etc.

## Post-Installation

After booting into your new system:

### Update the system:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-vm
```

### Update flake inputs:
```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake .#nixos-vm
```

### Add yourself to the system:
Edit `/etc/nixos/configuration.nix` and modify the user configuration, then rebuild.

## Customization

### Change Disk Layout

Edit `disko-config.nix` to modify:
- Partition sizes
- Filesystem types
- Add swap partition
- Add more partitions

Example with swap:
```nix
swap = {
  size = "8G";
  content = {
    type = "swap";
  };
};
```

### Change System Configuration

Edit `configuration.nix` to:
- Add/remove packages
- Change system services
- Modify user accounts
- Configure networking

Then rebuild:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-vm
```

## Script Options

The `install.sh` script supports the following options:

```
-h, --help              Show help message
-d, --disk DEVICE       Specify disk device (default: /dev/sda)
-r, --repo URL          Git repository URL for configuration
-n, --hostname NAME     Hostname for the system (default: nixos-vm)
--no-confirm            Skip confirmation prompt (dangerous!)
```

Environment variables:
- `DISK_DEVICE`: Disk to install to
- `CONFIG_REPO`: Git repository URL
- `HOSTNAME`: System hostname

## Security Notes

- The script requires root privileges
- It will **DESTROY ALL DATA** on the target disk
- Always double-check the disk device before running
- Set a strong root password after installation
- Consider setting up user passwords in the configuration

## Contributing

Feel free to modify this configuration for your needs. The main files are:
- `flake.nix`: Flake configuration and inputs
- `configuration.nix`: System configuration
- `disko-config.nix`: Disk partitioning layout
- `home.nix`: Home-manager user configuration
- `firewall.nix`: Firewall rules
- `install.sh`: Automated installation script

