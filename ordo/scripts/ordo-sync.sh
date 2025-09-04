#!/bin/bash

# Ordo Unified Sync - Local-first bidirectional sync with cloud storage
# Usage: ./ordo-sync.sh [command] [options]
# 
# Commands:
#   init <local-path> <remote-path>  - Setup new sync target
#   sync [target]                    - One-time sync (all if no target)
#   daemon [interval]                - Background sync daemon
#   status                          - Show sync status
#   conflicts                       - Show/resolve conflicts

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ORDO_DIR/config/sync-targets.conf"
LOG_FILE="$ORDO_DIR/logs/ordo-sync.log"
CONFLICT_DIR="$ORDO_DIR/conflicts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$ORDO_DIR/logs" "$ORDO_DIR/config" "$CONFLICT_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Print functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Determine bisync lock file path for a given local/remote pair (matches rclone's sanitization)
get_bisync_lock_file() {
    local local_path="$1"
    local remote_path="$2"
    local lock_dir="$HOME/.cache/rclone/bisync"
    local local_sanitized
    local remote_sanitized
    local_sanitized=$(echo "$local_path" | sed -E 's#^/##; s#/#_#g')
    remote_sanitized=$(echo "$remote_path" | sed -E 's#[:/]+#_#g; s#_+$##')
    echo "$lock_dir/${local_sanitized}..${remote_sanitized}.lck"
}

# Return 0 if a bisync appears to be running for the target, else 1
is_bisync_running() {
    local local_path="$1"
    local remote_path="$2"
    local lock_file
    lock_file=$(get_bisync_lock_file "$local_path" "$remote_path")

    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(grep -oE '"PID"\s*:\s*"[0-9]+' "$lock_file" 2>/dev/null | grep -oE '[0-9]+' || true)
        if [[ -n "${lock_pid:-}" ]] && ps -p "$lock_pid" >/dev/null 2>&1; then
            print_info "Bisync in progress (PID=$lock_pid) for $(basename "$local_path")."
            return 0
        fi
    fi
    return 1
}

# Check if rclone is available and working
check_rclone() {
    if ! command -v rclone &> /dev/null; then
        print_error "rclone is not installed or not in PATH"
        exit 1
    fi
}

# Parse remote from remote path (e.g., "onedrive-f6388:Documents/file.txt" -> "onedrive-f6388")
get_remote_name() {
    local remote_path="$1"
    echo "$remote_path" | cut -d':' -f1
}

# Check if remote is accessible
check_remote_connection() {
    local remote_name="$1"
    log "Checking connection to $remote_name..."
    if timeout 10 rclone lsd "$remote_name:" --max-depth 1 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get file checksum for change detection
get_checksum() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        sha256sum "$file_path" | cut -d' ' -f1
    else
        echo ""
    fi
}

# Initialize a new sync target
init_target() {
    local local_path="$1"
    local remote_path="$2"
    local sync_frequency="${3:-300}"  # Default 5 minutes
    
    # Validate inputs
    if [[ -z "$local_path" || -z "$remote_path" ]]; then
        print_error "Usage: ordo-sync.sh init <local-path> <remote-path> [sync-frequency-seconds]"
        exit 1
    fi
    
    # Expand local path
    local_path="${local_path/#\~/$HOME}"
    
    # Get remote name for connection check
    local remote_name
    remote_name=$(get_remote_name "$remote_path")
    
    log "Initializing sync target:"
    log "  Local: $local_path"
    log "  Remote: $remote_path"
    log "  Frequency: ${sync_frequency}s"
    
    # Create local directory
    mkdir -p "$local_path"
    print_success "Created local directory: $local_path"
    
    # Check if we can connect to remote
    if check_remote_connection "$remote_name"; then
        print_success "Connected to remote: $remote_name"
        
        # Check if remote path exists and has content
        if rclone lsd "$remote_path" >/dev/null 2>&1; then
            print_info "Remote path exists, performing initial sync..."
            
            # Initial sync from remote to local
            if rclone sync "$remote_path" "$local_path" \
                --progress \
                --log-file "$LOG_FILE" \
                --log-level INFO; then
                print_success "Initial sync completed"
            else
                print_warning "Initial sync had issues (check logs)"
            fi
        else
            print_info "Remote path doesn't exist - will be created on first sync"
        fi
    else
        print_warning "Cannot connect to remote - initialized locally only"
    fi
    
    # Add to config file
    echo "$local_path|$remote_path|$sync_frequency" >> "$CONFIG_FILE"
    print_success "Sync target configured"
    
    echo ""
    print_info "Sync target initialized successfully!"
    echo "Local path: $local_path"
    echo "Applications should point to: $local_path"
    echo ""
    echo "To sync now: ./ordo-sync.sh sync"
    echo "To start daemon: ./ordo-sync.sh daemon"
}

# Perform bidirectional sync for a single target
sync_target() {
    local local_path="$1"
    local remote_path="$2"
    local target_name="$3"
    
    local remote_name
    remote_name=$(get_remote_name "$remote_path")
    
    log "Syncing target: $target_name"
    log "  Local: $local_path"
    log "  Remote: $remote_path"
    
    # Check remote connection
    if ! check_remote_connection "$remote_name"; then
        log "⚠ No connection to $remote_name - sync skipped"
        return 1
    fi
    
    # Create backup directory for conflicts
    local backup_dir="$CONFLICT_DIR/$(basename "$local_path")-$(date +%Y%m%d-%H%M%S)"
    
    # Use rclone bisync if available (preferred method)
    if rclone help bisync >/dev/null 2>&1; then
        log "Using rclone bisync for bidirectional sync..."
        
        # Check if this is first bisync (needs --resync)
        local bisync_state_file="$local_path/.rclone-bisync-state"
        local bisync_flags=""
        
        if [[ ! -f "$bisync_state_file" ]]; then
            log "First bisync - using --resync"
            bisync_flags="--resync"
        fi

        # Proactively handle a stale bisync lock file to avoid immediate failures on restart
        # rclone lock path format example:
        #   ~/.cache/rclone/bisync/home_user_Documents..onedrive-xyz_Documents.lck
        # We replicate rclone's sanitization to locate the lock file and clear it if the PID is not running.
        local lock_dir="$HOME/.cache/rclone/bisync"
        local local_sanitized
        local remote_sanitized
        local_sanitized=$(echo "$local_path" | sed -E 's#^/##; s#/#_#g')
        remote_sanitized=$(echo "$remote_path" | sed -E 's#[:/]+#_#g; s#_+$##')
        local lock_file="$lock_dir/${local_sanitized}..${remote_sanitized}.lck"

        if [[ -f "$lock_file" ]]; then
            # Try to read the PID from the JSON-ish lock file; if missing, assume stale
            local lock_pid
            lock_pid=$(grep -oE '"PID"\s*:\s*"[0-9]+' "$lock_file" 2>/dev/null | grep -oE '[0-9]+' || true)
            if [[ -n "${lock_pid:-}" ]] && ps -p "$lock_pid" >/dev/null 2>&1; then
                log "Another bisync appears to be running (PID=$lock_pid). Skipping $target_name for now."
                return 1
            else
                log "Stale bisync lock detected at $lock_file (PID=${lock_pid:-unknown}). Clearing it..."
                # Prefer rclone deletefile as suggested by rclone, fallback to rm
                if ! rclone deletefile "$lock_file" >/dev/null 2>&1; then
                    rm -f "$lock_file" || true
                fi
            fi
        fi
        
        # Build exclusion flags from config file
        local exclude_flags=""
        local exclude_file="$ORDO_DIR/config/sync-excludes.conf"
        
        if [[ -f "$exclude_file" ]]; then
            log "Using exclusions from: $exclude_file"
            exclude_flags="--filter-from $exclude_file"
        fi
        
        # Build resiliency flags
        local resiliency_flags=(
            --retries 5
            --retries-sleep 10s
            --low-level-retries 10
            --checkers 8
            --transfers 4
            --stats 30s
            --stats-one-line
        )

        # Optional wrapper timeout via env var ORDO_BISYNC_TIMEOUT_SEC (0 or unset = no timeout)
    local -a timeout_cmd=()
        local bisync_timeout="${ORDO_BISYNC_TIMEOUT_SEC:-0}"
        if [[ "$bisync_timeout" =~ ^[0-9]+$ ]] && [[ "$bisync_timeout" -gt 0 ]]; then
            timeout_cmd=(timeout "${bisync_timeout}s")
            log "Applying external timeout: ${bisync_timeout}s (set ORDO_BISYNC_TIMEOUT_SEC=0 to disable)"
        fi

        # Perform bisync with up to 3 attempts (no hard-coded timeout)
        local attempt
        local max_attempts=3
        for attempt in $(seq 1 $max_attempts); do
            if [[ $attempt -gt 1 ]]; then
                local sleep_s=$((attempt * 15))
                log "Retrying bisync (attempt $attempt/$max_attempts) after ${sleep_s}s..."
                sleep "$sleep_s"
            fi

            if "${timeout_cmd[@]}" rclone bisync "$local_path" "$remote_path" \
                $bisync_flags \
                $exclude_flags \
                "${resiliency_flags[@]}" \
                --progress \
                --log-file "$LOG_FILE" \
                --log-level INFO \
                --conflict-resolve newer \
                --conflict-suffix "conflict-{DateOnly}-{TimeOnly}"; then
                
                # Mark that initial resync completed successfully so we don't use --resync again
                if [[ ! -f "$bisync_state_file" ]]; then
                    touch "$bisync_state_file" || true
                fi
                
                log "✓ Bidirectional sync completed for $target_name"
                return 0
            fi
        done

        log "✗ Bisync failed for $target_name"
        return 1
    else
        log "rclone bisync not available, using manual sync approach..."
        
        # Manual bidirectional sync with conflict detection
        mkdir -p "$backup_dir"
        
        # Sync remote → local (with backup of local changes)
        log "Syncing remote → local..."
        if rclone sync "$remote_path" "$local_path" \
            --backup-dir "$backup_dir/local-backup" \
            --progress \
            --log-file "$LOG_FILE" \
            --log-level INFO \
            --exclude ".DS_Store" \
            --exclude "Thumbs.db"; then
            
            log "Remote → local sync completed"
        else
            log "✗ Remote → local sync failed"
            return 1
        fi
        
        # Sync local → remote
        log "Syncing local → remote..."
        if rclone sync "$local_path" "$remote_path" \
            --progress \
            --log-file "$LOG_FILE" \
            --log-level INFO \
            --exclude ".DS_Store" \
            --exclude "Thumbs.db"; then
            
            log "Local → remote sync completed"
        else
            log "✗ Local → remote sync failed"
            return 1
        fi
        
        # Clean up empty backup directory
        if [[ -d "$backup_dir" ]] && [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
            rmdir "$backup_dir" 2>/dev/null || true
        fi
        
        log "✓ Manual bidirectional sync completed for $target_name"
        return 0
    fi
}

# Sync all configured targets
sync_all() {
    echo "Ordo Sync"
    echo "========="
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "No sync targets configured"
        echo "Use: ./ordo-sync.sh init <local-path> <remote-path>"
        return 0
    fi
    
    local success_count=0
    local total_count=0
    
    while IFS='|' read -r local_path remote_path sync_frequency; do
        # Skip empty lines and comments
        [[ -z "$local_path" || "$local_path" =~ ^[[:space:]]*# ]] && continue
        
        total_count=$((total_count + 1))
        local target_name=$(basename "$local_path")
        print_info "Syncing $target_name..."
        if sync_target "$local_path" "$remote_path" "$target_name"; then
            success_count=$((success_count + 1))
            print_success "Synced: $target_name"
        else
            print_warning "Failed: $target_name (likely no connection)"
        fi
    done < "$CONFIG_FILE"
    
    log "Sync summary: $success_count/$total_count targets synced successfully"
    
    if [[ $success_count -eq $total_count ]]; then
        print_success "All sync targets completed successfully"
    elif [[ $success_count -gt 0 ]]; then
        print_warning "Some sync targets failed (likely connection issues)"
    else
        print_error "All sync targets failed"
    fi
}

# Show status of all sync targets
show_status() {
    echo "Ordo Sync Status"
    echo "================"
    echo ""
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "No sync targets configured"
        echo ""
        echo "To add a sync target:"
        echo "  ./ordo-sync.sh init <local-path> <remote-path>"
        echo ""
        echo "Examples:"
        echo "  ./ordo-sync.sh init ~/ObsidianVaults/MyVault onedrive-f6388:Documents/ObsidianVaults/MyVault"
        echo "  ./ordo-sync.sh init ~/Documents/ImportantProject g-drive-f6388:Projects/ImportantProject"
        return 0
    fi
    
    local target_count=0
    
    while IFS='|' read -r local_path remote_path sync_frequency || [[ -n "$local_path" ]]; do
        # Skip empty lines and comments
        if [[ -z "$local_path" || "$local_path" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        target_count=$((target_count + 1))
        local target_name
        target_name=$(basename "$local_path")
        
        local remote_name
        remote_name=$(echo "$remote_path" | cut -d':' -f1)
        
        echo "Target: $target_name"
        echo "  Local:     $local_path"
        echo "  Remote:    $remote_path"
        echo "  Frequency: ${sync_frequency}s"
        
        # Check local status
        if [[ -d "$local_path" ]]; then
            local file_count
            file_count=$(find "$local_path" -type f 2>/dev/null | wc -l)
            print_success "Local: $file_count files"
        else
            print_error "Local: Directory missing"
        fi
        
        # Check remote status (simplified, non-blocking)
        print_info "Remote: $remote_name (connection check skipped for speed)"
        
        echo ""
    done < "$CONFIG_FILE"
    
    if [[ $target_count -eq 0 ]]; then
        print_warning "No valid sync targets found in config"
    else
        print_info "Total sync targets: $target_count"
    fi
    
    # Show recent activity
    if [[ -f "$LOG_FILE" ]]; then
        echo "Recent Activity:"
        echo "================"
        tail -n 5 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
            echo "  $line"
        done || echo "  No recent activity"
    fi
}

# Show and help resolve conflicts
show_conflicts() {
    echo "Conflict Resolution"
    echo "=================="
    echo ""
    
    if [[ ! -d "$CONFLICT_DIR" ]] || [[ -z "$(ls -A "$CONFLICT_DIR" 2>/dev/null)" ]]; then
        print_success "No conflicts found"
        return 0
    fi
    
    print_warning "Conflicts detected in: $CONFLICT_DIR"
    echo ""
    
    # List conflict directories
    for conflict_backup in "$CONFLICT_DIR"/*; do
        if [[ -d "$conflict_backup" ]]; then
            echo "Conflict backup: $(basename "$conflict_backup")"
            
            # Show files in conflict
            find "$conflict_backup" -type f | head -10 | while read -r file; do
                echo "  - ${file#$conflict_backup/}"
            done
            
            local file_count=$(find "$conflict_backup" -type f | wc -l)
            if [[ $file_count -gt 10 ]]; then
                echo "  ... and $((file_count - 10)) more files"
            fi
            echo ""
        fi
    done
    
    echo "To resolve conflicts:"
    echo "1. Review files in conflict backup directories"
    echo "2. Manually merge or choose preferred versions"
    echo "3. Copy resolved files back to sync targets"
    echo "4. Remove conflict backup directories when done"
    echo ""
    echo "Conflict backups are in: $CONFLICT_DIR"
}

# Start sync daemon
start_daemon() {
    local interval="${1:-300}"  # Default 5 minutes
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "No sync targets configured"
        echo "Use: ./ordo-sync.sh init <local-path> <remote-path>"
        exit 1
    fi
    
    log "Starting Ordo sync daemon (interval: ${interval}s)"
    print_info "Ordo sync daemon started (interval: ${interval}s)"
    print_info "Press Ctrl+C to stop"
    
    # Trap to handle graceful shutdown
    trap 'log "Sync daemon stopped"; print_info "Sync daemon stopped"; exit 0' INT TERM
    
    while true; do
        log "Daemon sync cycle starting..."
        sync_all >/dev/null 2>&1
        log "Daemon sync cycle completed, sleeping ${interval}s..."
        sleep "$interval"
    done
}

# Verify sync status for all targets without making changes
verify_targets() {
    echo "Ordo Sync Verify"
    echo "================="

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "No sync targets configured"
        return 0
    fi

    local all_ok=1
    while IFS='|' read -r local_path remote_path sync_frequency || [[ -n "$local_path" ]]; do
        # Skip empty/comment lines
        if [[ -z "$local_path" || "$local_path" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        local name
        name=$(basename "$local_path")
        echo "Target: $name"
        echo "  Local:  $local_path"
        echo "  Remote: $remote_path"

        # If a bisync is in progress, skip verification for safety
        if is_bisync_running "$local_path" "$remote_path"; then
            print_info "Skipping verify: bisync in progress"
            echo ""
            continue
        fi

        # Build filter-from if present
        local exclude_file="$ORDO_DIR/config/sync-excludes.conf"
        local filter_args=()
        if [[ -f "$exclude_file" ]]; then
            filter_args+=(--filter-from "$exclude_file")
        fi

        # Prefer a bisync dry-run to detect planned changes
        if rclone help bisync >/dev/null 2>&1; then
            if rclone bisync "$local_path" "$remote_path" --dry-run "${filter_args[@]}" --log-level NOTICE >/dev/null 2>&1; then
                print_success "In sync (no planned changes)"
            else
                print_warning "Drift detected or state missing (see rclone output for details)"
                all_ok=0
            fi
        else
            # Fallback: size-only check
            if rclone check "$local_path" "$remote_path" --size-only --log-level NOTICE >/dev/null 2>&1; then
                print_success "In sync (size-only)"
            else
                print_warning "Differences detected (size-only check)"
                all_ok=0
            fi
        fi
        echo ""
    done < "$CONFIG_FILE"

    if [[ $all_ok -eq 1 ]]; then
        print_success "All verified targets are in sync"
    else
        print_warning "One or more targets show drift or need --resync"
    fi
}

# Main script logic
check_rclone

case "${1:-}" in
    "init")
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 init <local-path> <remote-path> [sync-frequency-seconds]"
            echo ""
            echo "Examples:"
            echo "  $0 init ~/ObsidianVaults/MyVault onedrive-f6388:Documents/ObsidianVaults/MyVault"
            echo "  $0 init ~/Documents/Project g-drive-f6388:Projects/MyProject 180"
            exit 1
        fi
        init_target "$2" "$3" "${4:-300}"
        ;;
    "sync")
        if [[ $# -eq 1 ]]; then
            # Sync all targets
            sync_all
        else
            print_error "Syncing specific targets not yet implemented"
            echo "Use: $0 sync  (syncs all targets)"
            exit 1
        fi
        ;;
    "daemon")
        start_daemon "${2:-300}"
        ;;
    "status")
        show_status
        ;;
    "conflicts")
        show_conflicts
        ;;
    "verify")
        verify_targets
        ;;
    *)
        echo "Ordo Unified Sync - Local-first bidirectional sync"
        echo "================================================="
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init <local-path> <remote-path> [frequency]  - Setup new sync target"
        echo "  sync                                         - One-time sync all targets"
    echo "  daemon [interval-seconds]                    - Background sync daemon"
    echo "  status                                       - Show sync status"
    echo "  verify                                       - Dry-run check if targets are in sync"
        echo "  conflicts                                    - Show/resolve conflicts"
        echo ""
        echo "Examples:"
        echo "  $0 init ~/ObsidianVaults/MyVault onedrive-f6388:Documents/ObsidianVaults/MyVault"
        echo "  $0 init ~/Documents/Project g-drive-f6388:Projects/MyProject 180"
        echo "  $0 sync"
        echo "  $0 daemon 300  # Sync every 5 minutes"
        echo "  $0 status"
        echo ""
        echo "Philosophy:"
        echo "  - Applications point to LOCAL files only (~/Documents/, ~/ObsidianVaults/)"
        echo "  - Background sync keeps local files current with remote"
        echo "  - Zero application crashes due to network issues"
        echo "  - Browse remote files via mount points (/media/\$USER/)"
        ;;
esac