{
  services = {
    xserver = {
      enable = true;
      windowManager.bspwm.enable = true;
      displayManager.lightdm = {
        enable = true;
        greeters.gtk.enable = true;
      };
      xkb = {
        layout = "de";
        variant = "us";
      };
      videoDrivers = [ "modesetting" ];
    };

    gnome.gnome-keyring.enable = true;
  };

  programs.dconf.enable = true;

  security.pam.services.lightdm.enableGnomeKeyring = true;
}
