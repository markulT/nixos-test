# /etc/nixos/configuration.nix

{ config, pkgs, ... }:

let
  # Fetch home-manager. This is a simple way to get started.
  # For more advanced, reproducible builds, you can use Flakes.
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz";
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Import home-manager's NixOS module.
    (import "${home-manager}/nixos")
    ./firewall.nix
  ];


 


  # 1. --- BOOTLOADER ---
  # Using systemd-boot for modern EFI systems. It's simple and effective.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 2. --- NETWORKING ---
  networking.hostName = "nixos-vm"; # Define your hostname.
  # Use NetworkManager. It's the easiest and most common for desktops/laptops.
  networking.networkmanager.enable = true;
  # Configure a basic firewall, allowing SSH access.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ]; # For SSH

  # 3. --- LOCALISATION ---
  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";

  # 4. --- USER ACCOUNTS ---
  # Define a non-root user account.
  users.users.alice = {
    isNormalUser = true;
    # Add user to the 'wheel' group to grant sudo permissions.
    # 'docker' group is needed to use docker without sudo.
    extraGroups = [ "wheel" "docker" "video"];
    # Set the default shell for this user.
    shell = pkgs.fish;
  };

  # 5. --- SOFTWARE & SYSTEM CONFIGURATION ---

  # Enable Nix command and flakes support.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System-wide packages available to all users.
  # Keep this list minimal. User-specific apps go in home.nix.
  environment.systemPackages = with pkgs; [
    alacritty
    vim
    git
    wget
    btop      # A modern resource monitor
    openssl
    greetd.gtkgreet
    greetd.tuigreet
    kitty
  ];
  environment.etc."greetd/environments" = {
    text = ''
      Hyprland
    '';
  };
  security.polkit.enable = true;

  # Enable Docker daemon for containerization.
  virtualisation.docker.enable = true;
  virtualisation.vmware.guest.enable = true;

  # Enable sound with Pipewire (the modern standard).
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

  # Enable Hyprland (Wayland compositor). We are NOT enabling X11/Xserver.
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.fish.enable = true;
  # Install system-wide fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
    pkgs.nerd-fonts.droid-sans-mono
    pkgs.nerd-fonts._0xproto
  ];
  nixpkgs.config.allowUnfree = true;

  # 6. --- VIRTUALIZATION ---
  # Enable VirtualBox guest additions for better VM integration.
  # services.virtualbox.guest.enable = true;

  # 7. --- HOME MANAGER INTEGRATION ---
  # This section hooks your home.nix file into the system build.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.alice = import ./home.nix;
  # Optional: Keep backups of dotfiles managed by home-manager.
  home-manager.backupFileExtension = "hm-backup";
  services.xserver.videoDrivers = [ "vmware" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions,
  # are taken. It's perfectly fine and recommended to leave this value
  # set to the version you installed with.
  system.stateVersion = "24.05"; # Use the version you are installing.
}
