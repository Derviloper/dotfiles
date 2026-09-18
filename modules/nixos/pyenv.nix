# pyenv builds every CPython from source, and NixOS has no /usr/include or
# /usr/lib for configure to search. Without the hook below, `pyenv install`
# succeeds with warnings while quietly dropping ssl, sqlite3, readline and tkinter.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # nixpkgs installs pyenv without upstream's pyenv.d, which holds the hooks
  # that rehash shims after `pip install` and resolve `pyenv install 3.13` to
  # the newest 3.13.x.
  pyenv = pkgs.pyenv.overrideAttrs (old: {
    postInstall = old.postInstall + ''
      cp -R pyenv.d "$out/pyenv.d"
    '';
  });

  libs = with pkgs; [
    bzip2
    gdbm
    libffi
    libuuid
    libxcrypt # _crypt, up to 3.12
    mpdecimal
    ncurses
    openssl
    readline
    sqlite
    tcl
    tk
    # tk.h includes Xlib.h, which tk.pc does not mention
    libx11
    xorgproto
    xz
    zlib
    zstd # compression.zstd, from 3.14
  ];

  toolchain = with pkgs; [
    gcc
    gnumake
    pkg-config
  ];

  # All a finished interpreter references in the store: these libraries, plus
  # the glibc and libgcc of the compiler that linked it.
  runtimeClosure = pkgs.writeText "pyenv-runtime-closure" (
    lib.concatLines (
      map (p: "${lib.getLib p}") (
        libs
        ++ [
          pkgs.gcc.libc
          pkgs.gcc.cc
        ]
      )
    )
  );

  pkgConfigPath = lib.makeSearchPathOutput "dev" "lib/pkgconfig" libs;
  cppflags = lib.concatMapStringsSep " " (p: "-I${lib.getDev p}/include") libs;
  ldflags = lib.concatMapStringsSep " " (
    p: "-L${lib.getLib p}/lib -Wl,-rpath,${lib.getLib p}/lib"
  ) libs;

  installHook = pkgs.writeText "nixos-build-env.bash" ''
    # Sourced by `pyenv install` only, so none of this reaches the shell or the
    # interpreters it builds. From modules/nixos/pyenv.nix in the dotfiles.
    export PATH="${lib.makeBinPath toolchain}:$PATH"
    export PKG_CONFIG_PATH="${pkgConfigPath}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export CPPFLAGS="${cppflags}''${CPPFLAGS:+ $CPPFLAGS}"
    export LDFLAGS="${ldflags}''${LDFLAGS:+ $LDFLAGS}"

    # Those rpaths point into the store, where the weekly GC collects whatever a
    # nixpkgs bump left unreferenced, breaking every interpreter built against it.
    # So each install roots its own closure; `pyenv uninstall` drops the root.
    after_install 'if [ "$STATUS" -eq 0 ]; then
      ${config.nix.package}/bin/nix-store --realise --add-root "$PREFIX/.nix-gc-root" ${runtimeClosure} > /dev/null ||
        echo "pyenv: could not add a GC root for $PREFIX" >&2
    fi'
  '';
in
{
  environment = {
    systemPackages = [ pyenv ];
    etc."pyenv.d/install/nixos-build-env.bash".source = installHook;
  };

  # Order 1400 for the same reason as in nvm.nix.
  programs.zsh.interactiveShellInit = lib.mkOrder 1400 ''
    export PYENV_ROOT="$HOME/.pyenv"
    eval "$(${lib.getExe pyenv} init - zsh)"
  '';
}
