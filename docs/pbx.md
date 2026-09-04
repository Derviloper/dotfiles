# The PBX (asterisk on cluster01)

[Asterisk](https://www.asterisk.org) running as a two-extension SIP PBX, so two
Grandstream devices in two different homes can call each other over the public
internet. There is no trunk: it dials those two handsets and nothing else.

| Extension | Who | Dials |
| --- | --- | --- |
| `1001` | Phone A | `2` to reach Phone B |
| `1002` | Phone B | `1` to reach Phone A |
| `600` | Echo test | speaks your own audio back |
| `601` | Milliwatt | steady 1004 Hz tone |

Everything lives in `kubernetes/cluster01/asterisk/`, except the two firewall
holes, which are in `hosts/server01/default.nix` and need `just deploy server01`
rather than a git push.

## Why it does not look like the other apps

- **`hostNetwork: true`, no Service, no IngressRoute.** RTP needs a contiguous
  UDP range, and a Kubernetes Service cannot express one -- the `LoadBalancer`
  approach minecraft uses would mean 100 enumerated ports and a 100-hostPort
  klipper DaemonSet. It also puts Asterisk on server01's public address
  directly, so the server side is not behind NAT.
- **Nothing addresses server01 by name.** SIP is UDP straight to the origin;
  Cloudflare is not in the path and cannot be. Because Asterisk is not behind
  NAT it needs no `external_media_address`, so the origin IP appears in neither
  the config nor public DNS -- only in the two phones. That keeps the stance in
  [secrets.md](secrets.md) intact.
- **A non-standard SIP port.** 5060 attracts a constant REGISTER/OPTIONS flood.
  See the comment in `values.yaml` for how much this is and is not worth.

## Provisioning a Grandstream

Under the account's SIP settings:

| Field | Phone A | Phone B |
| --- | --- | --- |
| SIP Server | `<server01 origin IP>:5160` | same |
| SIP User ID | `1001` | `1002` |
| Authenticate ID | `1001` | `1002` |
| Authenticate Password | see below | see below |
| Register Expiration | `2` (minutes) | same |
| NAT Traversal | Keep-Alive | same |
| Preferred Vocoder | PCMA, PCMU, G.722 | same |
| Dial Plan | `{ [12] \| 100[12] \| 60[01] }` | same |

The dial plan is the one that bites. Grandstream ships
`{ x+ | \+x+ | *x+ | *xx*x+ }`, which will not send a single digit until you
press SEND or the interdigit timer expires -- so "dial 2" feels broken until you
replace it.

The origin IP is the one in `~/.ssh/config.local`; it is deliberately not in
this repo.

## Passwords

The two SIP passwords are one `pjsip_auth.conf` file inside the
`asterisk-pjsip-auth` SealedSecret in `values.yaml`. `pjsip.conf` pulls it in
with an `#include`, so no credential is ever templated into the ConfigMap.

To rotate:

```sh
just fetch-cert                                     # if local/ is empty
LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32   # once per extension
just seal                                           # paste the Secret below
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: asterisk-pjsip-auth
  namespace: asterisk
stringData:
  pjsip_auth.conf: |
    [auth1001]
    type=auth
    auth_type=userpass
    username=1001
    password=<generated>

    [auth1002]
    type=auth
    auth_type=userpass
    username=1002
    password=<generated>
```

Replace the `SealedSecret` in `values.yaml`, push, then:

```sh
kubectl -n asterisk rollout restart deploy/asterisk
```

That restart is not optional. The pod's `checksum/config` annotation covers the
ConfigMap only, so a re-sealed password reaches the cluster but not the running
Asterisk.

## Checking it

```sh
kubectl -n asterisk logs deploy/asterisk
kubectl -n asterisk exec deploy/asterisk -- asterisk -rx "pjsip show endpoints"
kubectl -n asterisk exec deploy/asterisk -- asterisk -rx "pjsip show contacts"
kubectl -n asterisk exec deploy/asterisk -- asterisk -rx "core show channels"
```

Endpoints are `Unavailable` until the phones register. If a call rings but has
one-way or no audio, it is the RTP range every time: `rtp.conf` and
`allowedUDPPortRanges` have to agree, and the NixOS side needs an actual deploy.
