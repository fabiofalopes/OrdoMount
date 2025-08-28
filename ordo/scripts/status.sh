#!/bin/bash

# Check status of Ordo mounts and system health
# Usage: ./status.sh

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
MOUNT_BASE="$HOME/mounts"
CACHE_DIR="$ORDO_DIR/cache"
CONFIG_FILE="$ORDO_DIR/config/remotes.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if rclone is available
print_header "System Check"
if command -v rclone &> /dev/null; then
    rclone_version=$(rclone version | head -n1)
    print_success "rclone available: $rclone_version"
else
    print_error "rclone not found in PATH"
    exit 1
fi

# Check Ordo directory structure
if [[ -d "$ORDO_DIR" ]]; then
    print_success "Ordo directory exists: $ORDO_DIR"
else
    print_error "Ordo directory not found: $ORDO_DIR"
    exit 1
fi

# Check configuration
print_header "Configuration"
if [[ -f "$CONFIG_FILE" ]]; then
    configured_remotes=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        remote=$(echo "$line" | xargs)
        [[ -n "$remote" ]] && configured_remotes+=("$remote")
    done < "$CONFIG_FILE"
    
    if [[ ${#configured_remotes[@]} -gt 0 ]]; then
        print_success "Configuration file found with ${#configured_remotes[@]} remotes"
        for remote in "${configured_remotes[@]}"; do
            echo "  - $remote"
        done
    else
        print_warning "Configuration file exists but no remotes configured"
    fi
else
    print_error "Configuration file not found: $CONFIG_FILE"
    echo "Run './scripts/init.sh' to initialize Ordo and create the configuration file"
fi

# Check mount status
print_header "Mount Status"
if [[ -d "$MOUNT_BASE" ]]; then
    print_success "Mount base directory exists: $MOUNT_BASE"
    
    # Get active rclone mounts
    active_mounts=$(mount | grep rclone | awk '{print $3}' | grep "^$MOUNT_BASE" || true)
    
    if [[ -n "$active_mounts" ]]; then
        echo -e "\n${GREEN}Active mounts:${NC}"
        while IFS= read -r mount_point; do
            remote_name=$(basename "$mount_point")
            echo "  ✓ $remote_name → $mount_point"
            
            # Test accessibility
            if timeout 5 ls "$mount_point" &>/dev/null; then
                echo "    Status: Accessible"
            else
                echo -e "    Status: ${YELLOW}Not accessible (may be slow or auth issue)${NC}"
            fi
        done <<< "$active_mounts"
    else
        print_warning "No active rclone mounts found"
    fi
    
    # Check for configured but unmounted remotes
    if [[ ${#configured_remotes[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Configured remotes status:${NC}"
        for remote in "${configured_remotes[@]}"; do
            mount_point="$MOUNT_BASE/$remote"
            if mountpoint -q "$mount_point" 2>/dev/null; then
                print_success "$remote (mounted)"
            else
                print_warning "$remote (not mounted)"
            fi
        done
    fi
else
    print_error "Mount base directory not found: $MOUNT_BASE"
fi

# Check cache status
print_header "Cache Status"
if [[ -d "$CACHE_DIR" ]]; then
    cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "0B")
    cache_files=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l || echo "0")
    print_success "Cache directory: $CACHE_DIR"
    echo "  Size: $cache_size"
    echo "  Files: $cache_files"
else
    print_warning "Cache directory not found: $CACHE_DIR"
fi

# Check recent logs
print_header "Recent Activity"
log_file="$ORDO_DIR/logs/automount.log"
if [[ -f "$log_file" ]]; then
    echo "Last 5 log entries:"
    tail -n 5 "$log_file" | while IFS= read -r line; do
        echo "  $line"
    done
else
    print_warning "No automount log found"
fi

echo -e "\n${BLUE}Status check complete${NC}"