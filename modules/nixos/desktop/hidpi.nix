# Everything about scaling the X11 desktop by `local.hidpi.scale`, in one place.
# X11 has no global scale factor, so each toolkit gets its own knob, all derived
# from here.
#
# The right scale depends on the display the VM window sits on, not on the host,
# so no host sets it: a machine that needs one puts it in its gitignored
# local/nixos/<host>.nix (see lib/local-settings/README.md).
#
# GDK_SCALE alone covers GTK 3/4, Electron and Java 9+. Xft.dpi stays at 96 on
# purpose: Electron multiplies it with GDK_SCALE and GTK4 ignores GDK_DPI_SCALE,
# so raising it would put both at 4x.
#
# The configs edited live rather than generated from Nix can't read the option,
# so they follow these variables at runtime: bspwmrc scales its border by
# GDK_SCALE and passes it to eww's bar for the strut, and rofi's config.rasi
# reads ROFI_DPI.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.local.hidpi) scale;

  cursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    # The 1x size. Everything below that takes a cursor size wants device
    # pixels, except GTK4.
    size = 24;
  };
in
{
  options.local.hidpi.scale = lib.mkOption {
    type = lib.types.ints.positive;
    default = 1;
    example = 2;
    description = ''
      Integer factor to scale the X11 desktop by. 1 leaves everything at the
      toolkits' defaults.
    '';
  };

  config = lib.mkIf (scale > 1) {
    environment.sessionVariables = {
      GDK_SCALE = toString scale;
      QT_SCALE_FACTOR = toString scale;
      ROFI_DPI = toString (96 * scale);
      # home.sessionVariables never reach the X session -- the xsession wrapper
      # doesn't source hm-session-vars.sh -- so these have to come through PAM.
      XCURSOR_THEME = cursor.name;
      XCURSOR_SIZE = toString (cursor.size * scale);
    };

    # The greeter gets GDK_SCALE through PAM like any session, but sets its own
    # cursor size, which defaults to 16.
    services.xserver.displayManager.lightdm.greeters.gtk.cursorTheme = {
      inherit (cursor) name package;
      size = cursor.size * scale;
    };

    home-manager.sharedModules = [
      {
        # XCURSOR_SIZE isn't enough: Electron takes the size from GTK's
        # gtk-cursor-theme-size, so without settings.ini VS Code's cursor stays at 1x.
        home.pointerCursor = {
          inherit (cursor) name package;
          size = cursor.size * scale;
          gtk.enable = true;
          x11.enable = true;
        };
        gtk.enable = true;
        # GTK4 on X11 multiplies gtk-cursor-theme-size by GDK_SCALE (GTK3 doesn't),
        # so it gets the 1x size or Ghostty's cursor ends up at 4x.
        gtk.gtk4.extraConfig.gtk-cursor-theme-size = cursor.size;
      }
    ];
  };
}
