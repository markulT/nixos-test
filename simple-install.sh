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

ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"
HOSTNAME="${HOSTNAME:-nixos-vm}"

# Check if the script directory is read-only (e.g., embedded in ISO)
# If so, copy to a writable location
if [ ! -w "$SCRIPT_DIR" ] || [ ! -w "$SCRIPT_DIR/disko-config.nix" ] 2>/dev/null; then
    echo -e "${BLUE}Config directory is read-only, copying to writable location...${NC}"
    WORK_DIR="/tmp/nixos-config-$$"
    mkdir -p "$WORK_DIR"
    cp -r "$SCRIPT_DIR"/* "$WORK_DIR/"
    chmod -R u+w "$WORK_DIR"
    SCRIPT_DIR="$WORK_DIR"
    echo -e "${GREEN}Working from:${NC} $SCRIPT_DIR"
fi

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
echo -e "${YELLOW}Enter the disk device path (e.g., /dev/vda, /dev/sda) or just the device name (e.g., vda, sda):${NC}"
read -p "Device: " DISK

# Trim whitespace
DISK=$(echo "$DISK" | xargs)

# Normalize disk path: if it doesn't start with /dev/, add it
if [[ ! "$DISK" =~ ^/dev/ ]]; then
    DISK="/dev/$DISK"
fi

# Validate that the device exists
if [[ ! -b "$DISK" ]]; then
    echo -e "${RED}ERROR:${NC} Device $DISK does not exist or is not a block device"
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    exit 1
fi

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

# Check available space (for nixos-install, not for partitioning)
echo -e "${BLUE}Checking available space in installer environment...${NC}"
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE / 1024))
echo "Available space: ${AVAILABLE_SPACE_MB}MB"

if [[ $AVAILABLE_SPACE_MB -lt 200 ]]; then
    echo -e "${YELLOW}WARNING:${NC} Low disk space (${AVAILABLE_SPACE_MB}MB available)"
    echo "Attempting to clean up Nix store..."
    
    # Clean up Nix store if possible
    if command -v nix-collect-garbage &> /dev/null; then
        nix-collect-garbage -d 2>/dev/null || true
    fi
    
    # Check again
    AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE / 1024))
    echo "Available space after cleanup: ${AVAILABLE_SPACE_MB}MB"
    
    if [[ $AVAILABLE_SPACE_MB -lt 150 ]]; then
        echo -e "${YELLOW}WARNING:${NC} Very low disk space (${AVAILABLE_SPACE_MB}MB available)"
        echo "Partitioning will proceed (uses standard tools, no downloads needed)"
        echo "But nixos-install may need more space. Continuing anyway..."
    fi
fi

# Update disko-config.nix with selected disk
echo -e "${GREEN}==> Step 2/5: Updating disko configuration...${NC}"

# Ensure we have an absolute path and the file is writable
DISKO_CONFIG="$SCRIPT_DIR/disko-config.nix"
DISKO_CONFIG=$(readlink -f "$DISKO_CONFIG" 2>/dev/null || echo "$DISKO_CONFIG")

# Verify the file exists and is writable
if [ ! -f "$DISKO_CONFIG" ]; then
    echo -e "${RED}ERROR:${NC} disko-config.nix not found at $DISKO_CONFIG"
    exit 1
fi

if [ ! -w "$DISKO_CONFIG" ]; then
    echo -e "${RED}ERROR:${NC} disko-config.nix is not writable at $DISKO_CONFIG"
    echo "This should not happen if the read-only check worked. Please report this issue."
    exit 1
fi

# Use a safer method: read file, modify in memory, write back
# This avoids sed -i creating temp files in read-only locations
TEMP_FILE=$(mktemp /tmp/disko-config.XXXXXX)
if ! sed "s|device = \"/dev/[^\"]*\";|device = \"$DISK\";|g" "$DISKO_CONFIG" > "$TEMP_FILE"; then
    rm -f "$TEMP_FILE"
    echo -e "${RED}ERROR:${NC} Failed to modify disko-config.nix"
    exit 1
fi

# Replace the original file
if ! mv "$TEMP_FILE" "$DISKO_CONFIG"; then
    rm -f "$TEMP_FILE"
    echo -e "${RED}ERROR:${NC} Failed to update disko-config.nix"
    exit 1
fi

# Verify the replacement worked
if ! grep -q "device = \"$DISK\";" "$SCRIPT_DIR/disko-config.nix"; then
    echo -e "${RED}ERROR:${NC} Failed to update disko-config.nix with device $DISK"
    echo "Current content of disko-config.nix (device line):"
    grep "device = " "$SCRIPT_DIR/disko-config.nix" || echo "  (device line not found)"
    echo "Please check the disko-config.nix file format"
    exit 1
fi

echo "Updated disko-config.nix to use $DISK"

# Manual partitioning (no Nix packages needed!)
echo
echo -e "${GREEN}==> Step 3/5: Partitioning and formatting disk...${NC}"
echo "This will create partitions and filesystems directly (no package downloads needed)"
echo

# Determine partition naming (nvme/mmc use p1, p2; others use 1, 2)
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    BOOT_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    BOOT_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

# Unmount any existing partitions
echo -e "${BLUE}Unmounting any existing partitions...${NC}"
umount "$BOOT_PART" 2>/dev/null || true
umount "$ROOT_PART" 2>/dev/null || true
umount /mnt/boot 2>/dev/null || true
umount /mnt 2>/dev/null || true

# Create partition table and partitions
echo -e "${BLUE}Creating GPT partition table...${NC}"
parted -s "$DISK" mklabel gpt

echo -e "${BLUE}Creating boot partition (512M, EFI)...${NC}"
parted -s "$DISK" mkpart boot fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on  # Mark as EFI System Partition

echo -e "${BLUE}Creating root partition (remaining space)...${NC}"
parted -s "$DISK" mkpart root ext4 513MiB 100%

# Wait for partitions to be available
sleep 2
partprobe "$DISK" 2>/dev/null || true
sleep 1

# Verify partitions exist
if [[ ! -b "$BOOT_PART" ]] || [[ ! -b "$ROOT_PART" ]]; then
    echo -e "${RED}ERROR:${NC} Failed to create partitions"
    echo "Expected partitions: $BOOT_PART and $ROOT_PART"
    lsblk "$DISK"
    exit 1
fi

# Format partitions
echo -e "${BLUE}Formatting boot partition (vfat)...${NC}"
mkfs.vfat -F 32 -n NIXBOOT "$BOOT_PART"

echo -e "${BLUE}Formatting root partition (ext4)...${NC}"
mkfs.ext4 -F -L NIXROOT "$ROOT_PART"

# Create mount points and mount
echo -e "${BLUE}Mounting filesystems...${NC}"
# Mount root first
mount "$ROOT_PART" /mnt
# Then create boot directory inside the mounted root
mkdir -p /mnt/boot
# Finally mount boot partition
mount "$BOOT_PART" /mnt/boot

echo -e "${GREEN}Partitioning and mounting complete!${NC}"
echo "Labels set: NIXBOOT (boot) and NIXROOT (root)"
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

