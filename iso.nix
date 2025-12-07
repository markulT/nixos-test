{ config, pkgs, lib, self, ... }:

let
  # Copy the entire repository source into the ISO
  embeddedConfig = pkgs.runCommand "embedded-nixos-config" {
    src = self;
  } ''
    mkdir -p $out
    cp -r $src/* $out/
    # Remove .git if it exists (to save space)
    rm -rf $out/.git 2>/dev/null || true
    # Make scripts executable
    chmod +x $out/*.sh 2>/dev/null || true
  '';
in
{
  # Embed the entire repository source into the ISO filesystem
  # This makes the config available at /etc/nixos-config in the installer
  environment.etc."nixos-config" = {
    source = embeddedConfig;
  };

  # Create symlink for easy access in home directory
  systemd.tmpfiles.rules = [
    "L+ /home/nixos/config - - - - /etc/nixos-config"
  ];

  # Package the partition script as a global command
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "auto-partition" ''
      #!/usr/bin/env bash
      # Auto-partition script wrapper
      # This script is embedded from the repository source
      
      CONFIG_DIR="/etc/nixos-config"
      SCRIPT="$CONFIG_DIR/simple-install.sh"
      
      if [ -f "$SCRIPT" ]; then
        exec "$SCRIPT" "$@"
      else
        echo "Error: simple-install.sh not found in embedded config"
        echo "Expected location: $SCRIPT"
        echo "Available files in $CONFIG_DIR:"
        ls -la "$CONFIG_DIR" 2>/dev/null || echo "  (directory not found)"
        exit 1
      fi
    '')
  ];

  # Add a helpful message on login
  programs.bash.interactiveShellInit = ''
    if [ -z "$NIXOS_CONFIG_SHOWN" ]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Custom NixOS Installer"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "  Configuration is embedded at: /etc/nixos-config"
      echo "  Also available at: /home/nixos/config (symlink)"
      echo ""
      echo "  Quick install: sudo auto-partition"
      echo "  Manual install: cd /etc/nixos-config && sudo ./simple-install.sh"
      echo ""
      export NIXOS_CONFIG_SHOWN=1
    fi
  '';
}

