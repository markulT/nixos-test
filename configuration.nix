# configuration.nix — General NixOS configuration
#
# Machine-specific settings (hostname, GPU drivers, bootloader, kernel modules)
# live in machines/laptop.nix or machines/vm.nix and are composed in flake.nix.

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./firewall.nix
    # No bootloader here — each machine file picks its own.
    # No machine.nix here — flake.nix adds the right one per target.
  ];

  # --- FILESYSTEM ---
  # Label-based paths work on any machine we install to.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };

  # --- NETWORKING ---
  # hostname is set per-machine in machines/*.nix
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  # --- LOCALISATION ---
  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- USER ACCOUNTS ---
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "video" "input" ];
    shell = pkgs.fish;
    initialPassword = "nixos";
  };

  users.mutableUsers = true;

  # --- NIX ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # --- PACKAGES ---
  environment.systemPackages = with pkgs; [
    alacritty
    vim
    git
    wget
    btop
    openssl
    greetd.gtkgreet
    greetd.tuigreet
    kitty
    chromium          # Web browser
    vesktop           # Discord client (Vencord-patched)
    wofi              # App launcher (Super+Space in Hyprland)
    # Machine-specific packages (GPU tools, drivers) are in machines/*.nix
  ];

  # --- DOTFILES ---
  # Symlink managed dotfiles into alice's home on every nixos-rebuild switch.
  # Edit dotfiles/hyprland.conf in the repo; the symlink updates automatically.
  system.activationScripts.dotfiles = ''
    mkdir -p /home/alice/.config/hypr
    ln -sf ${./dotfiles/hyprland.conf} /home/alice/.config/hypr/hyprland.conf
    chown -h alice:users /home/alice/.config/hypr
  '';

  environment.etc."greetd/environments" = {
    text = ''
      Hyprland
    '';
  };

  security.polkit.enable = true;

  # --- SERVICES ---
  virtualisation.docker.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # --- DESKTOP ---
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.fish.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Hack" ]; })
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.05";
}
