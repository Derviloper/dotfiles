{
  # Lets unpatched dynamic binaries (language-server downloads, vendored
  # toolchains) run without patchelf.
  programs.nix-ld.enable = true;
}
