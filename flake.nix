{
  description = "NixOS configurations — laptop + VM targets";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # ---------------------------------------------------------------
      # Physical laptop (Intel Iris Xe, boots from USB-connected SSD)
      # Build & install:
      #   nix build .#nixosConfigurations.nixos-laptop.config.system.build.toplevel
      # ---------------------------------------------------------------
      nixosConfigurations.nixos-laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix      # General config (services, users, packages…)
          ./machines/laptop.nix    # Laptop-specific (GPU, hostname, bootloader…)
        ];
      };

      # ---------------------------------------------------------------
      # VirtualBox VM (software rendering, BIOS boot)
      # Switch bootloader to bootloader-efi.nix inside machines/vm.nix
      # if you need a UEFI VM.
      # ---------------------------------------------------------------
      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix      # General config
          ./machines/vm.nix        # VM-specific (WLR vars, VBox guest, bootloader…)
        ];
      };

      # ---------------------------------------------------------------
      # Custom installer ISO (used to flash the SSD)
      # Build: nix build .#packages.x86_64-linux.iso
      # ---------------------------------------------------------------
      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./iso.nix
        ];
        specialArgs = {
          inherit self;
        };
      };

      packages.${system}.iso = self.nixosConfigurations.installer.config.system.build.isoImage;
    };
}
