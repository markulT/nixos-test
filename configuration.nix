# /etc/nixos/configuration.nix

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./firewall.nix
  ];

  # Filesystem configuration
  # Using filesystem labels (more reliable than device paths)
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };
  
  # Alternative: Use device paths (less reliable, changes with disk order)
  # For VMs, typically /dev/vda (VirtIO) or /dev/sda (SATA)
  # fileSystems."/" = {
  #   device = "/dev/vda2";  # Root partition (change vda to your disk)
  #   fsType = "ext4";
  # };
  # fileSystems."/boot" = {
  #   device = "/dev/vda1";  # Boot partition (change vda to your disk)
  #   fsType = "vfat";
  # };

  # 1. --- BOOTLOADER ---
  # Use systemd-boot for UEFI (recommended for modern systems)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # For BIOS boot, use GRUB instead:
  # boot.loader.grub.enable = true;
  # boot.loader.grub.device = "nodev";
  # boot.loader.grub.efiSupport = false;

  # 2. --- NETWORKING ---
  networking.hostName = "nixos-vm"; # Define your hostname.
  # Use NetworkManager. It's the easiest and most common for desktops/laptops.
  networking.networkmanager.enable = true;
  # Configure a basic firewall, allowing SSH access.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ]; # For SSH
  
  # Enable SSH server
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

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
    # Initial password (CHANGE THIS after first login with 'passwd')
    initialPassword = "nixos";
  };
  
  # Allow users to change their passwords after initial setup
  users.mutableUsers = true;

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
  # VirtualBox guest additions for better VM integration
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.x11 = false;  # We're using Wayland, not X11

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
    # Use specific nerdfonts instead of the entire collection (which is huge)
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Hack" ]; })
  ];
  nixpkgs.config.allowUnfree = true;

  # 6. --- VIRTUALIZATION ---
  # Enable VirtualBox guest additions for better VM integration.
  # services.virtualbox.guest.enable = true;

  # 7. --- HOME MANAGER INTEGRATION ---
  # Home manager is disabled for now - enable it later after first boot if needed
  # home-manager.useGlobalPkgs = true;
  # home-manager.useUserPackages = true;
  # home-manager.users.alice = import ./home.nix;
  # home-manager.backupFileExtension = "hm-backup";
  
  # Graphics configuration for Wayland/Hyprland
  # Note: services.xserver.videoDrivers is for X11, not Wayland
  # For Wayland in VMs, we rely on DRM/KMS and mesa drivers
  # VMware guest tools already provide the necessary graphics support
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  
  # Note: hardware.graphics option was removed in NixOS 24.05
  # 32-bit support is enabled automatically when needed
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions,
  # are taken. It's perfectly fine and recommended to leave this value
  # set to the version you installed with.
  system.stateVersion = "24.05"; # Use the version you are installing.
}
