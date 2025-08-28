#!/bin/bash

# Check connectivity and cache status for mounted remotes
# Usage: ./check-connectivity.sh [remote-name]

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
MOUNT_BASE="$HOME/mounts"
CONFIG_FILE="$ORDO_DIR/config/remotes.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_remote_connectivity() {
    local remote="$1"
    local mount_point="$MOUNT_BASE/$remote"
    
    echo -e "\n${BLUE}Checking: $remote${NC}"
    
    # Check if mounted
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        print_error "Not mounted at $mount_point"
        return 1
    fi
    
    print_success "Mount point exists: $mount_point"
    
    # Test basic connectivity to remote
    echo -n "Testing remote connectivity... "
    if timeout 10 rclone lsd "$remote:" --max-depth 1 &>/dev/null; then
        print_success "Remote is accessible"
        remote_online=true
    else
        print_warning "Remote is not accessible (offline or auth issue)"
        remote_online=false
    fi
    
    # Test local mount accessibility
    echo -n "Testing mount accessibility... "
    if timeout 5 ls "$mount_point" &>/dev/null; then
        print_success "Mount is accessible"
        mount_accessible=true
    else
        print_error "Mount is not accessible"
        mount_accessible=false
    fi
    
    # Check cache status
    cache_info=$(rclone backend stats "$remote:" 2>/dev/null || echo "unavailable")
    if [[ "$cache_info" != "unavailable" ]]; then
        echo "Cache info: $cache_info"
    fi
    
    # Provide recommendations
    if [[ "$remote_online" == false && "$mount_accessible" == false ]]; then
        print_warning "Recommendation: Remount when connectivity returns"
        echo "  Command: ./ordo/scripts/mount-remote.sh $remote"
    elif [[ "$remote_online" == false && "$mount_accessible" == true ]]; then
        print_success "Working offline from cache"
    elif [[ "$remote_online" == true && "$mount_accessible" == false ]]; then
        print_warning "Recommendation: Remount to fix access issues"
        echo "  Commands:"
        echo "    fusermount -u $mount_point"
        echo "    ./ordo/scripts/mount-remote.sh $remote"
    fi
}

# Main execution
if [[ $# -eq 1 ]]; then
    # Check specific remote
    check_remote_connectivity "$1"
else
    # Check all configured remotes
    print_header "Connectivity Check for All Remotes"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    configured_remotes=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        remote=$(echo "$line" | xargs)
        [[ -n "$remote" ]] && configured_remotes+=("$remote")
    done < "$CONFIG_FILE"
    
    if [[ ${#configured_remotes[@]} -eq 0 ]]; then
        print_warning "No remotes configured"
        exit 0
    fi
    
    for remote in "${configured_remotes[@]}"; do
        check_remote_connectivity "$remote"
    done
fi

echo -e "\n${BLUE}Connectivity check complete${NC}"