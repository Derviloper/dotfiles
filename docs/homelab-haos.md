# Home Assistant OS VM (homelab)

The host configuration provides everything HAOS needs declaratively: a `br0` LAN
bridge over `enp2s0` and `libvirtd` with `admin` in the `libvirtd` group. On a
freshly installed host those are in place after `just install homelab` -- no extra
config needed.

Only the **VM itself is imperative**: HAOS self-updates and continuously writes to
its own disk, so its qcow2 lives as mutable state in `/var/lib/libvirt/images`,
**not** in the Nix store. A redacted dump of the domain is kept at
[haos-domain.xml.example](haos-domain.xml.example). Run the steps below once, on
the host, as `admin`.

## 1 Download the latest HAOS KVM image

```sh
workdir="$(mktemp -d -p "$HOME")"; cd "$workdir"

url="$(nix shell nixpkgs#curl nixpkgs#jq -c bash -c '
  curl -fsSL https://api.github.com/repos/home-assistant/operating-system/releases/latest |
  jq -r ".assets[] | select(.name | test(\"^haos_ova-.*[.]qcow2[.]xz$\")) | .browser_download_url" |
  head -n1')"

nix shell nixpkgs#curl       -c curl -fL "$url" -o haos.qcow2.xz
nix shell nixpkgs#xz         -c xz --decompress haos.qcow2.xz
nix shell nixpkgs#qemu-utils -c qemu-img resize haos.qcow2 64G

sudo install -d -m 0755 /var/lib/libvirt/images
sudo mv haos.qcow2 /var/lib/libvirt/images/haos.qcow2
sudo chown root:root /var/lib/libvirt/images/haos.qcow2
```

## 2 Create and autostart the VM

```sh
virt-install --connect qemu:///system \
  --name haos --description "Home Assistant OS" \
  --os-variant generic \
  --memory 4096 --vcpus 4 --cpu host-passthrough --machine q35 \
  --disk path=/var/lib/libvirt/images/haos.qcow2,format=qcow2,bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --network bridge=br0,model=virtio \
  --import --graphics none --boot uefi --noautoconsole

virsh --connect qemu:///system autostart haos
```

`--memory`/`--vcpus` are sized for this host (16 GiB / 4-core N150). Home
Assistant's working set is about 2 GiB, so 4 GiB leaves it headroom and the
rest to the host's own services (InfluxDB). Without the cap the guest fills
every GiB it is given with page cache, which the host never gets back.

Resize later without recreating the VM. To shrink, lower the current size
before the maximum; to grow, the other way round:

```sh
virsh --connect qemu:///system setmem    haos 4GiB --config
virsh --connect qemu:///system setmaxmem haos 4GiB --config
```

Then shut the guest down and start it again. A reboot from inside Home Assistant
keeps the same QEMU process, and with it the old size. `setmem --live` resizes a
running guest right away through the memory balloon, but only up to the maximum
it was started with. `setvcpus --config` likewise needs that shutdown and
start.

## 3 Reach Home Assistant

First boot takes a few minutes while HAOS prepares its partitions, then open
<http://homeassistant.local:8123> (or `http://<vm-ip>:8123`). Find the VM's IP
from its MAC:

```sh
virsh --connect qemu:///system domiflist haos   # note the MAC
ip neigh show dev br0                            # or check the router's DHCP leases
```

Create a DHCP reservation for that MAC in the router so the address is stable, and
use Home Assistant's own backup system with an off-machine copy — the qcow2 on the
same box is not disaster recovery.

## 4 USB radios (Zigbee / Z-Wave / Bluetooth)

Find the dongle's vendor:product IDs (`nix shell nixpkgs#usbutils -c lsusb`), then:

```sh
virsh --connect qemu:///system shutdown haos
virsh --connect qemu:///system edit haos     # add the <hostdev> below inside <devices>
virsh --connect qemu:///system start haos
```

```xml
<hostdev mode="subsystem" type="usb" managed="yes">
  <source startupPolicy="optional"><vendor id="0x1a86"/><product id="0x55d4"/></source>
</hostdev>
```

`startupPolicy="optional"` lets the VM boot even when a dongle is unplugged —
libvirt skips any missing device instead of refusing to start the whole guest.
Without it (the default, `mandatory`), an absent USB radio blocks the VM from
starting. The dongle is only re-attached on VM start, so reconnect it and restart
the guest to bring the integration back.

## 5 Host metrics (Glances)

The host runs Glances on port 61208, reachable from the LAN only. In Home
Assistant add the **Glances** integration with host `homelab.local` (or the
host's IP), port `61208`, no username/password, SSL off.

## 6 Long-term history (InfluxDB)

The host runs InfluxDB 2 on port 8086, reachable from the LAN only. Its state
lives on the external USB HDD (`/mnt/hdd/influxdb2`, bind-mounted onto
`/var/lib/influxdb2`). The org `homelab`, the bucket `homeassistant` (unlimited
retention) and a write-only token for Home Assistant are provisioned from sops,
so nothing is clicked together on the InfluxDB side.

1. Print the token, and the admin password for the web UI (user `admin`):

   ```sh
   sops decrypt --extract '["influxdb2"]["homeassistantToken"]' hosts/homelab/secrets/sops.yaml
   sops decrypt --extract '["influxdb2"]["adminPassword"]' hosts/homelab/secrets/sops.yaml
   ```

1. Home Assistant wants the organization **ID**, not its name: log in at
   <http://homelab.local:8086> and copy it from the URL, after `/orgs/`.

1. In Home Assistant add the **InfluxDB** integration, pick 2.x, and enter URL
   `http://homelab.local:8086`, that organization ID, bucket `homeassistant` and
   the token.

By default every entity's state changes are written. Include/exclude filters
are YAML-only (`influxdb:` in `configuration.yaml`).

If the disk is missing at boot, `influxdb2.service` refuses to start instead of
initialising an empty database on the SSD; the rest of the host, HAOS included,
boots normally. Reconnect it and `sudo systemctl start influxdb2`, which mounts
it first. The disk holds the only copy of the history. A replacement needs
ext4, an `influxdb2/` directory at its root (the bind-mount source), and its
UUID in `hosts/homelab/default.nix`.

## Maintenance

```sh
virsh --connect qemu:///system list --all
virsh --connect qemu:///system start|shutdown|reboot|console haos
journalctl -u libvirtd
```

## Why `modules/nixos/libvirt-haos.nix` looks the way it does

That module is deliberately verbose and is preserved verbatim from the original
homelab repo. It encodes two failure modes that are not obvious from the code:

- `libvirt-guests` suspends the domain to disk on shutdown and restores it on
  boot, and the save image embeds the **host** USB bus/devnum the dongle had when
  it was last attached. After a reboot the dongle re-enumerates with a different
  devnum, the restored domain finds nothing at the recorded address, and
  `startupPolicy='optional'` silently drops the hostdev -- the guest comes up
  with no radio.
- Issuing `virsh` calls into a just-started `libvirtd` has segfaulted the daemon,
  and `libvirt-guests.service` is `Type=exec`, so systemd calls it "started"
  roughly 25s before the guest is actually running. Hence the polling loop rather
  than plain unit ordering.

Do not "tidy" it without reproducing both.
