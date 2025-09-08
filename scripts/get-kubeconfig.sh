#!/bin/bash
set -euo pipefail

printf "Enter the server you want to get the kubeconfig from [server01]: "
read -r server
server="${server:-server01}"

rsync -avzP --rsync-path="sudo rsync" $server:/etc/rancher/k3s/k3s.yaml ~/.kube/config

hostname=$(ssh -G "$server" | awk '/^hostname / { print $2 }')

sed -i.bak "s/127.0.0.1/$hostname/g" ~/.kube/config
