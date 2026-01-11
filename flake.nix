{
  description = "Derviloper's Nix Config";

  inputs = {
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";

    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";

    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
      ...
    }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map
          (name: {
            inherit name;
            value = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [ ./hosts/${name} ];
            };
          })
          [
            "server01"
          ]
      );

      deploy.nodes =
        let
          deployPkgs = forAllSystems (
            system:
            import nixpkgs {
              inherit system;
              overlays = [
                (self: super: {
                  deploy-rs = {
                    inherit ((deploy-rs.overlays.default self super).deploy-rs) lib;
                    inherit (super) deploy-rs;
                  };
                })
              ];
            }
          );
        in
        builtins.mapAttrs
          (name: sshUser: {
            hostname = name;
            profiles.system = {
              inherit sshUser;
              user = "root";
              remoteBuild = true;
              path =
                deployPkgs.${self.nixosConfigurations.${name}.pkgs.system}.deploy-rs.lib.activate.nixos
                  self.nixosConfigurations.${name};
            };
          })
          {
            server01 = "admin";
          };
    };
}
