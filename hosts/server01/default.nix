{
  config,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ./hardware.nix
    ../../profiles/server.nix
  ];

  time.timeZone = "Etc/UTC";

  sops.secrets."sealed-secrets-key.yaml" = {
    sopsFile = ./secrets/sealed-secrets-key.yaml;
    key = "";
  };

  boot = {
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    kernel.sysctl = {
      "fs.inotify.max_user_instances" = 512;
      "fs.inotify.max_user_watches" = 2048;
    };
  };

  services = {
    k3s = {
      enable = true;
      role = "server";

      # Pinned so a nixpkgs bump cannot move the control plane inside an unrelated
      # deploy (25.11 defaulted to 1.34, 26.05 to 1.35). Currently the nixpkgs
      # default anyway. Bump as its own change, one minor at a time -- k3s does
      # not support downgrades.
      package = pkgs.k3s_1_35;

      disable = [ "traefik" ];

      autoDeployCharts = {
        argocd = {
          name = "argo-cd";
          repo = "https://argoproj.github.io/argo-helm";
          # The *bootstrap* Argo CD, installed by NixOS before Argo CD manages
          # itself. Renovate only watches kubernetes/**/application.yaml, so keep
          # this in step with kubernetes/cluster01/argocd/application.yaml by hand;
          # drift is invisible until server01 is reinstalled. After a version
          # change, refresh the hash from the `got:` value in the mismatch error of:
          #   nix build .#nixosConfigurations.server01.config.system.build.toplevel
          version = "8.3.0";
          hash = "sha256-pIfbHJ4vafOPttJ/4ZupkObWQHl77KeOhFszkc4jkaQ=";
          targetNamespace = "argocd";
          createNamespace = true;
          values.configs.secret.annotations."sealedsecrets.bitnami.com/managed" = "true";
        };
      };

      manifests = {
        sealed-secret-key.source = config.sops.secrets."sealed-secrets-key.yaml".path;
        applications.source = ../../kubernetes/cluster01/applications.yaml;
      };
    };

    ntp.enable = true;

    # Bans SIP scanners on the asterisk pod, which writes its security log here
    # through a hostPath. Extends the stock [asterisk] jail (its filter, maxretry
    # 10 in 10m, a ban on TCP and UDP). The filter matches every failed-auth
    # event and neither ChallengeSent nor SuccessfulAuth -- checked with
    # fail2ban-regex against this pod's log -- and the phones logged no failure
    # in 30 days of Loki history. So a ban takes a wrong password, e.g. a handset
    # after a reset.
    fail2ban.jails.asterisk.settings = {
      logpath = "/var/log/asterisk/security";
      # The module defaults to the journal, which never sees container output.
      backend = "auto";
      port = 5160;
      # Short for a misconfigured handset; modules/nixos/openssh.nix doubles it
      # for scanners that come back.
      bantime = "1h";
    };

    logrotate.settings.asterisk = {
      files = "/var/log/asterisk/security";
      frequency = "daily";
      rotate = 7;
      compress = true;
      missingok = true;
      notifempty = true;
      # Asterisk holds the file open and never reopens it on its own.
      copytruncate = true;
    };
  };

  # uid 1000 is the container's asterisk user, so the entrypoint's chown leaves
  # this alone. The file must exist before the jail starts: fail2ban refuses to
  # start at all over a missing logpath, which would take the sshd jail with it.
  systemd.tmpfiles.rules = [
    "d /var/log/asterisk 0755 1000 1000 -"
    "f /var/log/asterisk/security 0644 1000 1000 -"
  ];

  networking = {
    firewall = {
      allowedTCPPorts = [
        22 # ssh
        80 # http
        443 # https
        # Not 6443: the API server is cluster-admin and only ever needed from the
        # admin's machine, so it goes through `just tunnel`. Pods still reach it
        # through the 10.42/10.43 rules below.
        25565 # Minecraft
      ];
      # The asterisk pod runs with hostNetwork, so this chain is its entire
      # exposure surface. Keep in step with kubernetes/cluster01/asterisk/values.yaml.
      allowedUDPPorts = [
        5160 # Asterisk SIP signalling
      ];
      allowedUDPPortRanges = [
        {
          from = 10000;
          to = 10099;
        } # Asterisk RTP media
      ];
      allowPing = true;
      pingLimit = "2/second";
      extraInputRules = ''
        ip saddr 10.42.0.0/16 accept
        ip saddr 10.43.0.0/16 accept
      '';
    };

    nftables.enable = true;
  };

  # The authorized key comes from profiles/base.nix.
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  nix.settings.max-jobs = 4;

  system.stateVersion = "25.11";
}
