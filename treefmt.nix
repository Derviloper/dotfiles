{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    yamlfmt.enable = true;
    shfmt.enable = true;
    mdformat.enable = true;
  };

  settings.global.excludes = [
    # sops writes its own layout. Reformatting churns every secret file and the
    # next `sops` edit would just churn it back.
    "hosts/*/secrets/*"
    # Generator output -- kept byte-identical to nixos-generate-config.
    "hosts/*/hardware.nix"
    # Vendored upstream.
    "modules/nixos/zsh/p10k.zsh"
    # Go templates, not YAML.
    "kubernetes/**/templates/*.yaml"
    "*.lock"
    "LICENSE"
  ];
}
