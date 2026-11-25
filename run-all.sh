#!/usr/bin/env bash
# run-all.sh — runs recon → exposure → default-creds in order, one evidence folder.
# Attack 3 (EICAR) stays manual because it needs an authorised session on a host.
set -uo pipefail
cd "$(dirname "$0")"

# Share ONE evidence folder across all three stages.
export EVID_ROOT="./evidence"
TS="$(date +%Y%m%d-%H%M%S)"; export RUN_TS="$TS"

echo "=== Cluster 5 red-team run @ $TS ==="
bash ./01-recon.sh          "${1:-targets.txt}"
bash ./03-exposure-check.sh "${1:-targets.txt}"
bash ./02-default-creds.sh  "${1:-targets.txt}"
echo "=== done — evidence under ./evidence/ ==="
