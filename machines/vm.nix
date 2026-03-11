# machines/vm.nix
# Machine-specific configuration for VirtualBox VMs.
# Works on both Fedora and Windows 11 hosts.
#
# Composed in flake.nix alongside configuration.nix (general config).

{ config, pkgs, lib, ... }:

{
  imports = [
    # Use BIOS locally (avoids VirtualBox EFI CD-ROM quirks),
    # or swap to ../bootloader-efi.nix once installed on a UEFI-capable VM.
    ../bootloader-bios.nix
  ];

  # --- IDENTITY ---
  networking.hostName = "nixos-vm";

  # --- KERNEL MODULES ---
  # No special early modules needed for VMs; VirtualBox handles disk access.
  boot.initrd.kernelModules = [ ];

  # --- GRAPHICS (VirtualBox software rendering) ---
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # --- ENVIRONMENT ---
  # These keep Hyprland stable under VirtualBox's limited GL support.
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";   # Prevents cursor artifact trails
    WLR_RENDERER = "gles2";          # Use GLES2 renderer (avoids Vulkan requirement)
    WLR_DRM_NO_ATOMIC = "1";         # Disable atomic modesetting (VM compat)
  };

  # --- VIRTUALISATION ---
  virtualisation.virtualbox.guest.enable = true;
}
