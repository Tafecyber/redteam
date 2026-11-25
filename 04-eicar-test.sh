#!/usr/bin/env bash
# 04-eicar-test.sh — Attack 3 (benign AV test), helper.
# Authorised IRTX use only.
#
# Drops the EICAR standard test string — harmless text that every AV flags as
# malware — so the blue team's ClamAV/Defender fires and the alert reaches
# central logging. There is NO real malware here; EICAR is an industry test file.
#
# Scope: run this only on a host you are authorised to touch (your own client,
# or another team's box ONLY if you already have an authorised session there and
# the ROE covers it). It writes one file and nothing else.
set -uo pipefail
cd "$(dirname "$0")" 2>/dev/null || true

DROP="${1:-/tmp/eicar.txt}"

# EICAR string is assembled from parts so this script file itself doesn't get
# quarantined before you can run it.
P1='X5O!P%@AP[4\PZX54(P^)7CC)7}'
P2='$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
printf '%s%s\n' "$P1" "$P2" > "$DROP"

echo "[+] EICAR test file written to: $DROP"
echo "    Wait ~5s, then check the blue team detected it. Expected: ClamAV logs"
echo "    '$DROP: ...EICAR... FOUND' and a Malware event in central logging."
echo
echo "    Cleanup after the round:  rm -f '$DROP'"
