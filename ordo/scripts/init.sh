#!/bin/bash

# Initialize Ordo directory structure and configuration
# Usage: ./init.sh

set -euo pipefail

# Configuration - Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
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

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_header "Ordo Initialization"

echo "Initializing Ordo in: $ORDO_DIR"

# Create necessary directories
print_header "Creating Directory Structure"

directories=(
    "$ORDO_DIR/logs"
    "$ORDO_DIR/cache"
    "$HOME/mounts"
)

for dir in "${directories[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_success "Created: $dir"
    else
        print_info "Already exists: $dir"
    fi
done

# Handle configuration file
print_header "Configuration Setup"

config_file="$ORDO_DIR/config/remotes.conf"
template_file="$ORDO_DIR/config/remotes.conf.template"

if [[ ! -f "$config_file" ]]; then
    if [[ -f "$template_file" ]]; then
        cp "$template_file" "$config_file"
        print_success "Created configuration file from template"
        print_info "Edit $config_file to configure your remotes"
    else
        # Create basic config if template doesn't exist
        cat > "$config_file" << 'EOF'
# Ordo Remote Configuration
# List one rclone remote per line
# Lines starting with # are comments
#
# Example:
# your-remote-name

EOF
        print_success "Created basic configuration file"
    fi
else
    print_info "Configuration file already exists: $config_file"
fi

# Make scripts executable
print_header "Setting Script Permissions"

for script in "$SCRIPT_DIR"/*.sh; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        script_name=$(basename "$script")
        print_success "Made executable: $script_name"
    fi
done

# Check rclone availability
print_header "System Check"

if command -v rclone &> /dev/null; then
    rclone_version=$(rclone version | head -n1)
    print_success "rclone available: $rclone_version"
    
    # List available remotes
    available_remotes=$(rclone listremotes | sed 's/:$//' || echo "")
    if [[ -n "$available_remotes" ]]; then
        print_success "Available rclone remotes found:"
        echo "$available_remotes" | while read -r remote; do
            [[ -n "$remote" ]] && echo "  - $remote"
        done
        echo
        print_info "Add these remotes to $config_file to use them with Ordo"
    else
        print_info "No rclone remotes configured yet"
        print_info "Use 'rclone config' to set up your cloud storage connections"
    fi
else
    print_info "rclone not found - please install rclone first"
    echo "  Visit: https://rclone.org/install/"
fi

print_header "Next Steps"

echo "1. Configure your remotes in: $config_file"
echo "2. Run automount: $SCRIPT_DIR/automount.sh"
echo "3. Check status: $SCRIPT_DIR/status.sh"
echo
echo "For help with any script, run it without arguments or check the README.md"

print_success "Ordo initialization complete!"