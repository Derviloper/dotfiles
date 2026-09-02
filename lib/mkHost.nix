# Single host constructor. Everything that was duplicated verbatim across the
# three old flakes -- specialArgs threading, the home-manager block, disko and
# sops-nix wiring -- lives here exactly once.
{
  inputs,
  hostname,
  system,
  username,
}:
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs hostname username; };

  modules = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    ../hosts/${hostname}

    {
      nixpkgs.hostPlatform = system;
      networking.hostName = hostname;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = { inherit inputs username; };

        users.${username} = {
          imports = [ ../hosts/${hostname}/home.nix ];

          # Set here rather than threaded through specialArgs, so modules can
          # read config.home.homeDirectory instead of taking it as an argument.
          home = {
            inherit username;
            homeDirectory = "/home/${username}";
          };

          programs.home-manager.enable = true;
        };
      };
    }
  ];
}
