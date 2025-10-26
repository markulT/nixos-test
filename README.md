# NixOS Server Configuration

Automated NixOS installation with disko partitioning.

## Quick Install

Boot into NixOS installer and run:

```bash
# Get this repo (or use wget/USB)
nix-shell -p git
git clone <YOUR_REPO_URL> /tmp/nixos-config
cd /tmp/nixos-config

# One command to install everything
sudo ./quick-install.sh
```

The script will:
1. Show interactive disk selection menu
2. Run disko to create partitions
3. Mount the new filesystem
4. Copy this config to `/mnt/etc/nixos`
5. Run `nixos-install`

Then just `reboot`!

## What's Included

- **Hyprland** - Wayland compositor
- **greetd** - Display manager
- **Docker** - Containerization
- **fish** - Modern shell
- **Home Manager** - Dotfile management
- **VMware Guest Tools** - For VM integration

## Customization

Edit these files before running the install:

- `configuration.nix` - System configuration
- `disko-config.nix` - Disk layout (default: 512M boot + rest for root)
- `home.nix` - User configuration
- `firewall.nix` - Firewall rules

## Disk Selection

The installer shows an interactive menu:

```
Available disks:
No  Device        Size     Description
--- ------        ----     -----------
1   /dev/vda      20G      VirtIO (VM)
2   /dev/sda      500G     SATA/SCSI

Choose installation disk:
  [1-2] Select from list above
  [m] Manual input (type device path)
  [l] List disks again
  [q] Quit
```

Or specify manually:
```bash
sudo ./quick-install.sh /dev/nvme0n1
```

## Post-Install

After reboot, rebuild the system:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-vm
```

Update packages:
```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake .#nixos-vm
```

## Recovery Mode

If something goes wrong during installation, reset without rebooting:

```bash
# Reset everything to start fresh
sudo ./reset-installation.sh

# Then try again
sudo ./quick-install.sh
```

## Files

- `quick-install.sh` - One-command installer (recommended)
- `reset-installation.sh` - Reset failed installation (no reboot needed!)
- `install.sh` - Full-featured installer with more options
- `INSTALLATION.md` - Detailed installation guide
- `configuration.nix` - Main system config
- `disko-config.nix` - Disk partitioning
- `flake.nix` - Flake configuration
- `home.nix` - Home Manager config
- `firewall.nix` - Firewall rules

## Troubleshooting

See [INSTALLATION.md](INSTALLATION.md) for detailed troubleshooting.

Common issues:
- **Wrong disk**: Script auto-detects, or specify manually
- **No space**: Run `sudo nix-collect-garbage -d` in installer
- **Permission errors**: Always use `sudo`

## License

Feel free to use and modify for your own systems.

