# Ordo – Local-First Cloud Storage

**Zero app crashes. Always-available files. Background sync that just works.**

Ordo provides seamless cloud storage integration with two distinct modes:

| Mode | Purpose | Files Location |
|------|---------|----------------|
| **MIRROR** | Full local copy, constant bidirectional sync | Local folder (e.g., `~/Documents`) |
| **CLOUD-ONLY** | Browse/upload without local copy | Mount point (`/media/$USER/remote/`) |

## Quick Start

```bash
# Prerequisites (Debian/Ubuntu)
sudo apt install -y rclone fuse3 inotify-tools

# Configure rclone remote
rclone config

# Setup Ordo
cd OrdoMount/ordo
./setup.sh
```

## The Two Modes

### MIRROR Mode – Full Sync (like Dropbox/OneDrive)
For folders you need offline and constantly synced. Daemon monitors and syncs automatically.

```bash
# Config: ordo/config/sync-targets.conf
~/Documents|onedrive:Documents|300|
~/SharedProject|gdrive:SharedProject|180|--drive-shared-with-me

# Commands
./scripts/ordo-sync.sh sync      # Force sync now
./scripts/ordo-sync.sh status    # Check status
./scripts/ordo-sync.sh daemon &  # Start background sync
```

**Stop mirroring**: Comment out line with `#` in config (local files stay)

### CLOUD-ONLY Mode – Browse Without Local Copy
For occasional access, uploading files, browsing archives. No local copy stored.

```bash
# Config: ordo/config/remotes.conf
onedrive||
gdrive|shared|--drive-shared-with-me

# Commands
./scripts/automount.sh           # Mount all remotes
./scripts/unmount-all.sh         # Unmount all
ls /media/$USER/gdrive-shared/   # Browse
cp file.pdf /media/$USER/gdrive/ # Upload to cloud
```

## Daily Commands

```bash
# Status
./scripts/status.sh              # Overall status
./scripts/ordo-sync.sh status    # Sync targets status
./scripts/ordo-sync.sh verify    # Verify sync (dry-run)

# Sync
./scripts/ordo-sync.sh sync      # Manual sync all targets
./scripts/ordo-sync.sh daemon &  # Background daemon

# Mounts
./scripts/automount.sh           # Mount cloud remotes for browsing
./scripts/unmount-all.sh         # Unmount all
```

## Add New Targets

```bash
# MIRROR: Full sync with local copy
./scripts/ordo-sync.sh init ~/Projects/Work gdrive:Projects/Work 300

# MIRROR: Google Drive "Shared with me"
./scripts/ordo-sync.sh init ~/Shared/TeamDocs gdrive:TeamDocs 300 "--drive-shared-with-me"
```

## Key Philosophy

> **Applications point to LOCAL paths only. Never to mount points.**

- MIRROR mode: Apps use `~/Documents/` (local folder that syncs)
- CLOUD-ONLY mode: For human browsing, not for apps

## Docs

- Main documentation: `ordo/README.md`
- Production operations: `docs/PRODUCTION-READY.md`
- Architecture diagram: `docs/ORDO-ERD.md`
- FHS mount reference: `docs/FHS-MOUNT-REFERENCE.md`

## Requirements

- Linux with FUSE support
- rclone installed and configured
- inotify-tools (for responsive file watching)

---

**Motto**: Local files that sync in background. Zero application interference.
