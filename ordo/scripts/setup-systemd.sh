#!/bin/bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $*"; }
print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
print_error() { echo -e "${RED}✗${NC} $*"; }

die() {
    print_error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  ./setup-systemd.sh [--dry-run]

Installs Ordo systemd user services (sync + log rotation), enables boot start via linger,
and runs a basic verification.

Options:
  --dry-run   Print what would be done, do not change anything.
EOF
}

DRY_RUN=0
if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
    usage
    exit 0
fi
if [[ ${1:-} == "--dry-run" ]]; then
    DRY_RUN=1
fi

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        print_info "[dry-run] $*"
        return 0
    fi
    "$@"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

need_cmd systemctl
need_cmd install
need_cmd mkdir
need_cmd id

if ! command -v systemd-notify >/dev/null 2>&1; then
    print_warning "systemd-notify not found; watchdog heartbeats will be disabled"
    print_warning "Install systemd (and ensure systemd-notify is in PATH) for watchdog supervision."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDO_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$(dirname "$ORDO_DIR")"

SYNC_SCRIPT="$ORDO_DIR/scripts/ordo-sync.sh"
LOGROTATE_SCRIPT="$ORDO_DIR/scripts/ordo-logrotate.sh"

SYNC_UNIT_SRC="$ORDO_DIR/systemd/ordo-sync.service"
LOGROTATE_SERVICE_SRC="$ORDO_DIR/systemd/ordo-logrotate.service"
LOGROTATE_TIMER_SRC="$ORDO_DIR/systemd/ordo-logrotate.timer"

USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
SYNC_OVERRIDE_DIR="$USER_SYSTEMD_DIR/ordo-sync.service.d"
LOGROTATE_OVERRIDE_DIR="$USER_SYSTEMD_DIR/ordo-logrotate.service.d"

print_info "Ordo systemd setup (user service)"
print_info "Repo: $REPO_DIR"

if [[ ! -x "$SYNC_SCRIPT" ]]; then
    die "Sync script not found or not executable: $SYNC_SCRIPT"
fi

if [[ ! -x "$LOGROTATE_SCRIPT" ]]; then
    print_warning "Logrotate script not executable: $LOGROTATE_SCRIPT"
    print_warning "Fixing permissions: chmod +x '$LOGROTATE_SCRIPT'"
    run chmod +x "$LOGROTATE_SCRIPT" || true
fi

for f in "$SYNC_UNIT_SRC" "$LOGROTATE_SERVICE_SRC" "$LOGROTATE_TIMER_SRC"; do
    if [[ ! -f "$f" ]]; then
        die "Missing unit file: $f"
    fi
done

print_info "Installing unit files into: $USER_SYSTEMD_DIR"
run mkdir -p "$USER_SYSTEMD_DIR"

run install -m 644 "$SYNC_UNIT_SRC" "$USER_SYSTEMD_DIR/"
run install -m 644 "$LOGROTATE_SERVICE_SRC" "$USER_SYSTEMD_DIR/"
run install -m 644 "$LOGROTATE_TIMER_SRC" "$USER_SYSTEMD_DIR/"

# Make ExecStart independent from repo location via drop-in override.
# (The shipped unit uses %h/... paths, but we want this to work anywhere.)
print_info "Writing drop-in overrides (absolute ExecStart)"
run mkdir -p "$SYNC_OVERRIDE_DIR" "$LOGROTATE_OVERRIDE_DIR"

SYNC_OVERRIDE_FILE="$SYNC_OVERRIDE_DIR/override.conf"
LOGROTATE_OVERRIDE_FILE="$LOGROTATE_OVERRIDE_DIR/override.conf"

SYNC_OVERRIDE_CONTENT="[Service]
ExecStart=
ExecStart=$SYNC_SCRIPT daemon 300
"

LOGROTATE_OVERRIDE_CONTENT="[Service]
ExecStart=
ExecStart=$LOGROTATE_SCRIPT
"

if [[ "$DRY_RUN" == "1" ]]; then
    print_info "[dry-run] write $SYNC_OVERRIDE_FILE"
    print_info "$SYNC_OVERRIDE_CONTENT"
    print_info "[dry-run] write $LOGROTATE_OVERRIDE_FILE"
    print_info "$LOGROTATE_OVERRIDE_CONTENT"
else
    printf '%s' "$SYNC_OVERRIDE_CONTENT" >"$SYNC_OVERRIDE_FILE"
    printf '%s' "$LOGROTATE_OVERRIDE_CONTENT" >"$LOGROTATE_OVERRIDE_FILE"
fi

print_info "Reloading user systemd units"
run systemctl --user daemon-reload

print_info "Resetting failed state (if any)"
run systemctl --user reset-failed ordo-sync.service ordo-logrotate.timer ordo-logrotate.service || true

# Stop old instances cleanly before restart (avoids transient multi-instance behavior).
run systemctl --user stop ordo-sync.service || true
run systemctl --user stop ordo-logrotate.timer || true

wait_active() {
    local unit_name="$1"
    local timeout_sec="${2:-20}"

    local start_time
    start_time=$(date +%s)

    while true; do
        if systemctl --user is-active --quiet "$unit_name"; then
            return 0
        fi

        local now
        now=$(date +%s)
        if (( now - start_time >= timeout_sec )); then
            return 1
        fi

        sleep 1
    done
}

print_info "Enabling services"
run systemctl --user enable ordo-sync.service
run systemctl --user enable ordo-logrotate.timer

print_info "Starting/restarting services"
run systemctl --user restart --no-block ordo-sync.service
run systemctl --user restart --no-block ordo-logrotate.timer

if [[ "$DRY_RUN" != "1" ]]; then
    if ! wait_active ordo-sync.service 30; then
        print_warning "ordo-sync.service did not become active within timeout"
        run systemctl --user status --no-pager ordo-sync.service || true
        run journalctl --user -u ordo-sync.service -n 200 --no-pager || true
    fi

    if ! wait_active ordo-logrotate.timer 10; then
        print_warning "ordo-logrotate.timer did not become active within timeout"
        run systemctl --user status --no-pager ordo-logrotate.timer || true
    fi
fi

print_info "Enabling linger for boot start"
if command -v loginctl >/dev/null 2>&1; then
    if ! run loginctl enable-linger "$(id -un)"; then
        print_warning "Could not enable linger automatically."
        print_warning "Try running: loginctl enable-linger \"$USER\""
        print_warning "(May require admin/polkit approval on some distros.)"
    fi
else
    print_warning "loginctl not found; cannot enable linger automatically."
    print_warning "Install systemd-logind/loginctl and run: loginctl enable-linger \"$USER\""
fi

print_info "Basic verification"
run systemctl --user is-enabled ordo-sync.service
run systemctl --user is-active ordo-sync.service
run systemctl --user show ordo-sync.service -p Type -p WatchdogUSec -p NotifyAccess -p WatchdogTimestamp -p ExecStart

run systemctl --user is-enabled ordo-logrotate.timer
run systemctl --user is-active ordo-logrotate.timer

print_info "Testing log rotation once"
run systemctl --user start ordo-logrotate.service || true

print_info "Linger status"
if command -v loginctl >/dev/null 2>&1; then
    run loginctl show-user "$(id -un)" -p Linger || true
fi

print_success "Done."
print_info "View logs: journalctl --user -u ordo-sync.service -e --no-pager"
print_info "View file log: tail -n 200 '$ORDO_DIR/logs/ordo-sync.log'"
