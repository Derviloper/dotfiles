{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Derviloper";
        email = "derviloper@gmx.de";
        # Provisioned out of band -- see docs/secrets.md. Deliberately not
        # shipped in this repo.
        signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      };
      gpg.format = "ssh";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };
}
