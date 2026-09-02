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

        # Without this, a single unmanaged file in the way ("would be
        # clobbered") aborts the whole activation -- so nothing home-manager
        # owns gets updated, and the failure is only visible in the journal.
        # Move the stray file aside instead and keep going.
        backupFileExtension = "hm-bak";

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
