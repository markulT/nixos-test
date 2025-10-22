#!/usr/bin/env bash
set -euo pipefail

################################################################################
# NixOS Automated Installation Script with Disko
################################################################################
# This script automates the entire NixOS installation process including:
# - Partitioning with disko
# - Configuration deployment
# - System installation
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DISK_DEVICE="${DISK_DEVICE:-/dev/sda}"
CONFIG_REPO="${CONFIG_REPO:-}"
HOSTNAME="${HOSTNAME:-nixos-vm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

enable_nix_features() {
    log_info "Enabling nix experimental features..."
    mkdir -p /root/.config/nix
    echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf
}

detect_disk() {
    log_info "Detecting available disks..."
    lsblk -d -n -o NAME,SIZE,TYPE | grep disk
    
    if [[ ! -b "$DISK_DEVICE" ]]; then
        log_error "Disk $DISK_DEVICE not found!"
        log_info "Available disks:"
        lsblk -d -n -o NAME,SIZE,TYPE | grep disk
        exit 1
    fi
    
    log_info "Using disk: $DISK_DEVICE"
}

confirm_installation() {
    log_warn "WARNING: This will DESTROY ALL DATA on $DISK_DEVICE"
    log_warn "Disk information:"
    lsblk "$DISK_DEVICE"
    
    read -p "Are you sure you want to continue? (yes/NO): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
}

get_configuration() {
    log_info "Getting configuration files..."
    
    # If we're running from the config directory, use it directly
    if [[ -f "$SCRIPT_DIR/disko-config.nix" ]] && [[ -f "$SCRIPT_DIR/flake.nix" ]]; then
        log_info "Using configuration from: $SCRIPT_DIR"
        CONFIG_DIR="$SCRIPT_DIR"
        return 0
    fi
    
    # Otherwise, try to clone from repo
    if [[ -n "$CONFIG_REPO" ]]; then
        log_info "Cloning configuration from: $CONFIG_REPO"
        CONFIG_DIR="/tmp/nixos-config"
        rm -rf "$CONFIG_DIR"
        git clone "$CONFIG_REPO" "$CONFIG_DIR"
    else
        log_error "Configuration not found. Please either:"
        log_error "  1. Run this script from the config directory, or"
        log_error "  2. Set CONFIG_REPO environment variable"
        exit 1
    fi
}

partition_disk() {
    log_info "Partitioning disk with disko..."
    
    # Comprehensive cleanup before partitioning
    log_info "Cleaning up existing disk configuration..."
    
    # Unmount any existing mounts
    log_info "Unmounting any existing partitions..."
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    
    # Remove device mapper volumes
    log_info "Removing device mapper volumes..."
    dmsetup remove_all 2>/dev/null || true
    
    # Deactivate any LVM volumes
    if command -v vgchange &> /dev/null; then
        vgchange -an 2>/dev/null || true
    fi
    
    # Update kernel partition table
    log_info "Updating kernel partition table..."
    partprobe "$DISK_DEVICE" 2>/dev/null || true
    
    # Give the system a moment to release the disk
    sleep 2
    
    # Wipe existing filesystem signatures
    log_info "Wiping existing filesystem signatures on $DISK_DEVICE..."
    if command -v wipefs &> /dev/null; then
        # Use wipefs if available
        wipefs -af "$DISK_DEVICE" 2>/dev/null || true
        
        # Wipe individual partitions if they exist
        for part in "${DISK_DEVICE}"*[0-9]; do
            if [[ -b "$part" ]]; then
                wipefs -af "$part" 2>/dev/null || true
            fi
        done
    else
        # Fallback to dd if wipefs is not available
        log_warn "wipefs not found, using dd to zero out partition table..."
        dd if=/dev/zero of="$DISK_DEVICE" bs=1M count=10 conv=notrunc 2>/dev/null || true
    fi
    
    # Another partition table update
    partprobe "$DISK_DEVICE" 2>/dev/null || true
    sleep 1
    
    # Run disko
    log_info "Running disko to create partitions..."
    nix run github:nix-community/disko -- \
        --mode zap_create_mount \
        "$CONFIG_DIR/disko-config.nix"
    
    log_info "Partitioning complete. Mount points:"
    mount | grep /mnt
}

deploy_configuration() {
    log_info "Deploying configuration to /mnt/etc/nixos..."
    
    mkdir -p /mnt/etc/nixos
    
    # Copy all configuration files
    cp -r "$CONFIG_DIR"/* /mnt/etc/nixos/
    
    # Ensure proper permissions
    chmod -R 755 /mnt/etc/nixos
    
    log_info "Configuration deployed successfully"
}

install_nixos() {
    log_info "Installing NixOS..."
    
    # Install using flake
    nixos-install --flake "/mnt/etc/nixos#$HOSTNAME" --no-root-password
    
    log_info "NixOS installation complete!"
}

set_root_password() {
    log_info "Setting root password..."
    
    read -s -p "Enter root password: " password
    echo
    read -s -p "Confirm root password: " password2
    echo
    
    if [[ "$password" != "$password2" ]]; then
        log_error "Passwords don't match!"
        exit 1
    fi
    
    echo -e "$password\n$password" | nixos-enter --root /mnt -c passwd root
}

cleanup() {
    log_info "Cleaning up temporary files..."
    if [[ -n "${CONFIG_DIR:-}" ]] && [[ "$CONFIG_DIR" == "/tmp/"* ]]; then
        rm -rf "$CONFIG_DIR"
    fi
}

print_completion_message() {
    echo
    log_info "════════════════════════════════════════════════════════════"
    log_info "  Installation Complete!"
    log_info "════════════════════════════════════════════════════════════"
    echo
    log_info "You can now reboot into your new NixOS installation:"
    log_info "  sudo reboot"
    echo
    log_info "After reboot, you can rebuild the system with:"
    log_info "  sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME"
    echo
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated NixOS installation script with disko partitioning.

OPTIONS:
    -h, --help              Show this help message
    -d, --disk DEVICE       Specify disk device (default: /dev/sda)
    -r, --repo URL          Git repository URL for configuration
    -n, --hostname NAME     Hostname for the system (default: nixos-vm)
    --no-confirm            Skip confirmation prompt (dangerous!)

ENVIRONMENT VARIABLES:
    DISK_DEVICE             Disk to install to (default: /dev/sda)
    CONFIG_REPO             Git repository URL for configuration
    HOSTNAME                System hostname (default: nixos-vm)

EXAMPLES:
    # Run from config directory
    sudo ./install.sh

    # Specify disk and hostname
    sudo ./install.sh --disk /dev/nvme0n1 --hostname my-server

    # Clone config from repository
    sudo ./install.sh --repo https://github.com/user/nixos-config.git

EOF
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    local skip_confirm=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--disk)
                DISK_DEVICE="$2"
                shift 2
                ;;
            -r|--repo)
                CONFIG_REPO="$2"
                shift 2
                ;;
            -n|--hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --no-confirm)
                skip_confirm=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting NixOS automated installation"
    log_info "Hostname: $HOSTNAME"
    log_info "Disk: $DISK_DEVICE"
    
    check_root
    enable_nix_features
    detect_disk
    
    if [[ "$skip_confirm" != true ]]; then
        confirm_installation
    fi
    
    get_configuration
    partition_disk
    deploy_configuration
    install_nixos
    
    # Optional: Set root password
    read -p "Do you want to set a root password now? (y/N): " set_pw
    if [[ "$set_pw" =~ ^[Yy]$ ]]; then
        set_root_password
    fi
    
    cleanup
    print_completion_message
}

# Trap errors and cleanup
trap cleanup EXIT

# Run main function
main "$@"

