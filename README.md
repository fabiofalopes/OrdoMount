# Ordo – Local‑First Cloud Storage (rclone)

Zero application freezes. Always‑available local files. Background sync that just works.

Ordo replaces app‑on‑mounts with a local‑first design: apps use local folders (e.g., `~/Documents/`), while rclone bisync keeps them in sync with your cloud. Optional mounts under `/media/$USER/` are for browsing only.

## Quick Start

```bash
git clone <repository-url>
cd OrdoMount
./ordo/setup.sh
```

Prerequisites (Debian/Ubuntu):
```bash
sudo apt update
sudo apt install -y rclone fuse3 inotify-tools
```

Then configure rclone remotes (OneDrive/Google Drive/etc.):
```bash
rclone config
# Create a remote, e.g. "onedrive-f6388" or "g-drive-f6388" and complete the OAuth flow
```

What setup does:
- Initializes directories and config
- Optionally mounts remotes for browsing under `/media/$USER/<remote>/`
- Configures sync targets (local ↔ remote)
- Optionally starts the background sync daemon

## Daily Use

```bash
# Status
./ordo/scripts/status.sh
./ordo/scripts/ordo-sync.sh status

# Manual sync and daemon
./ordo/scripts/ordo-sync.sh sync
nohup ./ordo/scripts/ordo-sync.sh daemon &

# Verify targets are in sync (read‑only)
./ordo/scripts/ordo-sync.sh verify

# Mount for browsing (not for apps)
./ordo/scripts/automount.sh
```

Add a new sync target:
```bash
./ordo/scripts/ordo-sync.sh init ~/Documents/MyProject g-drive-f6388:Projects/MyProject 300
```

Tip: replace `g-drive-f6388` with your own rclone remote name, e.g. `onedrive-f6388:Documents/MyProject`.

## Dependencies

- rclone (configured via `rclone config`)
- FUSE3 (for optional mounts)
- inotify-tools (for responsive file watching in daemon mode)

Install on Debian/Ubuntu:
```bash
sudo apt update
sudo apt install -y rclone fuse3 inotify-tools
```

## Persistent Daemon (optional)

Run the sync daemon on login and restart on failure using a user service:

1) Copy the service file to your user systemd directory
```bash
mkdir -p ~/.config/systemd/user
cp ordo/systemd/ordo-sync.service ~/.config/systemd/user/
```

2) Enable and start
```bash
systemctl --user daemon-reload
systemctl --user enable --now ordo-sync.service
loginctl enable-linger "$USER"   # optional: keep running after logout
```

Tune remote pull cadence (remote → local latency) by setting an environment variable in the service file:
- `Environment=ORDO_REMOTE_POLL_INTERVAL=120` (recommended 60–120s during active hours; 300–600s otherwise)

## Architecture

Two‑tier system:
- Local Sync Targets (for apps): `~/Documents/`, `~/ObsidianVaults/` – always available, bidirectionally synced in background
- Remote Browse Mounts (for humans): `/media/$USER/<remote>/` – explore full cloud when connected

Key philosophy: applications must point to local paths only. Never point apps to `/media/$USER/...`.

## Features

- Unified sync via `ordo/scripts/ordo-sync.sh` (rclone bisync)
	- Exclusions via `ordo/config/sync-excludes.conf`
	- Conflict policy: newer wins with timestamped conflict copies
	- Resilience: retries, low‑level retries, stats, lock cleanup
	- First‑run handling with `--resync` and local state marker
	- Safe `verify` command: dry‑run check, skips if a live bisync is running
- FHS‑compliant mounts under `/media/$USER/` for browsing
- Simple status and logs in `ordo/logs/`

## Requirements

- Linux with bash and FUSE
- rclone installed and configured (`rclone config`)
- Sufficient local disk space for your sync targets

Recommended extras:
- inotify-tools (for immediate sync on local file changes)

## Docs

- Getting started and concepts: `ordo/README.md`
- Analysis and plan: `docs/ANALYSIS-AND-STREAMLINED-PLAN.md`
- Implementation summary: `docs/IMPLEMENTATION-SUMMARY.md`
- State report (today): `docs/STATE-REPORT-2025-09-05.md`
- Exploration/testing log: `ordo/EXPLORATION-LOG.md`
- Production readiness: `ordo/PRODUCTION-READY.md`
- rclone command reference: `docs/rclone_commands_reference.md`

---

Motto: Local files that sync in the background. Zero application interference.