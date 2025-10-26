#!/usr/bin/env bash
set -euo pipefail

################################################################################
# NixOS Installation Reset Script
################################################################################
# This script cleans up failed installations and resets the disk
# Use this when installation goes wrong and you want to start fresh
# WITHOUT rebooting the machine
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[RESET]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

################################################################################
# Main reset process
################################################################################
main() {
    log "╔════════════════════════════════════════════════════════════╗"
    log "║     NixOS Installation Reset Tool                         ║"
    log "╚════════════════════════════════════════════════════════════╝"
    echo
    
    # Check for root
    [[ $EUID -ne 0 ]] && error "This script must be run as root (use sudo)"
    
    # Get disk device
    local disk="${1:-}"
    
    if [[ -z "$disk" ]]; then
        log "No disk specified. Auto-detecting..."
        # Try to find the disk being used
        local mounted=$(mount | grep /mnt | head -1 | awk '{print $1}')
        if [[ -n "$mounted" ]]; then
            # Extract device from mount point (e.g., /dev/vda1 -> /dev/vda)
            disk=$(echo "$mounted" | sed 's/[0-9]*$//')
            log "Detected disk from mounted partition: $disk"
        else
            # Try common disks
            for d in "/dev/vda" "/dev/sda" "/dev/nvme0n1"; do
                if [[ -b "$d" ]]; then
                    disk="$d"
                    break
                fi
            done
        fi
        
        if [[ -z "$disk" ]]; then
            error "Could not auto-detect disk. Please specify: sudo $0 /dev/vda"
        fi
    fi
    
    log "Target disk: ${BLUE}$disk${NC}"
    echo
    
    # Confirm
    warn "This will DESTROY ALL PARTITIONS and DATA on $disk"
    warn "But you will stay in the installer environment"
    read -p "Continue? (type 'yes' to proceed): " confirm
    [[ "$confirm" != "yes" ]] && { log "Cancelled."; exit 0; }
    
    echo
    log "Starting cleanup process..."
    echo
    
    # Step 1: Unmount everything
    log "Step 1/6: Unmounting filesystems..."
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    
    # Step 2: Remove device mapper volumes
    log "Step 2/6: Removing device mapper volumes..."
    dmsetup remove_all 2>/dev/null || true
    
    # Step 3: Deactivate LVM volumes
    log "Step 3/6: Deactivating LVM volumes..."
    if command -v vgchange &> /dev/null; then
        vgchange -an 2>/dev/null || true
    fi
    
    # Step 4: Sync filesystem
    log "Step 4/6: Syncing filesystem..."
    sync
    
    # Step 5: Wipe partition table
    log "Step 5/6: Wiping partition table..."
    
    # Method 1: Try sgdisk
    if command -v sgdisk &> /dev/null; then
        log "   Using sgdisk..."
        sgdisk --zap-all "$disk" 2>/dev/null || true
    fi
    
    # Method 2: Use dd as backup
    log "   Using dd to zero out partition table area..."
    dd if=/dev/zero of="$disk" bs=1M count=100 conv=notrunc 2>/dev/null || true
    
    # Method 3: Try wipefs if available
    if command -v wipefs &> /dev/null; then
        log "   Using wipefs..."
        wipefs -af "$disk" 2>/dev/null || true
    fi
    
    # Step 6: Update kernel partition table
    log "Step 6/6: Updating kernel partition table..."
    partprobe "$disk" 2>/dev/null || true
    sleep 3
    
    echo
    log "╔════════════════════════════════════════════════════════════╗"
    log "║     Reset Complete!                                       ║"
    log "╚════════════════════════════════════════════════════════════╝"
    echo
    log "The disk has been completely reset."
    log "You can now run the installation script again:"
    echo
    log "  ${BLUE}sudo ./quick-install.sh${NC}"
    echo
    log "Or check the disk status with:"
    echo "  ${BLUE}lsblk${NC}"
    echo
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
Usage: sudo $0 [DISK_DEVICE]

NixOS Installation Reset Tool - Clean up failed installations without rebooting.

This script:
  1. Unmounts all filesystems
  2. Removes device mapper volumes
  3. Deactivates LVM volumes
  4. Wipes partition table
  5. Resets the disk to factory state

Arguments:
    DISK_DEVICE     Optional. Disk to reset (e.g., /dev/vda, /dev/sda)
                    If not specified, will auto-detect from mounted partitions.

Examples:
    sudo $0              # Auto-detect and reset
    sudo $0 /dev/vda     # Reset specific disk
    sudo $0 /dev/sda     # Reset SATA disk

Use this when:
  - Installation fails partway through
  - You want to try different disk layouts
  - You need to start over without rebooting

Then run: sudo ./quick-install.sh

EOF
    exit 0
fi

main "$@"

