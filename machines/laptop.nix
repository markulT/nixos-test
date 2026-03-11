# machines/laptop.nix
# Machine-specific configuration for the physical laptop.
# Hardware: Intel CPU + Intel Iris Xe iGPU, SSD connected via USB adapter.
#
# Composed in flake.nix alongside configuration.nix (general config).

{ config, pkgs, lib, ... }:

{
  imports = [
    ../bootloader-efi.nix          # Laptop uses UEFI / systemd-boot
  ];

  # --- FIRMWARE ---
  # Enables redistribution-friendly firmware blobs (linux-firmware).
  # Required for Intel WiFi (iwlwifi), Bluetooth, and other onboard hardware.
  hardware.enableRedistributableFirmware = true;

  # --- IDENTITY ---
  networking.hostName = "nixos-laptop";

  # --- KERNEL MODULES ---
  # Load i915 early so the GPU is available during boot splash.
  boot.initrd.kernelModules = [ "i915" ];
  # mt7921e: MediaTek MT7902/MT7922 PCIe WiFi driver (loaded post-initrd)
  boot.kernelModules = [ "mt7921e" ];

  # --- GRAPHICS (Intel Iris Xe / i915 open-source driver) ---
  # The i915 driver is built into the kernel; no proprietary blobs needed.
  # Mesa already includes the Intel ANV Vulkan driver — no separate package.
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver   # iHD — VA-API hardware video decode (8th gen+)
      libvdpau-va-gl       # VDPAU backend via VA-API
    ];
  };

  # --- ENVIRONMENT ---
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";   # Steer libva to the iHD VA-API driver
  };

  # --- MACHINE-SPECIFIC PACKAGES ---
  environment.systemPackages = with pkgs; [
    intel-gpu-tools    # intel_gpu_top and friends — GPU activity monitoring
  ];
}
