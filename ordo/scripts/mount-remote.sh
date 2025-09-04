#!/bin/bash

# Mount a single rclone remote with VFS caching
# Usage: ./mount-remote.sh <remote-name>

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
MOUNT_BASE="/media/$USER"
LOG_DIR="$ORDO_DIR/logs"

# Simplified mount settings for browsing (no cache needed)
TIMEOUT="30s"
RETRIES="1"

# Check arguments
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <remote-name>"
    exit 1
fi

remote="$1"
mount_point="$MOUNT_BASE/$remote"
log_file="$LOG_DIR/mount-$remote.log"

# Ensure directories exist
sudo mkdir -p "$MOUNT_BASE" 2>/dev/null || mkdir -p "$HOME/mounts"  # Fallback if no sudo
mkdir -p "$LOG_DIR" "$mount_point"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

log "Mounting remote: $remote"

# Check if already mounted
if mountpoint -q "$mount_point" 2>/dev/null; then
    log "WARNING: $mount_point is already mounted"
    exit 0
fi

# Robust mount for browsing with timeout protection
log "Executing robust rclone mount for browsing..."

rclone mount "$remote:" "$mount_point" \
    --timeout "$TIMEOUT" \
    --retries "$RETRIES" \
    --daemon \
    --allow-non-empty \
    --daemon-timeout "60s" \
    --vfs-cache-mode minimal \
    --vfs-read-chunk-size 32M \
    --vfs-read-chunk-size-limit 1G \
    --buffer-size 32M \
    --dir-cache-time 5m \
    --poll-interval 1m \
    --log-file "$log_file" \
    --log-level INFO

# Wait a moment for mount to establish
sleep 2

# Verify mount success
if mountpoint -q "$mount_point" 2>/dev/null; then
    log "SUCCESS: $remote mounted at $mount_point"
    
    # Test basic functionality
    if ls "$mount_point" &>/dev/null; then
        log "SUCCESS: Mount is accessible"
    else
        log "WARNING: Mount exists but may not be fully accessible"
    fi
else
    log "ERROR: Mount failed for $remote"
    exit 1
fi