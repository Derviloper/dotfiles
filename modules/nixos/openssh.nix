{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    extraConfig = ''
      PermitEmptyPasswords no
      ClientAliveInterval 300
      ClientAliveCountMax 3
    '';
  };

  services.fail2ban = {
    enable = true;
    # A plain 10 minute ban just paces a scanner: one address on server01 was
    # banned 297 times in a week. Each ban now doubles the last, counting bans
    # from every jail, so a host found probing SIP starts SSH bans longer too.
    bantime-increment = {
      enable = true;
      maxtime = "1w";
      overalljails = true;
    };
  };

  programs.ssh.knownHosts."github.com" = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}
