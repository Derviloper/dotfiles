{
  description = "NixOS configurations for desktop01, homelab, and server01";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      deploy-rs,
      treefmt-nix,
      git-hooks,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;

      # The one place a host is declared. Drives both nixosConfigurations and
      # deploy.nodes; a host without `deploy` is rebuilt in place.
      hosts = {
        desktop01.username = "derviloper";

        homelab = {
          username = "admin";
          deploy.sshUser = "admin";
        };

        server01 = {
          username = "admin";
          deploy.sshUser = "admin";
          # The guest builds its own toplevel. Flip to false and `nix copy` if it
          # ever runs short of RAM while k3s is live.
          deploy.remoteBuild = true;
        };
      };

      deployHosts = lib.filterAttrs (_: cfg: cfg ? deploy) hosts;

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      preCommit = git-hooks.lib.${system}.run {
        src = ./.;
        # nixos-generate-config output is kept byte-identical, so the linters
        # must not have opinions about it.
        excludes = [ "hosts/.*/hardware\\.nix" ];

        hooks = {
          treefmt.enable = true;
          treefmt.package = treefmtEval.config.build.wrapper;
          statix.enable = true;
          deadnix.enable = true;
          gitleaks = {
            enable = true;
            name = "gitleaks";
            entry = "${pkgs.gitleaks}/bin/gitleaks git --pre-commit --redact --staged";
            pass_filenames = false;
          };
        };
      };
    in
    {
      nixosConfigurations = lib.mapAttrs (
        hostname: cfg:
        import ./lib/mkHost.nix {
          inherit
            inputs
            hostname
            system
            ;
          inherit (cfg) username;
        }
      ) hosts;

      deploy.nodes = lib.mapAttrs (hostname: cfg: {
        hostname = cfg.deploy.hostname or hostname;
        inherit (cfg.deploy) sshUser;
        profiles.system = {
          user = "root";
          remoteBuild = cfg.deploy.remoteBuild or false;
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${hostname};
        };
      }) deployHosts;

      checks.${system} =
        # `nix flake check` only *evaluates* nixosConfigurations; building the
        # toplevels is what catches a package broken on a new nixpkgs.
        lib.mapAttrs' (
          hostname: _:
          lib.nameValuePair "toplevel-${hostname}"
            self.nixosConfigurations.${hostname}.config.system.build.toplevel
        ) hosts
        // (deploy-rs.lib.${system}.deployChecks self.deploy)
        // {
          formatting = treefmtEval.config.build.check self;
          pre-commit = preCommit;
        };

      formatter.${system} = treefmtEval.config.build.wrapper;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = preCommit.enabledPackages;

        shellHook = ''
          ${preCommit.shellHook}

          # `nix develop` always lands in bash. Hand over to the same zsh + p10k
          # the hosts run -- but only for a genuinely interactive session.
          # `nix develop -c <cmd>` and CI must stay in bash: there, $- has no
          # `i`, and exec'ing a shell would mean the command never runs.
          # Set NO_DEV_ZSH=1 to opt out.
          case $- in
            *i*)
              if [ -t 0 ] && [ -z "''${NO_DEV_ZSH:-}" ] && command -v zsh > /dev/null 2>&1; then
                exec zsh
              fi
              ;;
          esac
        '';

        packages = with pkgs; [
          # secrets
          sops
          age
          ssh-to-age
          # deployment
          deploy-rs.packages.${system}.default
          # kubernetes
          kubectl
          kubernetes-helm
          kubeseal
          # nix tooling
          just
          nixfmt
          statix
          deadnix
          nvd
          nh
        ];
      };
    };
}
