#!/bin/bash

# Ordo Automount - Mount all configured rclone remotes with VFS caching
# Usage: ./automount.sh

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ORDO_DIR/config/remotes.conf"
LOG_FILE="$ORDO_DIR/logs/automount.log"
MOUNT_BASE="$HOME/mounts"
CACHE_DIR="$ORDO_DIR/cache"

# Ensure directories exist
mkdir -p "$MOUNT_BASE" "$ORDO_DIR/logs" "$CACHE_DIR"

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

# Read configured remotes from config file
configured_remotes=()
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Remove leading/trailing whitespace
    remote=$(echo "$line" | xargs)
    [[ -n "$remote" ]] && configured_remotes+=("$remote")
done < "$CONFIG_FILE"

if [[ ${#configured_remotes[@]} -eq 0 ]]; then
    log "WARNING: No remotes configured in $CONFIG_FILE"
    exit 0
fi

log "Configured remotes: ${configured_remotes[*]}"

# Mount each configured remote
mounted_count=0
failed_count=0

for remote in "${configured_remotes[@]}"; do
    log "Processing remote: $remote"
    
    # Check if remote exists in rclone config
    if ! echo "$available_remotes" | grep -q "^$remote$"; then
        log "ERROR: Remote '$remote' not found in rclone configuration"
        ((failed_count++))
        continue
    fi
    
    # Test remote connectivity
    log "Testing connectivity to $remote..."
    if ! rclone lsd "$remote:" &>/dev/null; then
        log "ERROR: Cannot connect to remote '$remote' (check authentication)"
        ((failed_count++))
        continue
    fi
    
    # Create mount directory
    mount_point="$MOUNT_BASE/$remote"
    mkdir -p "$mount_point"
    
    # Check if already mounted
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log "INFO: $remote is already mounted at $mount_point"
        ((mounted_count++))
        continue
    fi
    
    # Mount the remote
    log "Mounting $remote to $mount_point..."
    if "$ORDO_DIR/scripts/mount-remote.sh" "$remote"; then
        log "SUCCESS: Mounted $remote"
        ((mounted_count++))
    else
        log "ERROR: Failed to mount $remote"
        ((failed_count++))
    fi
done

log "Automount complete: $mounted_count mounted, $failed_count failed"

if [[ $failed_count -gt 0 ]]; then
    exit 1
fi