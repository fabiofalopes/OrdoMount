#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$ORDO_DIR/logs"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ordo"
STATE_FILE="$CACHE_DIR/logrotate.state"
CONF_FILE="$CACHE_DIR/logrotate.conf"

mkdir -p "$CACHE_DIR"

cat >"$CONF_FILE" <<EOF
$LOG_DIR/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d
}
EOF

if command -v logrotate >/dev/null 2>&1; then
    logrotate -s "$STATE_FILE" "$CONF_FILE"
    exit 0
fi

# Fallback: basic daily rotation without logrotate.
# - Copy/Truncate to avoid interacting with a running writer.
# - Keep 14 most recent rotated logs per file.

today="$(date +%Y%m%d)"

shopt -s nullglob
for log_file in "$LOG_DIR"/*.log; do
    if [[ ! -s "$log_file" ]]; then
        continue
    fi

    rotated="$log_file-$today"
    if [[ -e "$rotated" || -e "$rotated.gz" ]]; then
        continue
    fi

    cp -- "$log_file" "$rotated"
    : >"$log_file"

    if command -v gzip >/dev/null 2>&1; then
        gzip -f "$rotated" || true
    fi

    rotated_candidates=("$log_file"-*)
    if [[ ${#rotated_candidates[@]} -gt 14 ]]; then
        mapfile -t sorted < <(ls -1t -- "${rotated_candidates[@]}" 2>/dev/null || true)
        if [[ ${#sorted[@]} -gt 14 ]]; then
            for prune_file in "${sorted[@]:14}"; do
                rm -f -- "$prune_file" || true
            done
        fi
    fi
done
