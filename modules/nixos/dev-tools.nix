# The CLI and native toolchain, system-wide so root gets the same tools. The
# version managers need more than a package entry on NixOS, hence a module each.
{ pkgs, ... }:
{
  imports = [
    ./nvm.nix
    ./pyenv.nix
    ./rustup.nix
  ];

  # Absent because every host has them already: curl and dig from
  # profiles/base.nix, ssh from services.openssh, which from NixOS itself.
  environment.systemPackages = with pkgs; [
    file
    jq
    ripgrep
    tree
    unzip
    wget
    zip
    # Only in environment.defaultPackages, which a host can empty.
    rsync
    strace

    ethtool
    nmap
    pciutils
    traceroute # the man page; the binary on PATH is the wrapper below
    usbutils

    cmake
    gcc
    gnumake
    ninja
    pkg-config
    # The gcc wrapper exposes only the compiler, not ar, ranlib and ld.
    binutils

    gdb
    lldb
    ltrace

    shellcheck
    shfmt
  ];

  # A cap_net_raw wrapper in /run/wrappers/bin (first on PATH), so ICMP (-I) and
  # TCP (-T) probes work without sudo.
  programs.traceroute.enable = true;

  # The module adds utempter so panes show up in `who`, but its generated
  # tmux.conf pins three settings to stale values; these are tmux's own defaults.
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 10;
    clock24 = true;
  };
}
