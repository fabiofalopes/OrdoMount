# Ordo Production Readiness

This document describes what “production-ready” means for Ordo’s always-on sync daemon and how to operate it.

## Goal

- Sync daemon starts automatically on boot/reboot/power-on.
- Daemon restarts on crash and avoids restart storms.
- Daemon is supervised (systemd watchdog) and remains observable.
- Logs do not grow without bound.

## Service Model (recommended)

The daemon is optimized to avoid sync storms:

- **Inotify event coalescing**: small bursts of editor saves become one sync.
- **Rate limiting**: ensures a minimum time between sync runs.

Ordo runs as a **systemd user service** with **linger** enabled.

Why:
- Uses your existing `~/.config/rclone` without root.
- Starts at boot (when linger is enabled).
- Restarts automatically on failure.

## Install / Enable

1) Install the service:

```bash
mkdir -p ~/.config/systemd/user
install -m 644 /home/fabio/projetos/hub/OrdoMount/ordo/systemd/ordo-sync.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable ordo-sync.service
systemctl --user start --no-block ordo-sync.service
```

2) Enable boot start:

```bash
loginctl enable-linger "$USER"
```

## Health Supervision (watchdog)

- Service uses `WatchdogSec=60` and `Type=simple`.
- Unit sets `NotifyAccess=all` so watchdog heartbeats sent by a helper process are accepted.

View unit configuration:

```bash
systemctl --user cat ordo-sync.service
systemctl --user show ordo-sync.service -p WatchdogUSec -p Type -p NotifyAccess -p WatchdogTimestamp
```

## Logging

- Journald: `journalctl --user -u ordo-sync.service`
- File log: `/home/fabio/projetos/hub/OrdoMount/ordo/logs/ordo-sync.log` (contains wrapper logs and rclone logs)

Tail file log:

```bash
tail -n 200 /home/fabio/projetos/hub/OrdoMount/ordo/logs/ordo-sync.log
```

## Log Rotation (user timer)

Ordo provides a user-level timer that rotates `ordo/logs/*.log` daily and keeps 14 rotations.

Install/enable:

```bash
chmod +x /home/fabio/projetos/hub/OrdoMount/ordo/scripts/ordo-logrotate.sh
install -m 644 /home/fabio/projetos/hub/OrdoMount/ordo/systemd/ordo-logrotate.service ~/.config/systemd/user/
install -m 644 /home/fabio/projetos/hub/OrdoMount/ordo/systemd/ordo-logrotate.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable ordo-logrotate.timer
systemctl --user start --no-block ordo-logrotate.timer
```

Check next run:

```bash
systemctl --user list-timers --all | grep -F ordo-logrotate
```

Force a run now:

```bash
systemctl --user start ordo-logrotate.service
```

## Day-to-day Commands

```bash
systemctl --user status --no-pager ordo-sync.service
journalctl --user -u ordo-sync.service -e --no-pager

systemctl --user restart ordo-sync.service
systemctl --user stop ordo-sync.service

# Daemon self-reported state/health
/home/fabio/projetos/hub/OrdoMount/ordo/scripts/ordo-sync.sh health
```

## Daemon State / Health

The daemon periodically writes a small key/value state file used for quick diagnostics:

- Default path: `$XDG_RUNTIME_DIR/ordo/sync/daemon.state`
  - Fallback: `$XDG_CACHE_HOME/ordo/sync/daemon.state` or `~/.cache/ordo/sync/daemon.state`
- Fields: `updated_at`, `status`, `mode` (and occasionally extra keys)
- `health` exits non-zero if `updated_at` is older than 300 seconds

## Validation Checklist

- Boot start
  - `loginctl show-user "$USER" -p Linger`
  - Reboot, then: `systemctl --user is-active ordo-sync.service`
- Crash recovery
  - `systemctl --user kill -s SIGKILL ordo-sync.service`
  - Confirm it restarts: `systemctl --user status ordo-sync.service`
- Watchdog
  - Confirm watchdog enabled: `systemctl --user show ordo-sync.service -p WatchdogUSec`
- Logs
  - `journalctl --user -u ordo-sync.service -e --no-pager`
  - `ls -la /home/fabio/projetos/hub/OrdoMount/ordo/logs`
- Rotation
  - `systemctl --user start ordo-logrotate.service`
  - Confirm rotated files appear under `ordo/logs/`.
