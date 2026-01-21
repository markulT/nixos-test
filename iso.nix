{ config, pkgs, lib, self, ... }:

let
  # SSH key file path (can be set via environment variable SSH_KEY_PATH during build)
  # This should point to your private SSH key (e.g., ~/.ssh/id_ed25519 or ~/.ssh/id_rsa)
  # Usage: SSH_KEY_PATH=~/.ssh/id_ed25519 nix build .#packages.x86_64-linux.iso
  sshKeyPath = builtins.getEnv "SSH_KEY_PATH";
  hasSSHKey = sshKeyPath != "";
  
  # Git repository URL (can be set via environment variable GIT_REPO_URL during build)
  # Usage: GIT_REPO_URL=git@github.com:user/repo.git nix build .#packages.x86_64-linux.iso
  gitRepoUrl = builtins.getEnv "GIT_REPO_URL";
  hasGitRepo = gitRepoUrl != "";
  # Copy the entire repository source into the ISO
  embeddedConfig = pkgs.runCommand "embedded-nixos-config" {
    src = self;
  } (lib.concatStrings [
    ''
      mkdir -p $out
      cp -r $src/* $out/
      # Remove .git if it exists (to save space)
      rm -rf $out/.git 2>/dev/null || true
      # Make scripts executable
      chmod +x $out/*.sh 2>/dev/null || true
    ''
    (lib.optionalString hasSSHKey ''
      # Embed SSH key if provided via environment variable
      mkdir -p $out/.ssh
      cp "${sshKeyPath}" $out/.ssh/id_key
      chmod 600 $out/.ssh/id_key
    '')
    (lib.optionalString hasGitRepo ''
      # Embed default git repo URL
      echo "${gitRepoUrl}" > $out/.git-repo-url
      chmod 644 $out/.git-repo-url
    '')
  ]);
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

  # Ensure git is available in the installer
  environment.systemPackages = with pkgs; [
    git
    (writeShellScriptBin "auto-partition" ''
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
    (writeShellScriptBin "update-config" ''
      #!/usr/bin/env bash
      # Update config from git repository
      # Usage: update-config [repo-url] [branch]
      #        update-config [branch]  (if repo is embedded)
      
      set -euo pipefail
      
      ARG1="''${1:-}"
      ARG2="''${2:-}"
      
      # Check for embedded default repo URL
      DEFAULT_REPO=""
      if [ -f /etc/nixos-config/.git-repo-url ]; then
        DEFAULT_REPO=$(cat /etc/nixos-config/.git-repo-url | tr -d '\n\r')
      fi
      
      # Determine if first argument is a repo URL or branch name
      # Repo URLs typically contain @ or :// or end with .git
      if [ -n "$ARG1" ] && (echo "$ARG1" | grep -qE '@|://|\.git$'); then
        # First argument is a repo URL
        REPO_URL="$ARG1"
        BRANCH="''${ARG2:-main}"
      elif [ -n "$DEFAULT_REPO" ]; then
        # Use embedded default repo, first arg is branch (if provided)
        REPO_URL="$DEFAULT_REPO"
        BRANCH="''${ARG1:-main}"
        if [ -n "$ARG1" ]; then
          echo "Using embedded default repo: $REPO_URL"
          echo "Branch: $BRANCH"
        fi
      else
        # No default repo, first arg must be repo URL
        REPO_URL="$ARG1"
        BRANCH="''${ARG2:-main}"
      fi
      
      # Use GIT_REPO from environment if still no repo URL
      if [ -z "$REPO_URL" ] && [ -n "''${GIT_REPO:-}" ]; then
        REPO_URL="$GIT_REPO"
        BRANCH="''${ARG1:-main}"
      fi
      
      if [ -z "$REPO_URL" ]; then
        echo "Usage: update-config <repo-url> [branch]"
        echo "   or: update-config [branch]  (if repo is embedded)"
        echo ""
        echo "Examples:"
        echo "  update-config git@github.com:user/repo.git main"
        echo "  update-config release  (uses embedded repo, branch: release)"
        if [ -n "$DEFAULT_REPO" ]; then
          echo ""
          echo "Embedded default repo: $DEFAULT_REPO"
          echo "  update-config        # uses default repo, branch: main"
          echo "  update-config release # uses default repo, branch: release"
        fi
        exit 1
      fi
      
      WORK_DIR="/tmp/nixos-config-update"
      echo "Cloning/updating config from $REPO_URL (branch: $BRANCH)..."
      
      if [ -d "$WORK_DIR" ]; then
        cd "$WORK_DIR"
        git fetch origin
        git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
        git pull origin "$BRANCH"
      else
        git clone -b "$BRANCH" "$REPO_URL" "$WORK_DIR"
      fi
      
      echo ""
      echo "Config updated! New files are in: $WORK_DIR"
      echo "To use the updated config:"
      echo "  cd $WORK_DIR"
      echo "  sudo ./simple-install.sh"
      echo ""
      echo "Or copy to embedded location:"
      echo "  sudo cp -r $WORK_DIR/* /etc/nixos-config/"
    '')
  ];

  # Set up SSH keys for the nixos user if provided
  system.activationScripts.setupSSH = lib.optionalString hasSSHKey ''
    mkdir -p /home/nixos/.ssh
    chmod 700 /home/nixos/.ssh
    chown nixos:users /home/nixos/.ssh
    
    # Copy embedded SSH key if it exists
    if [ -f /etc/nixos-config/.ssh/id_key ]; then
      cp /etc/nixos-config/.ssh/id_key /home/nixos/.ssh/id_key
      chmod 600 /home/nixos/.ssh/id_key
      chown nixos:users /home/nixos/.ssh/id_key
      
      # Detect key type and create appropriate symlink
      KEY_TYPE=$(head -n 1 /home/nixos/.ssh/id_key | awk '{print $1}')
      if echo "$KEY_TYPE" | grep -q "BEGIN.*PRIVATE KEY"; then
        # Try to detect if it's RSA or ED25519
        if grep -q "BEGIN RSA PRIVATE KEY" /home/nixos/.ssh/id_key; then
          ln -sf id_key /home/nixos/.ssh/id_rsa
        elif grep -q "BEGIN OPENSSH PRIVATE KEY" /home/nixos/.ssh/id_key; then
          # Check if it's ed25519 by looking at the key comment
          if grep -q "ed25519" /home/nixos/.ssh/id_key; then
            ln -sf id_key /home/nixos/.ssh/id_ed25519
          else
            ln -sf id_key /home/nixos/.ssh/id_rsa
          fi
        fi
      fi
    fi
    
    # Add GitHub and GitLab to known_hosts
    if [ ! -f /home/nixos/.ssh/known_hosts ]; then
      ssh-keyscan github.com gitlab.com 2>/dev/null >> /home/nixos/.ssh/known_hosts || true
      chmod 600 /home/nixos/.ssh/known_hosts
      chown nixos:users /home/nixos/.ssh/known_hosts
    fi
    
    # Configure SSH to use the key
    if [ ! -f /home/nixos/.ssh/config ]; then
      cat > /home/nixos/.ssh/config <<EOF
Host github.com
  IdentityFile ~/.ssh/id_key
  StrictHostKeyChecking accept-new

Host gitlab.com
  IdentityFile ~/.ssh/id_key
  StrictHostKeyChecking accept-new
EOF
      chmod 600 /home/nixos/.ssh/config
      chown nixos:users /home/nixos/.ssh/config
    fi
  '';

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
      if [ -f /home/nixos/.ssh/id_rsa ] || [ -f /home/nixos/.ssh/id_ed25519 ] || [ -f /home/nixos/.ssh/id_key ]; then
        echo ""
        if [ -f /etc/nixos-config/.git-repo-url ]; then
          DEFAULT_REPO=$(cat /etc/nixos-config/.git-repo-url)
          echo "  Update config from git: update-config [branch]"
          echo "  (Default repo: $DEFAULT_REPO)"
        else
          echo "  Update config from git: update-config <repo-url> [branch]"
          echo "  Example: update-config git@github.com:user/repo.git main"
        fi
      fi
      echo ""
      export NIXOS_CONFIG_SHOWN=1
    fi
  '';
}

