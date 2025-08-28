#!/bin/bash

# Mount a single rclone remote with VFS caching
# Usage: ./mount-remote.sh <remote-name>

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
MOUNT_BASE="$HOME/mounts"
CACHE_DIR="$ORDO_DIR/cache"
LOG_DIR="$ORDO_DIR/logs"

# Default VFS cache settings
VFS_CACHE_MODE="full"
VFS_CACHE_MAX_SIZE="10G"
VFS_CACHE_MAX_AGE="24h"
VFS_CACHE_POLL_INTERVAL="1m"

# Offline behavior settings
VFS_READ_AHEAD="2G"
VFS_READ_CHUNK_SIZE="128M"
VFS_READ_CHUNK_SIZE_LIMIT="2G"
BUFFER_SIZE="64M"
TIMEOUT="60s"
RETRIES="3"

# Check arguments
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <remote-name>"
    exit 1
fi

remote="$1"
mount_point="$MOUNT_BASE/$remote"
log_file="$LOG_DIR/mount-$remote.log"

# Ensure directories exist
mkdir -p "$MOUNT_BASE" "$LOG_DIR" "$CACHE_DIR" "$mount_point"

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

# Mount with VFS caching
log "Executing rclone mount with VFS caching..."

rclone mount "$remote:" "$mount_point" \
    --vfs-cache-mode "$VFS_CACHE_MODE" \
    --vfs-cache-max-size "$VFS_CACHE_MAX_SIZE" \
    --vfs-cache-max-age "$VFS_CACHE_MAX_AGE" \
    --vfs-cache-poll-interval "$VFS_CACHE_POLL_INTERVAL" \
    --vfs-read-ahead "$VFS_READ_AHEAD" \
    --vfs-read-chunk-size "$VFS_READ_CHUNK_SIZE" \
    --vfs-read-chunk-size-limit "$VFS_READ_CHUNK_SIZE_LIMIT" \
    --buffer-size "$BUFFER_SIZE" \
    --timeout "$TIMEOUT" \
    --retries "$RETRIES" \
    --cache-dir "$CACHE_DIR" \
    --daemon \
    --allow-non-empty \
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