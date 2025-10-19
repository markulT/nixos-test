# /etc/nixos/home.nix

{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "alice";
  home.homeDirectory = "/home/alice";

  # This must match the system.stateVersion in configuration.nix.
  home.stateVersion = "24.05";

  # --- USER-SPECIFIC PACKAGES ---
  # These packages will be installed only for your user.
  home.packages = with pkgs; [
    # CLI Tools
    bat       # A cat clone with wings
    tree      # Display directory structures

    # GUI Applications
    firefox
    chromium
    kitty     # A modern terminal emulator
    gedit
    discord
    rofi # Application launcher
    lazydocker
  ];

  # --- SHELL CONFIGURATION (Fish) ---
  programs.fish = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      update = "sudo nixos-rebuild switch";
      btw = "echo 'I use NixOS, btw'";
    };
  };

  # --- DESKTOP ENVIRONMENT CONFIGURATION (Wayland) ---
  # Waybar is a status bar for Wayland compositors like Hyprland.
  programs.waybar = {
    enable = true;
    # We will manage the config files manually using xdg.configFile.
    # This gives us more control.
  };

  # This is the modern, recommended way to place config files.
  # It links your local file into the correct spot in ~/.config.
  # It assumes 'waybar.json' is in the same directory as this home.nix.
  xdg.configFile."waybar/config".source = ./.config/waybar/waybar.json;
  xdg.configFile."rofi/config.rasi".source = ./rofi/config.rasi;

  # If you had a separate style.css for waybar:
  # xdg.configFile."waybar/style.css".source = ./.config/waybar_style.css;
}
