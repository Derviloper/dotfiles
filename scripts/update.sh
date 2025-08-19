#!/bin/bash
set -euo pipefail

printf "Enter the server you want to install [server01]: "
read -r server
server="${server:-server01}"

nix run github:serokell/deploy-rs -- .#"$server"
