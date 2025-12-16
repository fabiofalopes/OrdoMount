#!/bin/bash

# Ordo Automount - Mount all configured rclone remotes with VFS caching
# Usage: ./automount.sh
#
# Config format (remotes.conf):
#   remote_name|mount_suffix|rclone_flags
#   or just: remote_name (for simple mounts)

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ORDO_DIR/config/remotes.conf"
LOG_FILE="$ORDO_DIR/logs/automount.log"
MOUNT_BASE="/media/$USER"
# Ensure directories exist
sudo mkdir -p "$MOUNT_BASE" 2>/dev/null || mkdir -p "$HOME/mounts"  # Fallback if no sudo
mkdir -p "$ORDO_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    log "ERROR: rclone is not installed or not in PATH"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "ERROR: Configuration file not found: $CONFIG_FILE"
    log "Run './scripts/init.sh' to initialize Ordo and create the configuration file"
    exit 1
fi

log "Starting Ordo automount process"

# Get list of available rclone remotes
available_remotes=$(rclone listremotes | sed 's/:$//')
log "Available rclone remotes: $available_remotes"

# Mount each configured remote
mounted_count=0
failed_count=0

while IFS='|' read -r remote mount_suffix rclone_flags || [[ -n "$remote" ]]; do
    # Skip empty lines and comments
    [[ -z "$remote" || "$remote" =~ ^[[:space:]]*# ]] && continue
    
    # Remove leading/trailing whitespace
    remote=$(echo "$remote" | xargs)
    mount_suffix=$(echo "${mount_suffix:-}" | xargs)
    rclone_flags=$(echo "${rclone_flags:-}" | xargs)
    
    [[ -z "$remote" ]] && continue
    
    log "Processing remote: $remote"
    if [[ -n "$mount_suffix" ]]; then
        log "  Mount suffix: $mount_suffix"
    fi
    if [[ -n "$rclone_flags" ]]; then
        log "  Flags: $rclone_flags"
    fi
    
    # Check if remote exists in rclone config
    if ! echo "$available_remotes" | grep -q "^$remote$"; then
        log "ERROR: Remote '$remote' not found in rclone configuration"
        ((failed_count++))
        continue
    fi
    
    # Test remote connectivity (with flags if provided)
    log "Testing connectivity to $remote..."
    if ! rclone lsd "$remote:" $rclone_flags &>/dev/null; then
        log "ERROR: Cannot connect to remote '$remote' (check authentication)"
        ((failed_count++))
        continue
    fi
    
    # Determine mount point name
    if [[ -n "$mount_suffix" ]]; then
        mount_name="${remote}-${mount_suffix}"
    else
        mount_name="$remote"
    fi
    
    mount_point="$MOUNT_BASE/$mount_name"
    mkdir -p "$mount_point"
    
    # Check if already mounted
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log "INFO: $remote is already mounted at $mount_point"
        mounted_count=$((mounted_count + 1))
        continue
    fi
    
    # Mount the remote
    log "Mounting $remote to $mount_point..."
    if "$ORDO_DIR/scripts/mount-remote.sh" "$remote" "$mount_suffix" "$rclone_flags"; then
        log "SUCCESS: Mounted $remote at $mount_point"
        mounted_count=$((mounted_count + 1))
    else
        log "ERROR: Failed to mount $remote"
        failed_count=$((failed_count + 1))
    fi
done < "$CONFIG_FILE"

log "Automount complete: $mounted_count mounted, $failed_count failed"

if [[ $failed_count -gt 0 ]]; then
    exit 1
fi