#!/bin/bash

# Ordo Production Setup - One-time setup for the streamlined system
# Usage: ./setup.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Ordo Production Setup"
echo "This script will set up Ordo for production use."
echo "You'll only need to run this once (or when adding new sync targets)."
echo ""

# Step 1: Initialize Ordo
print_header "Step 1: Initialize Ordo"
if ./scripts/init.sh; then
    print_success "Ordo initialized successfully"
else
    print_error "Failed to initialize Ordo"
    exit 1
fi

# Step 2: Configure remotes for browsing (optional)
print_header "Step 2: Configure Remote Browsing (Optional)"
echo "Remote browsing allows you to explore all your cloud files when connected."
echo "This is optional - you can skip if you only want local sync targets."
echo ""

read -p "Do you want to set up remote browsing? (y/N): " setup_browsing
if [[ "$setup_browsing" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Edit config/remotes.conf to list your rclone remotes:"
    echo "Example:"
    echo "  onedrive-personal"
    echo "  gdrive-work"
    echo ""
    read -p "Press Enter when you've configured remotes.conf (or Ctrl+C to skip)..."
    
    if ./scripts/automount.sh; then
        print_success "Remote browsing set up successfully"
        echo "Browse your files at: /media/$USER/[remote-name]/"
    else
        print_warning "Remote mounting had issues (check your rclone config)"
    fi
else
    print_info "Skipping remote browsing setup"
fi

# Step 3: Set up sync targets
print_header "Step 3: Set Up Local Sync Targets"
echo "Local sync targets are where your applications should point."
echo "Files sync automatically in the background when connected."
echo ""

setup_sync_targets() {
    while true; do
        echo ""
        echo "Common sync target examples:"
        echo "1. Obsidian vault: ~/ObsidianVaults/MyVault ↔ onedrive:Documents/ObsidianVaults/MyVault"
        echo "2. Project folder: ~/Documents/MyProject ↔ gdrive:Projects/MyProject"
        echo "3. Important file: ~/Documents/important.txt ↔ onedrive:Documents/important.txt"
        echo ""
        
        read -p "Do you want to set up a sync target? (y/N): " setup_target
        if [[ ! "$setup_target" =~ ^[Yy]$ ]]; then
            break
        fi
        
        echo ""
        read -p "Local path (e.g., ~/ObsidianVaults/MyVault): " local_path
        read -p "Remote path (e.g., onedrive:Documents/ObsidianVaults/MyVault): " remote_path
        read -p "Sync frequency in seconds (default 300 = 5 minutes): " frequency
        frequency=${frequency:-300}
        
        # Expand tilde
        local_path="${local_path/#\~/$HOME}"
        
        echo ""
        echo "Setting up sync target:"
        echo "  Local:  $local_path"
        echo "  Remote: $remote_path"
        echo "  Frequency: ${frequency}s"
        echo ""
        
        if ./scripts/ordo-sync.sh init "$local_path" "$remote_path" "$frequency"; then
            print_success "Sync target configured successfully"
            echo ""
            print_info "IMPORTANT: Point your application to: $local_path"
            print_info "This local path will sync automatically with the remote"
        else
            print_warning "Failed to set up sync target (check your rclone config)"
        fi
    done
}

setup_sync_targets

# Step 4: Set up background sync daemon
print_header "Step 4: Background Sync Daemon"
echo "The sync daemon runs in the background and keeps your files synchronized."
echo ""

read -p "Do you want to start the background sync daemon now? (y/N): " start_daemon
if [[ "$start_daemon" =~ ^[Yy]$ ]]; then
    echo ""
    print_info "Starting background sync daemon..."
    print_info "This will sync all configured targets every few minutes"
    print_info "Press Ctrl+C to stop the daemon when needed"
    echo ""
    
    # Start daemon in background
    nohup ./scripts/ordo-sync.sh daemon > /dev/null 2>&1 &
    daemon_pid=$!
    
    print_success "Background sync daemon started (PID: $daemon_pid)"
    echo "To stop: kill $daemon_pid"
    echo "To restart: ./scripts/ordo-sync.sh daemon &"
else
    print_info "You can start the daemon later with: ./scripts/ordo-sync.sh daemon &"
fi

# Step 5: Final status and instructions
print_header "Setup Complete!"
echo ""
print_success "Ordo is now configured and ready for production use"
echo ""

echo "What you have now:"
echo "=================="

# Show configured sync targets
if [[ -f "config/sync-targets.conf" ]]; then
    sync_count=0
    while IFS='|' read -r local_path remote_path sync_frequency || [[ -n "$local_path" ]]; do
        if [[ -z "$local_path" || "$local_path" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        sync_count=$((sync_count + 1))
        target_name=$(basename "$local_path")
        echo "  ✓ Sync Target: $target_name"
        echo "    Local:  $local_path"
        echo "    Remote: $remote_path"
        echo "    Apps should point to: $local_path"
        echo ""
    done < "config/sync-targets.conf"
    
    if [[ $sync_count -eq 0 ]]; then
        print_warning "No sync targets configured"
    fi
fi

# Show remote browsing status
if [[ -f "config/remotes.conf" ]]; then
    remote_count=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        remote=$(echo "$line" | xargs)
        if [[ -n "$remote" ]]; then
            remote_count=$((remote_count + 1))
            echo "  ✓ Browse Remote: /media/$USER/$remote/"
        fi
    done < "config/remotes.conf"
    
    if [[ $remote_count -eq 0 ]]; then
        print_info "No remote browsing configured (that's fine)"
    fi
fi

echo ""
echo "Key Commands:"
echo "============="
echo "  ./scripts/status.sh                 - Check overall status"
echo "  ./scripts/ordo-sync.sh status       - Check sync targets"
echo "  ./scripts/ordo-sync.sh sync         - Manual sync now"
echo "  ./scripts/ordo-sync.sh daemon &     - Start background sync"
echo "  ./scripts/automount.sh              - Mount remotes for browsing"
echo ""

echo "Maintenance:"
echo "============"
echo "  - Background sync runs automatically"
echo "  - Check status occasionally: ./scripts/status.sh"
echo "  - Add new sync targets: ./scripts/ordo-sync.sh init <local> <remote>"
echo "  - View conflicts: ./scripts/ordo-sync.sh conflicts"
echo ""

print_success "Setup complete! Your applications should point to LOCAL paths only."
print_info "Files will sync automatically in the background when connected."