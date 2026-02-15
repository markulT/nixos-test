# Bootloader configuration for UEFI mode
# Recommended for modern systems and works well on Windows/macOS hosts
{ config, pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3; # Only keep the last 3 versions
  boot.loader.efi.canTouchEfiVariables = true;
}
