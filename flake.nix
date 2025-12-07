{
  description = "NixOS Server Configuration with Custom Installer ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # Standard NixOS configuration
      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      };

      # Custom installer ISO configuration
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

      # Convenience output for building the ISO
      packages.${system}.iso = self.nixosConfigurations.installer.config.system.build.isoImage;
    };
}

