#!/usr/bin/env bash
# Quick script to test the ISO in QEMU/KVM
# Usage: ./test-iso.sh /path/to/iso

set -euo pipefail

ISO_PATH="${1:-}"

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
    echo "Usage: $0 /path/to/nixos-installer.iso"
    echo ""
    echo "Example:"
    echo "  $0 ~/Downloads/nixos-minimal-x86_64-linux.iso"
    exit 1
fi

echo "Starting QEMU/KVM VM with ISO: $ISO_PATH"
echo ""
echo "VM Configuration:"
echo "  Memory: 2GB"
echo "  Disk: 20GB (temporary, will be deleted after VM stops)"
echo "  Boot: From ISO"
echo ""
echo "Press Ctrl+Alt+G to release mouse/keyboard"
echo "Press Ctrl+Alt+2 to open QEMU monitor"
echo ""

# Create a temporary disk image
DISK_IMG=$(mktemp /tmp/nixos-test-XXXXXX.img)
qemu-img create -f qcow2 "$DISK_IMG" 20G

# Clean up on exit
cleanup() {
    echo ""
    echo "Cleaning up temporary disk image..."
    rm -f "$DISK_IMG"
}
trap cleanup EXIT

# Check if KVM is available
if [ -c /dev/kvm ]; then
    KVM_OPT="-enable-kvm"
    echo "Using KVM acceleration"
else
    KVM_OPT=""
    echo "KVM not available, using software emulation (slower)"
fi

# Start QEMU
qemu-system-x86_64 \
    $KVM_OPT \
    -m 2048 \
    -smp 2 \
    -cdrom "$ISO_PATH" \
    -drive file="$DISK_IMG",format=qcow2 \
    -boot d \
    -netdev user,id=net0 \
    -device virtio-net,netdev=net0 \
    -display gtk \
    -name "NixOS Installer Test"

echo ""
echo "VM stopped. Temporary disk image cleaned up."


