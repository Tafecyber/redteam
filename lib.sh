#!/usr/bin/env bash
# lib.sh — shared helpers for the Cluster 5 red-team scripts.
# Sourced by the other scripts; not meant to be run on its own.

# ── Evidence directory ──────────────────────────────────────────────────────
# Everything gets written under ./evidence/<timestamp>/ so a whole round is one
# folder you can zip and attach to the report. Timestamps are UTC-safe local.
RUN_TS="$(date +%Y%m%d-%H%M%S)"
EVID_ROOT="${EVID_ROOT:-./evidence}"
RUN_DIR="${EVID_ROOT}/${RUN_TS}"
mkdir -p "$RUN_DIR"

# ── Pretty logging that also lands in a run log ─────────────────────────────
LOG="${RUN_DIR}/run.log"
_c() { printf '%b\n' "$*"; }                       # colour-aware echo
log()  { _c "\033[0;36m[*]\033[0m $*" | tee -a "$LOG"; }
ok()   { _c "\033[0;32m[+]\033[0m $*" | tee -a "$LOG"; }
warn() { _c "\033[0;33m[!]\033[0m $*" | tee -a "$LOG"; }
err()  { _c "\033[0;31m[-]\033[0m $*" | tee -a "$LOG" >&2; }
line() { _c "\033[0;90m────────────────────────────────────────────\033[0m"; }

# ── Load targets from a file, skipping comments/blanks ──────────────────────
# Usage: mapfile -t TARGETS < <(load_targets targets.txt)
load_targets() {
  local f="${1:-targets.txt}"
  [[ -f "$f" ]] || { err "targets file '$f' not found"; return 1; }
  grep -vE '^\s*(#|$)' "$f" | awk '{print $1}'
}

# ── ROE gate: refuse to run with an empty target list ───────────────────────
require_targets() {
  if [[ "${#TARGETS[@]}" -eq 0 ]]; then
    err "No targets. Un-comment ONLY your assigned group(s) in targets.txt."
    err "This is the ROE guard — it will not scan an empty/placeholder list."
    exit 2
  fi
  warn "About to engage ${#TARGETS[@]} address(es): ${TARGETS[*]}"
  warn "Confirm these are the targets your teacher assigned you."
}

# ── Dependency check ────────────────────────────────────────────────────────
need() { command -v "$1" >/dev/null 2>&1 || warn "missing tool: $1 ($2)"; }
