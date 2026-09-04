# desktop01 sets `local.liveConfig.enable`, which symlinks the bspwm, sxhkd and
# eww configs straight into a checkout at ~/Projects/dotfiles. bspwmrc is the
# only autostart entry point -- it launches sxhkd (every keybinding, including
# the terminal) and eww (the bar) -- so if that checkout is missing the symlink
# dangles, bspwm cannot exec its rc, and you get a blank screen with no way to
# open a terminal.
#
# This seeds the checkout before the display manager starts. The repo is public,
# so the clone needs no credential and no ordering against sops.
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

    # Self-healing: runs on a fresh install, after a rebuild straight from
    # GitHub on a machine that never ran the installer, or if the checkout is
    # ever deleted. A no-op once it is there.
    unitConfig.ConditionPathExists = "!${target}/.git";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      Group = config.users.users.${username}.group;
      # A failure here costs a usable desktop, so give a slow link room rather
      # than letting the 90s default kill the clone.
      TimeoutStartSec = 600;
    };

    path = [ pkgs.git ];

    script = ''
      mkdir -p "${home}/Projects"

      # Clone beside the target and move into place, so a pre-existing
      # non-repo directory cannot make `git clone` fail on a non-empty path.
      # Same filesystem, so the move is atomic.
      tmp=$(mktemp -d "${home}/Projects/.seed-XXXXXX")
      trap 'rm -rf "$tmp"' EXIT

      git clone https://github.com/Derviloper/dotfiles "$tmp/dotfiles"

      # Anything already there is kept, not deleted -- a working desktop is
      # worth more than a tidy home directory. rmdir succeeds only on an empty
      # directory, so only real content gets a .bak copy.
      if [ -e "${target}" ]; then
        rmdir "${target}" 2>/dev/null || mv "${target}" "${target}.bak-$(date +%s)"
      fi
      mv "$tmp/dotfiles" "${target}"
    '';
  };
}
