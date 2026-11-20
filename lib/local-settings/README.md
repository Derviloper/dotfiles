# local-settings

The default for the flake's `local-settings` input, and deliberately empty.

Some settings belong to one machine rather than to a host. desktop01's display
scale is one: the VM runs at the resolution of whatever display it sits on. Those
go in the gitignored `local/nixos/<host>.nix`, a normal NixOS module that
`lib/mkHost.nix` imports into that host when it exists:

```nix
# local/nixos/desktop01.nix
{ local.hidpi.scale = 2; }
```

The flake can't see gitignored files, so `just build`, `diff`, `switch` and
`boot` pass the directory in as an input override:

```sh
--override-input local-settings path:./local/nixos
```

That prints a "not writing modified lock file" warning, which is expected. A bare
`nixos-rebuild` doesn't pass it and builds against this empty stub instead, so
rebuild through `just`.

`just deploy` doesn't pass it either: these settings are for the machine you're
on, which is rebuilt in place.
