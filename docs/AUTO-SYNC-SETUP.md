# Ordo Auto-Sync: Findings and How-To

Date: 2025-09-08

## What we found

- Sync engine: `ordo/scripts/ordo-sync.sh` (uses rclone bisync; logs to `ordo/logs/ordo-sync.log`).
- Configured target: `Documents`
  - Local: `/home/fabio/Documents`
  - Remote: `onedrive-f6388:Documents/`
  - Frequency: `100s` (from `ordo/config/sync-targets.conf`)
- Manual sync works: a one-time `sync` run completed successfully just now and shows “Bidirectional sync completed”.
- Auto-sync service: systemd user units exist in repo under `ordo/systemd/` and can be installed/enabled (recommended: run `ordo/scripts/setup-systemd.sh`).
- Daemon behavior: `./ordo-sync.sh daemon` uses inotify for instant local change detection when `inotifywait` is available, plus periodic remote polling (`ORDO_REMOTE_POLL_INTERVAL`, default 300s or 120s in the service file).

## Goal

Enable continuous auto-sync so local changes in `Documents` sync automatically to OneDrive, and remote-side changes are picked up regularly.

## Option A — Start the daemon now (foreground or tmux)

- Start responsive daemon (watches local changes, polls remote):

```bash
cd /home/fabio/projetos/hub/OrdoMount/ordo/scripts
./ordo-sync.sh daemon 300
```

- Stop with Ctrl+C. For a background session, use tmux/screen or `nohup`.

## Option B — Enable auto-start on boot via systemd user service (recommended)

### Quick install (recommended)

Run the installer (idempotent):

```bash
/home/fabio/projetos/hub/OrdoMount/ordo/scripts/setup-systemd.sh
```

Dry-run:

```bash
/home/fabio/projetos/hub/OrdoMount/ordo/scripts/setup-systemd.sh --dry-run
```

### Manual install

1) Ensure inotify tools (for instant local change detection):

```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y inotify-tools
# Arch
# sudo pacman -S --needed inotify-tools
# Fedora
# sudo dnf install -y inotify-tools
```

2) Install and enable the user service:

```bash
mkdir -p ~/.config/systemd/user
install -m 644 /home/fabio/projetos/hub/OrdoMount/ordo/systemd/ordo-sync.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable ordo-sync.service
systemctl --user start --no-block ordo-sync.service
```

Note: this service uses systemd watchdog. Ensure `systemd-notify` is available (normally installed with systemd).

3) Enable boot start (required for start-on-boot):

```bash
# Keep user services running at boot and after logout
loginctl enable-linger "$USER"
```

4) Verify:

```bash
systemctl --user status --no-pager ordo-sync.service
systemctl --user show ordo-sync.service -p Type -p WatchdogUSec -p NotifyAccess -p WatchdogTimestamp
journalctl --user -u ordo-sync.service -e --no-pager

# Ordo sync file log
tail -n 200 /home/fabio/projetos/hub/OrdoMount/ordo/logs/ordo-sync.log
```

## Log rotation (recommended)

Ordo writes an rclone-backed file log at `ordo/logs/ordo-sync.log`. Enable the provided user-level timer to rotate logs daily:

```bash
chmod +x /home/fabio/projetos/hub/OrdoMount/ordo/scripts/ordo-logrotate.sh
install -m 644 /home/fabio/projetos/hub/OrdoMount/ordo/systemd/ordo-logrotate.service ~/.config/systemd/user/
install -m 644 /home/fabio/projetos/hub/OrdoMount/ordo/systemd/ordo-logrotate.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ordo-logrotate.timer
```

Force a run:

```bash
systemctl --user start ordo-logrotate.service
```

## Customize behavior

- Service defaults (see `ordo/systemd/ordo-sync.service`):
  - `ORDO_REMOTE_POLL_INTERVAL=120` (poll remote every 2 min)
  - `ORDO_BISYNC_TIMEOUT_SEC=0` (no external timeout)
  - `ORDO_USE_EXCLUDES=1` (use `ordo/config/sync-excludes.conf` if present)
  - `ORDO_DEBOUNCE_SEC=2` (coalesce bursts of local file events)
  - `ORDO_MIN_SYNC_INTERVAL_SEC=30` (rate limit sync runs)
- To adjust, edit your copy in `~/.config/systemd/user/ordo-sync.service`, then:

```bash
systemctl --user daemon-reload
systemctl --user restart ordo-sync.service
```

## Day-to-day commands

```bash
# One-time sync on demand
cd /home/fabio/projetos/hub/OrdoMount/ordo/scripts && ./ordo-sync.sh sync

# Check status & recent activity
./ordo-sync.sh status

# Dry-run verification of drift
./ordo-sync.sh verify

# Daemon health / state (reads the daemon state file)
./ordo-sync.sh health
```

## Daemon state file

The daemon writes a small key/value state file for quick health checks:

- Path: `$XDG_RUNTIME_DIR/ordo/sync/daemon.state` (or `$XDG_CACHE_HOME/ordo/sync/daemon.state`, or `~/.cache/ordo/sync/daemon.state`)
- Used by: `./ordo-sync.sh health`
- Staleness: `health` exits non-zero if `updated_at` is older than 300 seconds

## Add or change sync targets

- Preferred: use `init` to add targets safely (creates dirs, checks remote, appends to config):

```bash
./ordo-sync.sh init <local-path> <remote-name:path> [frequency-seconds]
# Example:
./ordo-sync.sh init ~/ObsidianVaults/MyVault onedrive-f6388:Documents/ObsidianVaults/MyVault 300
```

- Config file: `ordo/config/sync-targets.conf` (format: `local|remote|frequencySeconds`).

## Conflicts and recovery

- Bisync uses `--conflict-resolve newer` and adds a suffix if needed; see `ordo/logs/ordo-sync.log` for details.
- The script also guards against stale rclone bisync locks and avoids overlapping runs.
- If things look off, you can force a one-time rebuild of listings:

```bash
# Applies to the next run only
export ORDO_FORCE_RESYNC=1
./ordo-sync.sh sync
unset ORDO_FORCE_RESYNC
```

- Inspect potential conflicts/backups with:

```bash
./ordo-sync.sh conflicts
```

## Troubleshooting quick checks

- Is rclone installed and OneDrive remote reachable?

```bash
rclone version
rclone lsd onedrive-f6388:
```

- Is the service running? Any errors?

```bash
systemctl --user is-active ordo-sync.service
journalctl --user -u ordo-sync.service -e --no-pager
```

- Logs:
  - Main: `/home/fabio/projetos/hub/OrdoMount/ordo/logs/ordo-sync.log`
  - Automount (if used): `/home/fabio/projetos/hub/OrdoMount/ordo/logs/automount.log`

## Summary

- Recommended path: run `/home/fabio/projetos/hub/OrdoMount/ordo/scripts/setup-systemd.sh`.
- Ensure boot start: `loginctl enable-linger "$USER"`.
- Enable `ordo-logrotate.timer` to keep `ordo/logs/*.log` bounded.
