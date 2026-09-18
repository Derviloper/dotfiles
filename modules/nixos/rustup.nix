# Two fixes on top of nixpkgs' rustup, both --replace-fail so that a nixpkgs
# change to either spot breaks the build instead of silently undoing them.
{ pkgs, ... }:
let
  rustup = pkgs.rustup.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # nixpkgs points each downloaded toolchain's interpreter at the glibc rustup
      # was built with, which nothing keeps alive: a nixpkgs bump plus the weekly
      # GC leaves rustc with "required file not found". nix-ld's loader sits at a
      # path that never moves and always runs the current glibc.
      substituteInPlace src/dist/component/package.rs \
        --replace-fail ${pkgs.stdenv.cc.bintools.dynamicLinker} /lib64/ld-linux-x86-64.so.2

      # Without rust-analyzer installed, rustup runs the first one on PATH that is
      # not itself -- but nixpkgs runs it as .rustup-wrapped while every proxy links
      # to the wrapper, so the proxy qualifies and recurses until the limit. Skip
      # the wrapper too, so a missing component is one plain error.
      substituteInPlace src/toolchain.rs \
        --replace-fail \
          '&& !is_same_file(&me, &p).unwrap_or(true);' \
          '&& !is_same_file(&me, &p).unwrap_or(true) && !is_same_file(me.with_file_name("rustup"), &p).unwrap_or(true);'
    '';
    # Small, targeted changes; nixpkgs already ran the (slow, serial) suite.
    doCheck = false;
  });
in
{
  imports = [ ./nix-ld.nix ];

  environment = {
    systemPackages = [ rustup ];

    # Where `cargo install` puts binaries; rustup's own installer adds this line.
    extraInit = ''
      export PATH="$HOME/.cargo/bin:$PATH"
    '';
  };
}
