# hardware-configuration.nix — Generic Intel laptop profile
# Tuned for modern Intel laptops (11th gen / Iris Xe and up)
# booting from a USB-connected SATA SSD via adapter.
#
# After first successful boot on the actual laptop, regenerate this with:
#   sudo nixos-generate-config --show-hardware-config
# and replace this file for a perfectly tailored result.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # --- INITRD MODULES ---
  # These must be available in the early boot stage to mount root.
  # Critical for USB-SATA SSD (xhci_pci + usb_storage/uas + sd_mod).
  boot.initrd.availableKernelModules = [
    "xhci_pci"    # USB 3.x host controller (required for USB-connected SSD)
    "thunderbolt"  # Thunderbolt / USB4 (11th gen Intel laptops)
    "nvme"         # NVMe internal drives
    "usb_storage"  # USB mass-storage (fallback for USB-SATA adapters)
    "uas"          # USB Attached SCSI — faster protocol for SATA-over-USB
    "sd_mod"       # SCSI disk driver — exposes /dev/sda
    "ahci"         # SATA controller (for any onboard SATA ports)
  ];

  # i915 is loaded early via configuration.nix (boot.initrd.kernelModules)
  boot.initrd.kernelModules = [ ];

  # --- POST-INITRD MODULES ---
  boot.kernelModules = [
    "kvm-intel"    # Intel hardware virtualisation (for Docker, VMs)
  ];
  boot.extraModulePackages = [ ];

  # --- SWAP ---
  swapDevices = [ ];

  # --- NETWORKING ---
  # DHCP on all interfaces by default; NetworkManager (enabled in
  # configuration.nix) will manage this at runtime.
  networking.useDHCP = lib.mkDefault true;

  # --- PLATFORM ---
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
