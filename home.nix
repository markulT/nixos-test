{ config, pkgs, lib, ... }:

{
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "24.11";

  programs.fish = {
    enable = true;
    shellAliases = {
      chromium = "chromium --disable-pinch";
      chromium-browser = "chromium-browser --disable-pinch";
      firefox = "firefox --disable-pinch";
      btw = "echo i use nixos btw";
      ll = "ls -la";
    };
  };

  programs.waybar = {
    enable = true;
    #settings = lib.importJSON ./waybarconf;
    #settings = [ builtins.toJSON (builtins.readFile "/etc/nixos/waybarconf") ];
    #style = (builtins.readFile sources/waybar/style.css);
  };

  xdg.configFile."waybar/config".source = ./.config/waybar/config;
  xdg.configFile."waybar/style.css".source = ./.config/waybar/style.css;

  # cursor
  home.file.".icons/default".source = "${pkgs.vanilla-dmz}/share/icons/Vanilla-DMZ";

  home.packages = with pkgs; [
    bat
    gedit
  ];

}