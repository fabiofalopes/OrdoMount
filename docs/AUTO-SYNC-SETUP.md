# Ordo Auto-Sync: Findings and How-To

Date: 2025-09-08

## What we found

- Sync engine: `ordo/scripts/ordo-sync.sh` (uses rclone bisync; logs to `ordo/logs/ordo-sync.log`).
- Configured target: `Documents`
  - Local: `/home/fabio/Documents`
  - Remote: `onedrive-f6388:Documents/`
  - Frequency: `100s` (from `ordo/config/sync-targets.conf`)
- Manual sync works: a one-time `sync` run completed successfully just now and shows “Bidirectional sync completed”.
- Auto-sync service: a user-level systemd unit exists in repo at `ordo/systemd/ordo-sync.service`, but it’s not installed/enabled yet (no running service was found).
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

## Option B — Enable auto-start at login via systemd (recommended)

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
systemctl --user enable --now ordo-sync.service
```

3) (Optional) Keep running even after logout:

```bash
# Requires your user to be allowed lingering
loginctl enable-linger "$USER"
```

4) Verify:

```bash
systemctl --user status --no-pager ordo-sync.service
journalctl --user -u ordo-sync.service -e --no-pager
# Ordo sync log
tail -n 200 /home/fabio/projetos/hub/OrdoMount/ordo/logs/ordo-sync.log
```

## Customize behavior

- Service defaults (see `ordo/systemd/ordo-sync.service`):
  - `ORDO_REMOTE_POLL_INTERVAL=120` (poll remote every 2 min)
  - `ORDO_BISYNC_TIMEOUT_SEC=0` (no external timeout)
  - `ORDO_USE_EXCLUDES=1` (use `ordo/config/sync-excludes.conf` if present)
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
```

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

- Current state: manual sync works; auto-sync not yet enabled as a systemd user service.
- Do this to finish: install the provided unit, enable and start it (Option B). That gives continuous syncing with instant local change detection and periodic remote polling.
