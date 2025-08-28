#!/bin/bash

# Remount all configured remotes (useful after connectivity issues)
# Usage: ./remount-all.sh

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ORDO_DIR/config/remotes.conf"
LOG_FILE="$ORDO_DIR/logs/remount.log"
MOUNT_BASE="$HOME/mounts"

# Ensure directories exist
mkdir -p "$ORDO_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting remount process"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Read configured remotes
configured_remotes=()
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    remote=$(echo "$line" | xargs)
    [[ -n "$remote" ]] && configured_remotes+=("$remote")
done < "$CONFIG_FILE"

if [[ ${#configured_remotes[@]} -eq 0 ]]; then
    log "WARNING: No remotes configured"
    exit 0
fi

log "Configured remotes: ${configured_remotes[*]}"

# Remount each configured remote
remounted_count=0
failed_count=0

for remote in "${configured_remotes[@]}"; do
    log "Processing remote: $remote"
    mount_point="$MOUNT_BASE/$remote"
    
    # Unmount if currently mounted (even if broken)
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log "Unmounting existing mount: $remote"
        if fusermount -u "$mount_point" 2>/dev/null; then
            log "Successfully unmounted $remote"
        else
            log "WARNING: Failed to unmount $remote cleanly"
        fi
        sleep 1
    fi
    
    # Attempt to mount
    log "Mounting $remote..."
    if "$SCRIPT_DIR/mount-remote.sh" "$remote"; then
        log "SUCCESS: Remounted $remote"
        ((remounted_count++))
    else
        log "ERROR: Failed to remount $remote"
        ((failed_count++))
    fi
done

log "Remount complete: $remounted_count remounted, $failed_count failed"

if [[ $failed_count -gt 0 ]]; then
    exit 1
fi