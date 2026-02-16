# Bootloader configuration for Legacy BIOS mode
# More compatible with VirtualBox/KVM on Linux hosts
{ config, pkgs, ... }:

{
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";  # Will be auto-updated by simple-install.sh
  boot.loader.grub.configurationLimit = 3; # Only keep the last 3 versions
}
