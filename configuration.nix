# /etc/nixos/configuration.nix

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./firewall.nix
    # Choose your bootloader (comment/uncomment one):
    # ./bootloader-bios.nix   # For Legacy BIOS systems
    ./bootloader-efi.nix      # For modern UEFI systems (laptops, desktops)
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

  # 1. --- KERNEL MODULES & BOOT ---
  # i915 is autoloaded by the kernel for Intel iGPU — no manual override needed
  boot.initrd.kernelModules = [ "i915" ]; # Load Intel GPU driver early (better boot splash)

  # 2. --- NETWORKING ---
  networking.hostName = "nixos-laptop";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Enable SSH server
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  # 3. --- LOCALISATION ---
  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";

  # 4. --- USER ACCOUNTS ---
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "video" "input" ];
    shell = pkgs.fish;
    initialPassword = "nixos";
  };

  users.mutableUsers = true;

  # 5. --- SOFTWARE & SYSTEM CONFIGURATION ---

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
    # Intel GPU tools (useful for checking GPU status)
    intel-gpu-tools
  ];

  environment.etc."greetd/environments" = {
    text = ''
      Hyprland
    '';
  };

  security.polkit.enable = true;

  # Enable Docker daemon for containerization.
  virtualisation.docker.enable = true;

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

  # Enable Hyprland (Wayland compositor).
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

  # 6. --- GRAPHICS (Intel Iris Xe / Iris Plus) ---
  # The i915 open-source driver handles all Intel integrated graphics.
  # No proprietary drivers needed.
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver   # iHD driver — VA-API hardware video decode (8th gen+)
      vulkan-intel         # Intel Vulkan support
      libvdpau-va-gl       # VDPAU via VA-API (for apps that use VDPAU)
    ];
  };

  # No VM-specific environment variables needed on real hardware.
  # Hyprland works natively with Intel iGPU on Wayland.
  environment.sessionVariables = {
    # Tell apps to use VA-API for hardware video decoding
    LIBVA_DRIVER_NAME = "iHD";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # are taken.
  system.stateVersion = "24.05";
}
