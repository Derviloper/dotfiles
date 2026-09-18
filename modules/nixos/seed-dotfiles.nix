# desktop01's `local.liveConfig.enable` symlinks the bspwm, sxhkd and eww configs
# into a checkout at ~/Projects/dotfiles. bspwmrc is the only autostart entry
# point -- it launches sxhkd (every keybinding, including the terminal) and eww --
# so a missing checkout means a blank screen with no way to open a terminal.
# Seeding it before the display manager avoids that; the repo is public, so the
# clone needs no credential and no ordering against sops.
{
  config,
  pkgs,
  username,
  ...
}:
let
  home = config.users.users.${username}.home;
  target = "${home}/Projects/dotfiles";
in
{
  systemd.services.seed-dotfiles = {
    description = "Seed the dotfiles checkout that live configs symlink into";

    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Self-healing: runs on a fresh install or if the checkout is ever deleted,
    # and is a no-op once it is there.
    unitConfig.ConditionPathExists = "!${target}/.git";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      Group = config.users.users.${username}.group;
      # A failure here costs a usable desktop; give a slow link room.
      TimeoutStartSec = 600;
    };

    path = [ pkgs.git ];

    script = ''
      mkdir -p "${home}/Projects"

      # Clone beside the target and move into place (atomic, same filesystem), so
      # a pre-existing non-repo directory cannot fail the clone on a non-empty path.
      tmp=$(mktemp -d "${home}/Projects/.seed-XXXXXX")
      trap 'rm -rf "$tmp"' EXIT

      git clone https://github.com/Derviloper/dotfiles "$tmp/dotfiles"

      # Keep whatever is already there: rmdir succeeds only on an empty directory,
      # so only real content gets a .bak copy.
      if [ -e "${target}" ]; then
        rmdir "${target}" 2>/dev/null || mv "${target}" "${target}.bak-$(date +%s)"
      fi
      mv "$tmp/dotfiles" "${target}"
    '';
  };
}
