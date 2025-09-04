#!/bin/bash

# Unmount all Ordo rclone mounts
# Usage: ./unmount-all.sh

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
MOUNT_BASE="/media/$USER"
LOG_FILE="$ORDO_DIR/logs/unmount.log"

# Ensure log directory exists
mkdir -p "$ORDO_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting unmount process"

# Find all active rclone mounts in our mount base
active_mounts=$(mount | grep rclone | awk '{print $3}' | grep "^$MOUNT_BASE" || true)

if [[ -z "$active_mounts" ]]; then
    log "No active rclone mounts found in $MOUNT_BASE"
    exit 0
fi

unmounted_count=0
failed_count=0

echo "Found active mounts:"
while IFS= read -r mount_point; do
    remote_name=$(basename "$mount_point")
    echo "  - $remote_name at $mount_point"
    
    log "Unmounting $remote_name from $mount_point"
    
    # Try graceful unmount first
    if fusermount -u "$mount_point" 2>/dev/null || umount "$mount_point" 2>/dev/null; then
        log "SUCCESS: Unmounted $remote_name"
        unmounted_count=$((unmounted_count + 1))
    else
        log "WARNING: Graceful unmount failed for $remote_name, trying force unmount"
        
        # Try force unmount
        if fusermount -uz "$mount_point" 2>/dev/null || umount -f "$mount_point" 2>/dev/null; then
            log "SUCCESS: Force unmounted $remote_name"
            unmounted_count=$((unmounted_count + 1))
        else
            log "ERROR: Failed to unmount $remote_name"
            failed_count=$((failed_count + 1))
        fi
    fi
    
    # Clean up empty mount directory if unmount was successful
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        if [[ -d "$mount_point" ]] && [[ -z "$(ls -A "$mount_point" 2>/dev/null)" ]]; then
            rmdir "$mount_point" 2>/dev/null || true
            log "Cleaned up empty mount directory: $mount_point"
        fi
    fi
    
done <<< "$active_mounts"

log "Unmount complete: $unmounted_count unmounted, $failed_count failed"

if [[ $failed_count -gt 0 ]]; then
    echo "Some mounts could not be unmounted. Check the log for details."
    exit 1
else
    echo "All mounts successfully unmounted."
fi