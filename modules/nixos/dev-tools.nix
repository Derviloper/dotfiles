# The CLI and native toolchain, system-wide so that root gets the same tools.
# The version managers need more than a package entry on NixOS, so each has
# its own module.
{ pkgs, ... }:
{
  imports = [
    ./nvm.nix
    ./pyenv.nix
    ./rustup.nix
  ];

  # Not listed because every host already has them: curl and dig (dnsutils is
  # the same package) from profiles/base.nix, ssh from services.openssh, and
  # which from NixOS's required packages.
  environment.systemPackages = with pkgs; [
    file
    jq
    ripgrep
    tree
    unzip
    wget
    zip
    # NixOS only ships these two through environment.defaultPackages, which is
    # a default a host can empty.
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
    # The gcc wrapper exposes only the compiler; cmake and plain Makefiles also
    # call ar, ranlib and ld directly.
    binutils

    gdb
    lldb
    ltrace

    shellcheck
    shfmt
  ];

  # A cap_net_raw wrapper, so that ICMP (-I) and TCP (-T) probes work without
  # sudo. It lives in /run/wrappers/bin, which comes first on PATH.
  programs.traceroute.enable = true;

  # The module adds utempter, so that panes show up in `who`. Its generated
  # tmux.conf, though, pins three settings to values tmux itself has since
  # moved away from; these are tmux's current defaults.
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 10;
    clock24 = true;
  };
}
