{ ... }:
{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable traefik"
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
      applications.source = ./applications.yaml;
    };
  };
}
