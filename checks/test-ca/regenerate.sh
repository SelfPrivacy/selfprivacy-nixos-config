#!/usr/bin/env nix-shell
#!nix-shell -i bash -p step-cli -I nixpkgs=flake:nixpkgs
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

rm -f root_ca.crt root_ca.key intermediate_ca.crt intermediate_ca.key

step certificate create "SelfPrivacy Integration Test CA" \
  root_ca.crt root_ca.key \
  --profile root-ca \
  --not-before=-24h \
  --not-after=87720h \
  --no-password \
  --insecure

step certificate create "SelfPrivacy Integration Test Intermediate CA 1" \
  intermediate_ca.crt intermediate_ca.key \
  --profile intermediate-ca \
  --ca root_ca.crt \
  --ca-key root_ca.key \
  --not-before=-24h \
  --not-after=87600h \
  --no-password \
  --insecure

chmod 0600 root_ca.key intermediate_ca.key
