{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Derviloper";
        email = "derviloper@gmx.de";
        # Provisioned out of band, not shipped here -- see docs/secrets.md.
        signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      };
      gpg.format = "ssh";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };
}
