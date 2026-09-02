# The k3s cluster (server01)

Single-node [k3s](https://k3s.io) with [Argo CD](https://argo-cd.readthedocs.io)
doing GitOps against this repository.

## Bootstrap chain

1. `hosts/server01/default.nix` enables k3s and delivers two manifests through
   `services.k3s.manifests`: the sops-decrypted sealed-secrets controller key,
   and `kubernetes/cluster01/applications.yaml`.
1. `services.k3s.autoDeployCharts.argocd` installs Argo CD itself.
1. `applications.yaml` is an app-of-apps that recurses through
   `kubernetes/cluster01/**/application.yaml` and takes over from there.

So the *first* Argo CD install comes from NixOS, and everything after is Argo CD
managing itself. Changing `applications.yaml` requires a NixOS deploy, not just
a git push.

## Access

Admin UIs are **not** published. Reach them over port-forwards:

```sh
just kubeconfig server01

kubectl -n argocd port-forward svc/argocd-server 8080:80
kubectl -n traefik port-forward deploy/traefik 9000:9000
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

The Kubernetes Dashboard needs a token. Mint a short-lived one:

```sh
kubectl -n kubernetes-dashboard create token dashboard-admin --duration=1h
```

There is deliberately no long-lived token Secret. The previous configuration
shipped a legacy `kubernetes.io/service-account-token` bound to `cluster-admin`
that never expired and could not be revoked without deleting the ServiceAccount.

## Secrets

Cluster secrets are [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets):
asymmetrically encrypted to the controller, safe to commit. Create one with:

```sh
just seal
```

which needs `local/server01/sealed-secrets-certificate.pem` (gitignored -- pull
it with `kubeseal --fetch-cert`).

## Upgrading charts

Chart versions are pinned in each `application.yaml` and updated by Renovate.
Two rules learned the hard way:

- Bump one chart at a time and let it sync before the next.
- **Never** bump `sealed-secrets` and `traefik` in the same sync. If sealing
  breaks you lose the Cloudflare API token, and ACME goes with it.

## Pausing GitOps

Before any disruptive change to the node:

```sh
argocd app set applications --sync-policy none
```

`prune: true` and `selfHeal: true` are on, so Argo CD reconciling against a
moving target during a migration can delete live workloads.
