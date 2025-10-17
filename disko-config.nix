# /etc/nixos/disko-config.nix

{ lib, pkgs, ... }:

{
  # This uses the disko tool to declaratively partition the disk.
  disko.devices = {
    disk.main = {
      # This assumes your VM's disk is /dev/sda. Change if necessary.
      device = "/dev/sda";
      type = "gpt";
      partitions = [
        {
          name = "boot";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat"; # vfat is fat32
            mountpoint = "/boot";
          };
        }
        {
          name = "root";
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        }
      ];
    };
  };
}
