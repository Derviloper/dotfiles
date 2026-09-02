#!/usr/bin/env bash
set -euo pipefail

server="${1:-server01}"

rsync -avzP --rsync-path="sudo rsync" "$server:/etc/rancher/k3s/k3s.yaml" ~/.kube/config

hostname=$(ssh -G "$server" | awk '/^hostname / { print $2 }')
sed -i.bak "s/127.0.0.1/$hostname/g" ~/.kube/config
