{ config, ... }:
{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable traefik"
      "--kube-apiserver-arg=oidc-issuer-url=https://authentik.derviloper.de/application/o/kube-apiserver/.well-known/openid-configuration"
      "--kube-apiserver-arg=oidc-client-id=kube-apiserver"
      "--kube-apiserver-arg=oidc-username-claim=email"
      "--kube-apiserver-arg=oidc-groups-claim=groups"
    ];
    autoDeployCharts = {
      argocd = {
        name = "argo-cd";
        repo = "https://argoproj.github.io/argo-helm";
        version = "8.3.0";
        hash = "sha256-pIfbHJ4vafOPttJ/4ZupkObWQHl77KeOhFszkc4jkaQ=";
        targetNamespace = "argocd";
        createNamespace = true;
        values.configs.secret.annotations."sealedsecrets.bitnami.com/managed" = "true";
      };
    };
    manifests = {
      sealed-secret-key.source = config.sops.secrets."sealed-secrets-key.yaml".path;
      applications.source = ./applications.yaml;
    };
  };
}
