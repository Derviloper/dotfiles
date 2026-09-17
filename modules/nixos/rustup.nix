# Two fixes on top of nixpkgs' rustup, both --replace-fail so that a nixpkgs
# change to either spot breaks the build instead of silently undoing them.
{ pkgs, ... }:
let
  rustup = pkgs.rustup.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # nixpkgs patchelfs every toolchain rustup downloads, pointing each
      # binary's interpreter at the glibc rustup itself was built with. Nothing
      # keeps that glibc alive: once a nixpkgs bump replaces it, the weekly GC
      # deletes it and rustc stops starting ("required file not found") until
      # the toolchain is reinstalled. nix-ld's loader sits at a path that never
      # moves and always runs the current glibc.
      substituteInPlace src/dist/component/package.rs \
        --replace-fail ${pkgs.stdenv.cc.bintools.dynamicLinker} /lib64/ld-linux-x86-64.so.2

      # When a toolchain lacks rust-analyzer, rustup runs the first one on PATH
      # that is not the same file as itself. But nixpkgs wraps rustup, so the
      # running file is .rustup-wrapped while every proxy links to the wrapper
      # -- and the proxy counts as "some other rust-analyzer", which calls
      # itself until the recursion limit. Skip the wrapper as well, so that a
      # missing component is one plain error instead.
      substituteInPlace src/toolchain.rs \
        --replace-fail \
          '&& !is_same_file(&me, &p).unwrap_or(true);' \
          '&& !is_same_file(&me, &p).unwrap_or(true) && !is_same_file(me.with_file_name("rustup"), &p).unwrap_or(true);'
    '';
    # Only small, targeted changes, and the suite is slow and serial; nixpkgs
    # has already run it against this source.
    doCheck = false;
  });
in
{
  imports = [ ./nix-ld.nix ];

  environment = {
    systemPackages = [ rustup ];

    # Where `cargo install` puts binaries -- the line rustup's own installer
    # adds to a shell profile. Same mechanism as environment.localBinInPath.
    extraInit = ''
      export PATH="$HOME/.cargo/bin:$PATH"
    '';
  };
}
