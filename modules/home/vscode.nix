{
  config,
  lib,
  pkgs,
  ...
}:
{
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
