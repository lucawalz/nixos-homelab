{
  description = "Homelab NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }@inputs:
  let
    nodes = [
      "master"
      "worker-1"
      "worker-2"
    ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (name: {
      name = name;
      value = nixpkgs.lib.nixosSystem {
        specialArgs = {
          meta = { hostname = name; };
        };
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./disko-config.nix
          ./configuration.nix
        ];
      };
    }) nodes);
  };
}