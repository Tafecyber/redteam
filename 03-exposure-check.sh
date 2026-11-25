#!/usr/bin/env bash
# 03-exposure-check.sh — Attack 4 flavour (what's reachable from the WAN side).
# Authorised IRTX use only. Run from KaliWAN.
#
# Fast TCP-connect probe of the ports that SHOULD be filtered on a pfSense WAN.
# Prints OPEN / BLOCKED for each, with no extra tools (pure bash /dev/tcp).
# Use it to confirm the perimeter only exposes the intended HAProxy services and
# that management surfaces (SSH, the GUI, Proxmox) are not reachable from outside.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

mapfile -t TARGETS < <(load_targets "${1:-targets.txt}")
require_targets

# port:label — the ones worth proving are shut from the WAN.
CHECKS=(
  "22:SSH"          "80:HTTP-admin"   "443:HTTPS-front"
  "8443:HTTPS-alt"  "8006:Proxmox"    "3306:MySQL"
  "389:LDAP"        "5985:WinRM"      "10000:webmin"
)
OUT="${RUN_DIR}/exposure.txt"; : > "$OUT"

probe() { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

for t in "${TARGETS[@]}"; do
  line; log "Exposure → $t"
  printf '\n# %s\n' "$t" >> "$OUT"
  for c in "${CHECKS[@]}"; do
    port="${c%%:*}"; name="${c#*:}"
    if probe "$t" "$port"; then
      warn "  OPEN     ${port}/${name}"
      printf '  OPEN     %-6s %s\n' "$port" "$name" >> "$OUT"
    else
      log  "  BLOCKED  ${port}/${name}"
      printf '  BLOCKED  %-6s %s\n' "$port" "$name" >> "$OUT"
    fi
  done
done

line
ok "Exposure map: $OUT"
echo "Expected from the WAN: only the HAProxy front-end port(s) OPEN, the rest BLOCKED."
