{
  config,
  lib,
  pkgs,
  ...
}:
{
  # `--wait` is not optional. `code` normally hands the file to the already
  # running window and exits immediately, which to anything invoking $EDITOR
  # looks like "the user saved without changing anything" -- git would commit an
  # empty message, and scripts/create-secret.sh would seal the unedited
  # skeleton. With --wait it blocks until the tab is closed.
  home.sessionVariables = {
    EDITOR = "code --wait";
    VISUAL = "code --wait";
  };

  # Seeded once rather than managed: VS Code rewrites argv.json itself, so a
  # store-managed file would fight it.
  home.activation.seedVscodeArgv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${config.home.homeDirectory}/.vscode/argv.json"
    source=${lib.escapeShellArg (
      pkgs.writeText "argv.json" ''
        {
          "password-store": "gnome-libsecret"
        }
      ''
    )}

    if [ ! -e "$target" ]; then
      run mkdir -p "$(dirname "$target")"
      run install -m 0644 "$source" "$target"
    fi
  '';
}
