#!/bin/bash
set -e

nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./hosts/server01/hardware-configuration.nix --flake .#server01 --target-host server01
