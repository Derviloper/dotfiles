{
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # deploy-rs connects as a wheel user and pushes locally-built store paths;
      # without this they are rejected for lacking a signature. Note that this is
      # effectively root-equivalent -- a deliberate tradeoff, see the README.
      trusted-users = [
        "root"
        "@wheel"
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise.automatic = true;
  };
}
