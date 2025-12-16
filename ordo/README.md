# Ordo – Complete Documentation

## Overview

Ordo is a local-first cloud storage system with two distinct operation modes:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           ORDO ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MIRROR MODE                        CLOUD-ONLY MODE                     │
│  (sync-targets.conf)                (remotes.conf)                      │
│                                                                         │
│  ┌─────────────┐                    ┌─────────────┐                     │
│  │ ~/Documents │ ←──bisync──→       │  /media/$USER/gdrive/  │          │
│  │ (local)     │      Cloud         │  (FUSE mount)          │          │
│  └─────────────┘                    └─────────────┘                     │
│        ↑                                   ↑                            │
│   Apps point here                    Humans browse here                 │
│   Daemon syncs                       No local copy                      │
│   Works offline                      Unmount when done                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y rclone fuse3 inotify-tools

# Arch
sudo pacman -S rclone fuse3 inotify-tools
```

### Configure rclone Remotes

```bash
rclone config
# Follow prompts to add OneDrive, Google Drive, etc.
# Example names: onedrive-personal, gdrive-work
```

### Setup Ordo

```bash
./setup.sh
```

This will:
1. Initialize directories and configs
2. Optionally mount remotes for browsing
3. Configure sync targets
4. Optionally start background daemon

---

## MIRROR Mode

**Purpose**: Complete bidirectional sync – local copy always matches cloud.

**Use for**: Documents, projects, Obsidian vaults – anything you need offline and synced.

### Configuration

Edit `config/sync-targets.conf`:

```bash
# Format: local_path|remote_path|sync_frequency_seconds|rclone_flags
/home/user/Documents|onedrive:Documents|300|
/home/user/SharedProject|gdrive:SharedProject|180|--drive-shared-with-me
```

### Commands

```bash
# Add new sync target
./scripts/ordo-sync.sh init ~/NewFolder remote:NewFolder 300

# Add Google Drive "Shared with me" folder
./scripts/ordo-sync.sh init ~/Shared/Team gdrive:TeamFolder 300 "--drive-shared-with-me"

# Manual sync
./scripts/ordo-sync.sh sync

# Check status
./scripts/ordo-sync.sh status

# Verify sync (dry-run, safe)
./scripts/ordo-sync.sh verify

# Start background daemon
./scripts/ordo-sync.sh daemon &

# Or use watch mode (syncs on file changes)
./scripts/ordo-sync.sh daemon watch
```

### Stop Mirroring

Comment out or delete the line in `config/sync-targets.conf`:

```bash
# DISABLED: /home/user/OldProject|gdrive:OldProject|300|
```

Local files remain – they just stop syncing.

### Daemon Modes

| Mode | Behavior |
|------|----------|
| `daemon` | Polls at configured intervals |
| `daemon watch` | Uses inotify – syncs immediately on local changes |

---

## CLOUD-ONLY Mode

**Purpose**: Mount cloud storage for browsing – files stay in cloud, no local copy.

**Use for**: Occasional access, uploading files, browsing archives.

### Configuration

Edit `config/remotes.conf`:

```bash
# Format: remote_name|mount_suffix|rclone_flags
onedrive||
gdrive||
gdrive|shared|--drive-shared-with-me
```

This creates:
- `/media/$USER/onedrive/` – Your OneDrive
- `/media/$USER/gdrive/` – Your Google Drive
- `/media/$USER/gdrive-shared/` – Google Drive "Shared with me"

### Commands

```bash
# Mount all configured remotes
./scripts/automount.sh

# Unmount all
./scripts/unmount-all.sh

# Browse
ls /media/$USER/gdrive-shared/

# Upload file to cloud (no local copy kept)
cp myfile.pdf /media/$USER/gdrive/Uploads/

# Download from cloud
cp /media/$USER/gdrive/report.pdf ~/Downloads/
```

### unmount-all.sh

**Only unmounts CLOUD-ONLY mounts.** Does NOT affect MIRROR mode folders.

---

## Google Drive "Shared with Me"

Access files others have shared with you:

### CLOUD-ONLY (just browse)

Add to `config/remotes.conf`:
```bash
gdrive|shared|--drive-shared-with-me
```

Then: `./scripts/automount.sh`

Browse at: `/media/$USER/gdrive-shared/`

### MIRROR (full sync)

```bash
./scripts/ordo-sync.sh init ~/Shared/TeamProject gdrive:TeamProject 300 "--drive-shared-with-me"
```

---

## Systemd Service (Auto-start)

For persistent daemon that survives reboots:

```bash
# Install service
./scripts/setup-systemd.sh

# Or manually:
mkdir -p ~/.config/systemd/user
cp systemd/ordo-sync.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ordo-sync.service
loginctl enable-linger "$USER"  # Run even when logged out
```

### Service Commands

```bash
systemctl --user status ordo-sync
systemctl --user restart ordo-sync
journalctl --user -u ordo-sync -f
```

---

## Troubleshooting

### Check Status

```bash
./scripts/status.sh              # Overall status
./scripts/ordo-sync.sh status    # Sync targets
./scripts/ordo-sync.sh health    # Daemon health
```

### View Logs

```bash
tail -f logs/ordo-sync.log       # Sync log
tail -f logs/automount.log       # Mount log
```

### Force Resync

```bash
ORDO_FORCE_RESYNC=1 ./scripts/ordo-sync.sh sync
```

### Conflicts

```bash
./scripts/ordo-sync.sh conflicts  # View conflicts
ls conflicts/                     # Conflict backups
```

### Stuck Bisync Lock

The daemon auto-clears stale locks. If needed manually:

```bash
rm ~/.cache/rclone/bisync/*.lck
```

---

## Configuration Reference

### sync-targets.conf (MIRROR)

```bash
# Format: local_path|remote_path|sync_frequency_seconds|rclone_flags
#
# Examples:
/home/user/Documents|onedrive:Documents|300|
/home/user/Shared|gdrive:Shared|180|--drive-shared-with-me
```

### remotes.conf (CLOUD-ONLY)

```bash
# Format: remote_name|mount_suffix|rclone_flags
#
# Examples:
onedrive||                              # → /media/$USER/onedrive/
gdrive||                                # → /media/$USER/gdrive/
gdrive|shared|--drive-shared-with-me    # → /media/$USER/gdrive-shared/
```

### sync-excludes.conf

Patterns to exclude from sync (uses rclone filter syntax).

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ORDO_REMOTE_POLL_INTERVAL` | 300 | Seconds between remote polls in watch mode |
| `ORDO_BISYNC_TIMEOUT_SEC` | 0 | Timeout for bisync (0 = no timeout) |
| `ORDO_FORCE_RESYNC` | 0 | Set to 1 to force --resync |
| `ORDO_USE_EXCLUDES` | 1 | Set to 0 to disable exclusions |

---

## Directory Structure

```
ordo/
├── config/
│   ├── sync-targets.conf    # MIRROR mode targets
│   ├── remotes.conf         # CLOUD-ONLY mounts
│   └── sync-excludes.conf   # Exclusion patterns
├── scripts/
│   ├── ordo-sync.sh         # Main sync script
│   ├── automount.sh         # Mount cloud remotes
│   ├── mount-remote.sh      # Mount single remote
│   ├── unmount-all.sh       # Unmount all
│   ├── status.sh            # Show status
│   ├── init.sh              # Initialize Ordo
│   └── setup-systemd.sh     # Install systemd service
├── systemd/
│   └── ordo-sync.service    # Systemd unit file
├── logs/                    # Log files
├── conflicts/               # Conflict backups
└── setup.sh                 # Interactive setup
```

---

## Philosophy

> **Applications should never know files are synced.**

- Point apps to local paths (`~/Documents/`)
- NOT to mount points (`/media/$USER/...`)
- Background sync keeps local files current
- Zero crashes from network issues

**MIRROR** = for apps, works offline, constant sync
**CLOUD-ONLY** = for humans, browse when connected, no local copy
