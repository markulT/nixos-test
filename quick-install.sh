#!/usr/bin/env bash
set -euo pipefail

################################################################################
# NixOS One-Command Installation
################################################################################
# This is a streamlined installer that does everything in one go:
# 1. Detects disk automatically (or uses specified one)
# 2. Runs disko to partition and mount
# 3. Copies configuration to /mnt/etc/nixos
# 4. Runs nixos-install
# 5. Done!
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==> WARNING:${NC} $1"; }
error() { echo -e "${RED}==> ERROR:${NC} $1"; exit 1; }

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="${HOSTNAME:-nixos-vm}"

################################################################################
# Interactive disk selection
################################################################################
select_disk() {
    log "Detecting available disks..."
    echo
    
    # Get all available disks
    local disks=()
    while IFS= read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local disk="/dev/$name"
        if [[ -b "$disk" ]]; then
            disks+=("$disk")
        fi
    done < <(lsblk -d -n -o NAME,SIZE,TYPE | grep disk)
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        error "No disk devices found!"
    fi
    
    # Show disk information
    log "Available disks:"
    echo
    printf "%-3s %-12s %-8s %-20s\n" "No" "Device" "Size" "Description"
    printf "%-3s %-12s %-8s %-20s\n" "---" "------" "----" "-----------"
    
    for i in "${!disks[@]}"; do
        local disk="${disks[$i]}"
        local size=$(lsblk -d -n -o SIZE "$disk")
        local description=""
        
        # Add helpful descriptions
        case "$disk" in
            /dev/vda*) description="VirtIO (VM)" ;;
            /dev/sda*) description="SATA/SCSI" ;;
            /dev/nvme*) description="NVMe SSD" ;;
            /dev/hda*) description="IDE" ;;
            *) description="Other" ;;
        esac
        
        printf "%-3d %-12s %-8s %-20s\n" "$((i+1))" "$disk" "$size" "$description"
    done
    
    echo
    log "Choose installation disk:"
    echo "  [1-${#disks[@]}] Select from list above"
    echo "  [m] Manual input (type device path)"
    echo "  [l] List disks again"
    echo "  [q] Quit"
    echo
    
    while true; do
        read -p "Enter your choice: " choice
        
        case "$choice" in
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#disks[@]} ]]; then
                    local selected="${disks[$((choice-1))]}"
                    log "Selected: $selected"
                    echo "$selected"
                    return 0
                else
                    warn "Invalid choice. Please enter 1-${#disks[@]}"
                fi
                ;;
            m|M)
                echo
                log "Manual disk input"
                echo "Hint: Run 'lsblk' to see all devices"
                echo "Common devices: /dev/vda, /dev/sda, /dev/nvme0n1"
                echo
                read -p "Enter device path (e.g., /dev/vda): " manual_disk
                
                if [[ -b "$manual_disk" ]]; then
                    log "Selected: $manual_disk"
                    echo "$manual_disk"
                    return 0
                else
                    error "Device $manual_disk not found or not a block device!"
                fi
                ;;
            l|L)
                echo
                lsblk
                echo
                ;;
            q|Q)
                log "Installation cancelled"
                exit 0
                ;;
            *)
                warn "Invalid choice. Please enter 1-${#disks[@]}, m, l, or q"
                ;;
        esac
    done
}

################################################################################
# Auto-detect disk device (fallback)
################################################################################
detect_disk() {
    log "Auto-detecting primary disk..."
    
    # Try common disk devices in order of preference
    local disks=("/dev/vda" "/dev/sda" "/dev/nvme0n1")
    
    for disk in "${disks[@]}"; do
        if [[ -b "$disk" ]]; then
            echo "$disk"
            return 0
        fi
    done
    
    # If none of the common ones exist, find the largest disk
    local largest=$(lsblk -d -n -o NAME,SIZE,TYPE | grep disk | sort -k2 -hr | head -1 | awk '{print "/dev/"$1}')
    if [[ -b "$largest" ]]; then
        echo "$largest"
        return 0
    fi
    
    error "Could not detect any disk device!"
}

################################################################################
# Main installation
################################################################################
main() {
    [[ $EUID -ne 0 ]] && error "This script must be run as root (use sudo)"
    
    log "╔════════════════════════════════════════════════════════════╗"
    log "║          NixOS Automated Installation                     ║"
    log "╚════════════════════════════════════════════════════════════╝"
    echo
    log "Hostname: ${BLUE}$HOSTNAME${NC}"
    log "Config directory: ${BLUE}$SCRIPT_DIR${NC}"
    echo
    
    # Disk selection
    if [[ -n "${1:-}" ]]; then
        # Disk specified as argument
        DISK="$1"
        if [[ ! -b "$DISK" ]]; then
            error "Specified disk $DISK not found!"
        fi
        log "Using specified disk: ${BLUE}$DISK${NC}"
    else
        # Interactive disk selection
        DISK=$(select_disk)
    fi
    
    echo
    log "Selected disk: ${BLUE}$DISK${NC}"
    
    # Show disk info
    log "Disk information:"
    lsblk "$DISK" 2>/dev/null || error "Disk $DISK not found!"
    echo
    
    # Confirm
    warn "This will DESTROY ALL DATA on $DISK"
    read -p "Continue? (type 'yes' to proceed): " confirm
    [[ "$confirm" != "yes" ]] && { log "Cancelled."; exit 0; }
    
    # Update disko-config.nix with the correct disk
    log "Updating disko configuration for disk $DISK..."
    sed -i "s|device = \"/dev/[a-z0-9]*\";|device = \"$DISK\";|g" "$SCRIPT_DIR/disko-config.nix"
    
    # Enable nix experimental features
    log "Enabling nix experimental features..."
    mkdir -p /root/.config/nix
    echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf
    
    # Run disko
    log "Running disko to partition and mount disk..."
    log "(This may take a few minutes...)"
    echo
    
    nix run github:nix-community/disko -- \
        --mode zap_create_mount \
        "$SCRIPT_DIR/disko-config.nix" || error "Disko failed!"
    
    echo
    log "Partitioning complete! Mount points:"
    mount | grep /mnt | sed 's/^/  /'
    echo
    
    # Copy configuration
    log "Deploying configuration to /mnt/etc/nixos..."
    mkdir -p /mnt/etc/nixos
    cp -r "$SCRIPT_DIR"/* /mnt/etc/nixos/
    
    # Install NixOS
    log "Installing NixOS..."
    log "(This will take several minutes, be patient...)"
    echo
    
    nixos-install --flake "/mnt/etc/nixos#$HOSTNAME" --no-root-password || error "NixOS installation failed!"
    
    echo
    log "╔════════════════════════════════════════════════════════════╗"
    log "║          Installation Complete!                           ║"
    log "╚════════════════════════════════════════════════════════════╝"
    echo
    log "You can now:"
    log "  1. Set a root password: ${BLUE}nixos-enter --root /mnt -c passwd root${NC}"
    log "  2. Reboot: ${BLUE}reboot${NC}"
    echo
    log "After reboot, rebuild with:"
    log "  ${BLUE}sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME${NC}"
    echo
}

# Show usage if --help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
Usage: sudo $0 [DISK_DEVICE]

One-command NixOS installation with interactive disk selection.

Arguments:
    DISK_DEVICE     Optional. Disk to install to (e.g., /dev/vda, /dev/sda)
                    If not specified, will show interactive disk selection menu.

Environment Variables:
    HOSTNAME        System hostname (default: nixos-vm)

Examples:
    sudo ./quick-install.sh              # Interactive disk selection
    sudo ./quick-install.sh /dev/nvme0n1 # Use specific disk
    HOSTNAME=myserver sudo ./quick-install.sh /dev/vda

Interactive Menu Options:
    [1-N]  Select disk from numbered list
    [m]    Manual input (type device path)
    [l]    List all disks again
    [q]    Quit installation

EOF
    exit 0
fi

main "$@"

