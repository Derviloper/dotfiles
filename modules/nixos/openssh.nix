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

  services.fail2ban.enable = true;

  programs.ssh.knownHosts."github.com" = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}
