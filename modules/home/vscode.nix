{
  config,
  lib,
  pkgs,
  ...
}:
{
  # `--wait` is not optional: `code` otherwise hands the file to the running
  # window and exits, which to anything invoking $EDITOR looks like the user saved
  # nothing -- an empty commit message, or a sealed unedited secret skeleton.
  home.sessionVariables = {
    EDITOR = "code --wait";
    VISUAL = "code --wait";
  };

  # Seeded once, not managed: VS Code rewrites argv.json itself.
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
