#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Simple NixOS Installation Script
################################################################################
# Straightforward installation - no fancy detection, just ask and install
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="${HOSTNAME:-nixos-vm}"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          NixOS Simple Installation                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}Hostname:${NC} $HOSTNAME"
echo -e "${BLUE}Config directory:${NC} $SCRIPT_DIR"
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR:${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Show available disks
echo -e "${GREEN}==> Available disks:${NC}"
lsblk -d -o NAME,SIZE,TYPE | grep disk
echo

# Ask for disk device
echo -e "${YELLOW}Enter the disk device path (e.g., /dev/vda, /dev/sda):${NC}"
read -p "Device: " DISK

# Trim whitespace
DISK=$(echo "$DISK" | xargs)

echo
echo -e "${BLUE}Selected disk:${NC} $DISK"
echo

# Confirm
echo -e "${YELLOW}WARNING: This will DESTROY ALL DATA on $DISK${NC}"
read -p "Type 'yes' to continue: " confirm

if [[ "$confirm" != "yes" ]]; then
    echo -e "${GREEN}Installation cancelled.${NC}"
    exit 0
fi

echo
echo -e "${GREEN}==> Starting installation...${NC}"
echo

# Enable nix experimental features
echo -e "${GREEN}==> Step 1/5: Enabling nix experimental features...${NC}"
mkdir -p /root/.config/nix
echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf

# Update disko-config.nix with selected disk
echo -e "${GREEN}==> Step 2/5: Updating disko configuration...${NC}"
sed -i "s|device = \"/dev/[a-zA-Z0-9]*\";|device = \"$DISK\";|g" "$SCRIPT_DIR/disko-config.nix"
echo "Updated disko-config.nix to use $DISK"

# Run disko
echo
echo -e "${GREEN}==> Step 3/5: Running disko (partitioning and mounting)...${NC}"
echo "This may take a few minutes..."
echo

if ! nix run github:nix-community/disko -- --mode zap_create_mount "$SCRIPT_DIR/disko-config.nix"; then
    echo
    echo -e "${RED}ERROR: Disko failed!${NC}"
    echo "The disk $DISK might be invalid or in use."
    echo "Try running: lsblk"
    exit 1
fi

echo
echo -e "${GREEN}==> Partitioning complete!${NC}"
echo "Mount points:"
mount | grep /mnt

# Copy configuration
echo
echo -e "${GREEN}==> Step 4/5: Copying configuration to /mnt/etc/nixos...${NC}"
mkdir -p /mnt/etc/nixos
cp -r "$SCRIPT_DIR"/* /mnt/etc/nixos/
echo "Configuration copied successfully."

# Install NixOS
echo
echo -e "${GREEN}==> Step 5/5: Installing NixOS...${NC}"
echo "This will take several minutes. Please be patient..."
echo

if ! nixos-install --no-root-password; then
    echo
    echo -e "${RED}ERROR: NixOS installation failed!${NC}"
    echo "Check the error messages above for details."
    exit 1
fi

# Success!
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Installation Complete!                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Installation successful!${NC}"
echo
echo "Next steps:"
echo "  1. Optionally set root password:"
echo -e "     ${BLUE}nixos-enter --root /mnt -c passwd root${NC}"
echo
echo "  2. Reboot into your new system:"
echo -e "     ${BLUE}reboot${NC}"
echo
echo "After reboot, you can rebuild with:"
echo -e "  ${BLUE}sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME${NC}"
echo

