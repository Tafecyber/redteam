#!/usr/bin/env bash
# 01-recon.sh — Attack 1 (Reconnaissance), automated.
# Authorised IRTX use only. Run from KaliWAN. `bash 01-recon.sh` (Kali is zsh).
#
# What it does, per target:
#   1. Full TCP port scan (-Pn, pfSense won't answer ping).
#   2. Top-20 UDP scan (catches OpenVPN 1194/udp, which a default TCP scan misses).
#   3. -sV -sC service+script scan on whatever TCP ports came back open.
# All three saved with -oA so you get .nmap/.gnmap/.xml for the evidence log.
#
# Expected result on a properly hardened pfSense: 2 open TCP ports (the HAProxy
# front ends, e.g. 443/8443) and nothing else. "Only two ports" IS the finding.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

need nmap "apt install nmap"
mapfile -t TARGETS < <(load_targets "${1:-targets.txt}")
require_targets

OUT="${RUN_DIR}/recon"; mkdir -p "$OUT"
summary="${OUT}/_summary.txt"; : > "$summary"

for t in "${TARGETS[@]}"; do
  line; log "Recon → $t"
  base="${OUT}/${t//./_}"

  # 1. Full TCP sweep. --min-rate keeps it quick on a quiet lab net.
  log "  full TCP scan (1-65535)…"
  sudo nmap -Pn -n -sS -p- --min-rate 1500 --open -oA "${base}_tcp" "$t" \
       >/dev/null 2>&1 || warn "  tcp scan returned non-zero"

  # Pull the open TCP ports out of the greppable output.
  ports="$(grep -oP '\d+/open/tcp' "${base}_tcp.gnmap" 2>/dev/null \
            | cut -d/ -f1 | paste -sd, -)"

  # 2. Top UDP ports (OpenVPN etc.). Slow-ish but only 20 ports.
  log "  top-20 UDP scan…"
  sudo nmap -Pn -n -sU --top-ports 20 --open -oA "${base}_udp" "$t" \
       >/dev/null 2>&1 || true

  # 3. Service + default-script scan on the open TCP ports only.
  if [[ -n "$ports" ]]; then
    ok "  open TCP: $ports"
    log "  service/script scan on $ports…"
    nmap -Pn -n -sV -sC -p "$ports" -oA "${base}_svc" "$t" >/dev/null 2>&1 || true
    printf '%s\tTCP open: %s\n' "$t" "$ports" >> "$summary"
  else
    warn "  no open TCP ports found (expected on a well-filtered WAN face)"
    printf '%s\tTCP open: none\n' "$t" >> "$summary"
  fi
done

line
ok "Recon done. Evidence: $OUT"
ok "One-line summary per target:"; cat "$summary"
cat <<'NOTE'

Reading the result for your report:
  • 2 open ports + clean -sC output  → controls held. Write it up as "no finding,
    perimeter exposes only the intended HAProxy services." That is the expected,
    passing outcome — not a failure on your part.
  • A surprise port (22/SSH, 80 admin, 8006 Proxmox, a second mgmt GUI) → note it,
    screenshot the -sV line, and that becomes a real finding. Groups that split
    their 2 IPs across two pfSense sometimes leave the HA/secondary node softer.
NOTE
