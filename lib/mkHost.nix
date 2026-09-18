# Single host constructor: specialArgs threading, the home-manager block, and
# the disko and sops-nix wiring, once for all hosts.
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

        # Without this, one unmanaged file in the way ("would be clobbered") aborts
        # the whole activation, visibly only in the journal. Move it aside instead.
        backupFileExtension = "hm-bak";

        users.${username} = {
          imports = [ ../hosts/${hostname}/home.nix ];

          # Set here, not threaded through specialArgs, so modules can read
          # config.home.homeDirectory instead of taking an argument.
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
