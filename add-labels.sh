#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Add Filesystem Labels to Existing Partitions
################################################################################
# This script adds NIXBOOT and NIXROOT labels to existing partitions
# Use this if you installed without labels and don't want to reinstall
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Add Filesystem Labels                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR:${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Show available disks and partitions
echo -e "${GREEN}==> Available disks and partitions:${NC}"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
echo

# Ask for boot partition
echo -e "${YELLOW}Enter the boot partition path (e.g., /dev/vda1):${NC}"
read -p "Boot partition: " BOOT_PART
BOOT_PART=$(echo "$BOOT_PART" | xargs)

if [[ ! "$BOOT_PART" =~ ^/dev/ ]]; then
    BOOT_PART="/dev/$BOOT_PART"
fi

if [[ ! -b "$BOOT_PART" ]]; then
    echo -e "${RED}ERROR:${NC} Device $BOOT_PART does not exist"
    exit 1
fi

# Ask for root partition
echo -e "${YELLOW}Enter the root partition path (e.g., /dev/vda2):${NC}"
read -p "Root partition: " ROOT_PART
ROOT_PART=$(echo "$ROOT_PART" | xargs)

if [[ ! "$ROOT_PART" =~ ^/dev/ ]]; then
    ROOT_PART="/dev/$ROOT_PART"
fi

if [[ ! -b "$ROOT_PART" ]]; then
    echo -e "${RED}ERROR:${NC} Device $ROOT_PART does not exist"
    exit 1
fi

echo
echo -e "${BLUE}Boot partition:${NC} $BOOT_PART"
echo -e "${BLUE}Root partition:${NC} $ROOT_PART"
echo

# Get filesystem types
BOOT_FS=$(blkid -o value -s TYPE "$BOOT_PART" || echo "unknown")
ROOT_FS=$(blkid -o value -s TYPE "$ROOT_PART" || echo "unknown")

echo -e "${BLUE}Detected filesystems:${NC}"
echo "  Boot: $BOOT_FS"
echo "  Root: $ROOT_FS"
echo

# Validate filesystem types
if [[ "$BOOT_FS" != "vfat" ]]; then
    echo -e "${RED}ERROR:${NC} Boot partition is not vfat (detected: $BOOT_FS)"
    echo "Expected boot partition to be vfat. Please verify partition selection."
    exit 1
fi

if [[ "$ROOT_FS" != "ext4" ]]; then
    echo -e "${RED}ERROR:${NC} Root partition is not ext4 (detected: $ROOT_FS)"
    echo "Expected root partition to be ext4. Please verify partition selection."
    exit 1
fi

# Confirm
echo -e "${YELLOW}This will set the following labels:${NC}"
echo "  $BOOT_PART -> NIXBOOT"
echo "  $ROOT_PART -> NIXROOT"
echo
read -p "Continue? (type 'yes'): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo -e "${GREEN}Cancelled.${NC}"
    exit 0
fi

echo
echo -e "${GREEN}==> Adding labels...${NC}"

# Check if partitions are mounted and warn
if mount | grep -q "$BOOT_PART"; then
    echo -e "${YELLOW}WARNING:${NC} Boot partition is mounted. Unmounting..."
    umount "$BOOT_PART" || {
        echo -e "${RED}ERROR:${NC} Failed to unmount $BOOT_PART"
        echo "Please unmount manually and run again"
        exit 1
    }
fi

if mount | grep -q "$ROOT_PART"; then
    echo -e "${YELLOW}WARNING:${NC} Root partition is mounted. This is okay for ext4 labeling."
fi

# Add label to boot partition (vfat)
echo -e "${BLUE}Setting boot partition label to NIXBOOT...${NC}"
if ! fatlabel "$BOOT_PART" NIXBOOT; then
    echo -e "${RED}ERROR:${NC} Failed to set boot partition label"
    exit 1
fi

# Add label to root partition (ext4)
# ext4 can be labeled while mounted
echo -e "${BLUE}Setting root partition label to NIXROOT...${NC}"
if ! e2label "$ROOT_PART" NIXROOT; then
    echo -e "${RED}ERROR:${NC} Failed to set root partition label"
    exit 1
fi

# Verify labels
echo
echo -e "${GREEN}==> Verifying labels...${NC}"
BOOT_LABEL=$(blkid -o value -s LABEL "$BOOT_PART" || echo "")
ROOT_LABEL=$(blkid -o value -s LABEL "$ROOT_PART" || echo "")

if [[ "$BOOT_LABEL" == "NIXBOOT" ]]; then
    echo -e "${GREEN}✓${NC} Boot partition label: $BOOT_LABEL"
else
    echo -e "${RED}✗${NC} Boot partition label: $BOOT_LABEL (expected NIXBOOT)"
fi

if [[ "$ROOT_LABEL" == "NIXROOT" ]]; then
    echo -e "${GREEN}✓${NC} Root partition label: $ROOT_LABEL"
else
    echo -e "${RED}✗${NC} Root partition label: $ROOT_LABEL (expected NIXROOT)"
fi

# Show final status
echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$BOOT_PART" "$ROOT_PART"

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Labels Added Successfully!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo "Next steps:"
echo "  1. Reboot the system"
echo "  2. The system should now boot using the labeled partitions"
echo
echo "If you're in the installer environment:"
echo "  1. Remount the partitions:"
echo "     mount /dev/disk/by-label/NIXROOT /mnt"
echo "     mount /dev/disk/by-label/NIXBOOT /mnt/boot"
echo "  2. Continue with installation or reboot"
echo
