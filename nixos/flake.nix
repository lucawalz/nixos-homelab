{
  description = "NixOS homelab configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, agenix, ... }: {
    nixosConfigurations = {
      master = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          meta = { hostname = "master"; };
        };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./configuration.nix
          ./disko-config.nix
        ];
      };
      
      worker-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          meta = { hostname = "worker-1"; };
        };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./configuration.nix
          ./disko-config.nix
        ];
      };
    };
  };
}
