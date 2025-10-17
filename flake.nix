# /etc/nixos/flake.nix
{
  description = "A flake for my NixOS VM configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }@inputs: {
    nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; }; # Allows access to inputs in other files
      modules = [
        # Import the main configuration
        ./configuration.nix
        # Import home-manager module
        home-manager.nixosModules.home-manager
        # Import disko's NixOS module.
        disko.nixosModules.disko
        # And tell it to use our disk layout config.
        ./disko-config.nix
      ];
    };
  };
}
