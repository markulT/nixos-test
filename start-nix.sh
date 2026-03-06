#!/usr/bin/env bash
# Quick script to start Nix daemon and set up environment on Fedora

set -e

echo "🐧 Starting Nix daemon..."

# Disable SELinux temporarily if it's blocking (Fedora has it enabled by default)
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Permissive" ]; then
    echo "  Disabling SELinux temporarily..."
    sudo setenforce 0
fi

# Always re-link and reload to ensure units are properly registered
echo "  Ensuring Nix systemd units are properly linked..."
sudo rm -f /etc/systemd/system/nix-daemon.service /etc/systemd/system/nix-daemon.socket
sudo cp /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service /etc/systemd/system/
sudo cp /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.socket /etc/systemd/system/
sudo systemctl daemon-reload
echo "  ✓ Systemd units registered"

# Start the socket if not running (socket activation will start the daemon)
if ! systemctl is-active --quiet nix-daemon.socket; then
    echo "  Starting nix-daemon.socket..."
    sudo systemctl start nix-daemon.socket
    sleep 1  # Give it a moment to initialize
    echo "  ✓ Nix daemon socket started"
else
    echo "  ✓ Nix daemon socket already active"
fi

# Source the Nix environment
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    echo "  Loading Nix environment..."
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    echo "  ✓ Nix environment loaded"
else
    echo "  ⚠️  Warning: Nix profile script not found"
fi

echo ""
echo "✅ Nix is ready!"
echo ""
echo "You can now run:"
echo "  nix build .#packages.x86_64-linux.iso --out-link /tmp/nixos-iso"
echo ""
