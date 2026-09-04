{
  config,
  lib,
  pkgs,
  ...
}:
let
  # USB dongles passed through to the imperatively-managed `haos` libvirt domain,
  # matched by VID:PID (see docs/haos-domain.xml.example). When one of these
  # resets and re-enumerates while the VM is running, libvirt does NOT recover the
  # passthrough on its own: the host serial driver reclaims the device and the
  # guest silently loses its radio. The rules below (1) keep the host driver off
  # these devices and (2) re-attach them to the running VM on every hotplug.
  haosUsbDevices = [
    {
      name = "zigbee";
      vendor = "10c4";
      product = "ea60";
    } # SONOFF Dongle Plus MG24
    {
      name = "ir";
      vendor = "0403";
      product = "6015";
    } # FTDI FT230X UART (IR)
  ];

  # A libvirt hostdev fragment matching purely by VID:PID (no host <address>), so
  # `virsh attach-device` re-binds whichever bus/device number it currently has.
  hostdevXml =
    d:
    pkgs.writeText "haos-hostdev-${d.name}.xml" ''
      <hostdev mode='subsystem' type='usb' managed='yes'>
        <source startupPolicy='optional'>
          <vendor id='0x${d.vendor}'/>
          <product id='0x${d.product}'/>
        </source>
      </hostdev>
    '';

  # (1) Keep the host driver off it: unbind the freshly-probed USB interface from
  # whatever kernel driver (cp210x, ftdi_sio) grabbed it, so the host never holds
  # a stale /dev/ttyUSB* for a device that belongs to the VM.
  driverOff = pkgs.writeShellScript "haos-usb-driver-off" ''
    intf="$1" # e.g. 3-2:1.0
    link="/sys/bus/usb/devices/$intf/driver"
    [ -e "$link" ] || exit 0
    drv=$(basename "$(readlink -f "$link")")
    echo "$intf" > "/sys/bus/usb/drivers/$drv/unbind" 2>/dev/null || true
  '';

  # (2) Re-attach a single dongle to the running domain. `attach-device` does NOT
  # deduplicate — after a re-enumeration the device has a new bus/devnum, so a bare
  # attach would leave the old entry behind as a ghost. Detach every existing live
  # entry for this VID:PID first (each call removes one; it errors once none
  # remain), then attach whatever is currently present.
  #
  # The wait loop is load-bearing, not defensive. libvirt-guests suspends the domain
  # to disk on shutdown (ON_SHUTDOWN=suspend) and restores it on boot, and the save
  # image embeds the *host* USB address (bus/devnum) the dongle had when it was last
  # attached. After a reboot the dongle re-enumerates with a different devnum, the
  # restored domain finds nothing at the recorded address, and startupPolicy='optional'
  # silently drops the hostdev (`missing='yes'` in the live XML) — the guest comes up
  # with no radio. This unit is what repairs that, so it must not run before the
  # restore finishes. Ordering alone cannot express that: libvirt-guests.service is
  # Type=exec, so systemd calls it "started" the instant it execs, ~25s before the
  # guest is actually running. Hence: poll for the domain instead of bailing out.
  # (Issuing virsh calls into a just-started libvirtd also segfaulted the daemon.)
  reattach =
    d:
    pkgs.writeShellScript "haos-usb-reattach-${d.name}" ''
      virsh="${pkgs.libvirt}/bin/virsh --connect qemu:///system"
      i=0
      while [ "$i" -lt 180 ] && ! $virsh domstate haos 2>/dev/null | grep -q running; do
        i=$((i + 1))
        sleep 1
      done
      $virsh domstate haos 2>/dev/null | grep -q running || exit 0

      # Repairing a hostdev means detaching it first, and the guest sees that as
      # an unplug: enough to kill ZHA's open serial handle and take every Zigbee
      # device offline until Home Assistant is restarted. This unit is
      # Type=oneshot without RemainAfterExit, so it is never "active" and
      # switch-to-configuration starts it again on *every* nixos-rebuild --
      # meaning without this check, each deploy silently broke Zigbee for no
      # reason. RemainAfterExit is not the fix: it would make the udev-triggered
      # hotplug path a no-op, which is the whole point of the unit.
      #
      # So: only touch the domain when the attachment is actually wrong. A
      # hostdev that is present and resolved to the address the dongle currently
      # occupies needs no repair. A missing one, or one still pointing at a
      # pre-re-enumeration address, has no matching resolved address and falls
      # through to the detach/attach below.
      liveAddr() {
        $virsh dumpxml haos 2>/dev/null | ${pkgs.libxml2}/bin/xmllint --xpath \
          "string(/domain/devices/hostdev[source/vendor/@id='0x${d.vendor}' and source/product/@id='0x${d.product}']/source/address/@$1)" \
          - 2>/dev/null
      }

      for dev in /sys/bus/usb/devices/*/; do
        [ "$(cat "$dev/idVendor" 2>/dev/null)" = "${d.vendor}" ] || continue
        [ "$(cat "$dev/idProduct" 2>/dev/null)" = "${d.product}" ] || continue
        pluggedBus=$(cat "$dev/busnum" 2>/dev/null)
        pluggedDev=$(cat "$dev/devnum" 2>/dev/null)
        break
      done

      if [ -n "''${pluggedBus:-}" ] &&
        [ "$(liveAddr bus)" = "$pluggedBus" ] &&
        [ "$(liveAddr device)" = "$pluggedDev" ]; then
        echo "${d.name} already attached at bus $pluggedBus device $pluggedDev; leaving it alone"
        exit 0
      fi
      i=0
      while [ "$i" -lt 5 ] && $virsh detach-device haos ${hostdevXml d} --live 2>/dev/null; do
        i=$((i + 1))
        sleep 1
      done
      # Only attach when the dongle is actually plugged in; otherwise leave the
      # domain without the hostdev rather than logging a pointless failure.
      for dev in /sys/bus/usb/devices/*/; do
        [ "$(cat "$dev/idVendor" 2>/dev/null)" = "${d.vendor}" ] || continue
        [ "$(cat "$dev/idProduct" 2>/dev/null)" = "${d.product}" ] || continue
        exec $virsh attach-device haos ${hostdevXml d} --live
      done
    '';

  # The qcow2 cannot live in the Nix store: HAOS self-updates and writes to its
  # own disk continuously, so the image is mutable state by definition. This is
  # therefore an imperative one-shot bootstrap, guarded to run exactly once per
  # machine. It runs the same virt-install invocation the docs describe, rather
  # than defining a frozen XML, so the two cannot drift and libvirt keeps
  # re-deriving the OVMF and machine-type details across QEMU upgrades.
  macFile = config.sops.secrets."haos/mac".path;

  provision = pkgs.writeShellScript "haos-provision" ''
    set -euo pipefail

    img=/var/lib/libvirt/images/haos.qcow2
    install -d -m 0755 /var/lib/libvirt/images
    work=$(mktemp -d -p /var/lib/libvirt/images)
    trap 'rm -rf "$work"' EXIT

    url=$(curl -fsSL https://api.github.com/repos/home-assistant/operating-system/releases/latest |
      jq -r '.assets[] | select(.name | test("^haos_ova-.*[.]qcow2[.]xz$")) | .browser_download_url' |
      head -n1)
    if [ -z "$url" ]; then
      echo "no haos_ova qcow2.xz asset in the latest release" >&2
      exit 1
    fi

    curl -fL "$url" -o "$work/haos.qcow2.xz"
    xz --decompress "$work/haos.qcow2.xz"
    qemu-img resize "$work/haos.qcow2" 64G
    mv "$work/haos.qcow2" "$img"
    chown root:root "$img"

    # Pinning the MAC keeps the router's DHCP reservation valid across a
    # rebuild, so Home Assistant returns on the same address. A libvirt-assigned
    # one is still better than refusing to boot if the secret is unavailable.
    net="bridge=br0,model=virtio"
    if [ -r "${macFile}" ]; then
      net="$net,mac=$(cat "${macFile}")"
    else
      echo "no MAC at ${macFile}; letting libvirt assign one" >&2
    fi

    virt-install --connect qemu:///system \
      --name haos --description "Home Assistant OS" \
      --os-variant generic \
      --memory 12288 --vcpus 4 --cpu host-passthrough --machine q35 \
      --disk path="$img",format=qcow2,bus=scsi \
      --controller type=scsi,model=virtio-scsi \
      --network "$net" \
      --import --graphics none --boot uefi --noautoconsole

    virsh --connect qemu:///system autostart haos
  '';
in
{
  virtualisation.libvirtd.enable = true;

  # virt-install / virt-clone for one-time VM creation; virsh ships with libvirtd.
  environment.systemPackages = [ pkgs.virt-manager ];

  services.udev.extraRules = lib.concatMapStringsSep "\n" (d: ''
    # ${d.name} dongle (${d.vendor}:${d.product}): keep the host serial driver off the
    # interface, disable USB autosuspend (the reset that triggers re-enumeration),
    # and re-attach the device to the running haos VM on every (re)enumeration.
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTRS{idVendor}=="${d.vendor}", ATTRS{idProduct}=="${d.product}", RUN+="${driverOff} %k"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${d.vendor}", ATTR{idProduct}=="${d.product}", ATTR{power/control}="on", TAG+="systemd", ENV{SYSTEMD_WANTS}+="haos-usb-reattach-${d.name}.service"
  '') haosUsbDevices;

  systemd.services = {
    haos-provision = {
      description = "Download and define the Home Assistant OS VM";
      wantedBy = [ "multi-user.target" ];
      requires = [ "libvirtd.service" ];
      after = [
        "libvirtd.service"
        "network-online.target"
        "sops-install-secrets.service"
      ];
      wants = [ "network-online.target" ];

      # Runs exactly once per machine: once the image exists this is inert.
      unitConfig.ConditionPathExists = "!/var/lib/libvirt/images/haos.qcow2";

      path = with pkgs; [
        curl
        jq
        xz
        qemu-utils
        virt-manager
        libvirt
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = provision;
        # A ~400MB download plus decompress and resize; the 90s default would
        # kill this mid-write.
        TimeoutStartSec = "infinity";
      };
    };
  }
  // lib.listToAttrs (
    map (
      d:
      lib.nameValuePair "haos-usb-reattach-${d.name}" {
        description = "Re-attach the ${d.name} USB dongle to the haos libvirt domain";
        # udev only fires this on a USB `add` event, which at boot happens long before
        # there is a domain to attach to. Pull it in from multi-user.target as well so
        # every boot gets one run that outlives the libvirt-guests restore.
        wantedBy = [ "multi-user.target" ];
        after = [
          "haos-provision.service"
          "libvirtd.service"
          "libvirt-guests.service"
        ];
        wants = [ "libvirtd.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = reattach d;
        };
      }
    ) haosUsbDevices
  );
}
