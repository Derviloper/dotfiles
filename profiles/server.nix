# Headless hosts. Adds log hygiene and drops desktop-oriented defaults.
{
  imports = [ ./base.nix ];

  services = {
    journald = {
      forwardToSyslog = false;
      rateLimitInterval = "30s";
      rateLimitBurst = 1000;
      extraConfig = ''
        [Journal]
        Storage=persistent
        Compress=yes
        SystemMaxUse=200M
        SystemKeepFree=50M
      '';
    };

    logrotate.enable = true;

    printing.enable = false;
  };

  systemd.coredump.enable = false;
}
