# Everything VMware-specific, in one place. Retiring the VM is deleting this
# file and one host directory -- which is why the ENS1371 audio workaround lives
# here rather than in modules/nixos/desktop/sound.nix.
{ lib, pkgs, ... }:
{
  virtualisation.vmware.guest.enable = true;

  fileSystems."/mnt/hgfs" = {
    device = ".host:/";
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
    options = [
      "allow_other"
      "auto_unmount"
      "defaults"
      "gid=100"
      "uid=1000"
      "umask=022"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=5s"
    ];
  };

  # VMware's emulated audio chip (ENS1371) has jittery IRQ delivery; the
  # default 1024-frame period drains before the next interrupt arrives.
  # Larger period + generous headroom absorbs the jitter.
  services.pipewire.wireplumber.extraConfig."51-vmware-alsa-buffers" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "~alsa_output\\..*"; } ];
        actions.update-props = {
          "api.alsa.period-size" = 2048;
          "api.alsa.headroom" = 8192;
          "session.suspend-timeout-seconds" = 0;
        };
      }
    ];
  };

  # Resize the guest display to match the host window.
  home-manager.sharedModules = [
    {
      systemd.user.services.vmware-autofit = {
        Unit = {
          Description = "Apply preferred resolution to Virtual-1 on RandR changes";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe (
            pkgs.writeShellApplication {
              name = "vmware-autofit";
              runtimeInputs = with pkgs; [
                xrandr
                xev
              ];
              text = ''
                xrandr --output Virtual-1 --preferred || true
                xev -root -event randr | while IFS= read -r line; do
                  if [[ "$line" == RRScreenChangeNotify* ]]; then
                    xrandr --output Virtual-1 --preferred || true
                  fi
                done
              '';
            }
          );
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    }
  ];
}
