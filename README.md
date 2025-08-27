# Dotfiles

This repository contains my **Nix configurations**, currently focused on **NixOS server setup**, with plans to extend support for my **personal NixOS system** and **macOS (via nix-darwin)** in the future.

It is structured around [flakes](https://nixos.wiki/wiki/Flakes) and integrates several tools for system management, deployments, and secrets handling.

---

## ✨ Features

### Common across all configurations

- [home-manager](https://github.com/nix-community/home-manager) – user environment management
- [sops-nix](https://github.com/Mic92/sops-nix) – secret management with [Mozilla SOPS](https://github.com/mozilla/sops)
- [zsh](https://www.zsh.org/) + [powerlevel10k](https://github.com/romkatv/powerlevel10k) – shell with a beautiful prompt

---

### 🖥️ Server configuration

**Deployment stack**

- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) – remote NixOS installation
- [disko](https://github.com/nix-community/disko) – declarative disk partitioning
- [deploy-rs](https://github.com/serokell/deploy-rs) – reliable system deployment

**Kubernetes stack**

- [k3s](https://github.com/k3s-io/k3s) – lightweight Kubernetes
- [Argo CD](https://github.com/argoproj/argo-cd) – GitOps continuous delivery
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) – Kubernetes secrets encryption

---

### 🍏 Future macOS configuration

- [nix-darwin](https://github.com/LnL7/nix-darwin) – Nix on macOS

---

## 🚀 Goals

- Maintain reproducible, declarative configurations for servers, desktops, and laptops
- Simplify deployment and secret management
- Expand cross-platform support (NixOS + macOS)
- Provide a foundation for a personal homelab and developer workflow
