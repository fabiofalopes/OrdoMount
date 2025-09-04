# Ordo - Local-First Cloud Storage

**Zero application crashes. Always-available files. Background sync.**

Ordo provides a hybrid approach to cloud storage that eliminates the fundamental problem of applications crashing when network connectivity drops.

## The Problem Ordo Solves

**Traditional cloud storage approaches fail applications:**
- Mount-based solutions cause apps to crash when network drops
- Applications become unresponsive waiting for network-dependent file operations
- Complex VFS caching doesn't prevent connection-dependent behavior
- Users need "emergency fix" scripts to recover from frozen applications

## The Ordo Solution

**Local-first with background sync** (like OneDrive/Dropbox model):
- ✅ **Applications always work** - Point to truly local files
- ✅ **Zero crashes** - Network issues never affect applications  
- ✅ **Background sync** - Files sync transparently when connected
- ✅ **Browse everything** - Optional remote mounts for exploration
- ✅ **Set and forget** - Minimal maintenance after setup

## Quick Start

### 1. One-Time Setup
```bash
./setup.sh
```
This interactive script will:
- Initialize Ordo
- Configure remote browsing (optional)
- Set up local sync targets
- Start background sync daemon

### 2. Point Applications to Local Files
```bash
# Example: Obsidian vault
# Setup creates: ~/ObsidianVaults/MyVault/
# Point Obsidian to: ~/ObsidianVaults/MyVault/
# Syncs with: onedrive:Documents/ObsidianVaults/MyVault

# Example: Project development  
# Setup creates: ~/Documents/MyProject/
# Point your IDE to: ~/Documents/MyProject/
# Syncs with: gdrive:Projects/MyProject
```

### 3. That's It!
- Files sync automatically in background
- Applications never know files are synced
- Work completely offline
- Browse all remote files at `/media/$USER/remote-name/` when connected

## Architecture

### Two-Tier System
1. **Local Sync Targets** (`~/Documents/`, `~/ObsidianVaults/`)
   - Where applications point
   - Always available (even offline)
   - Background sync keeps current

2. **Remote Browse Mounts** (`/media/$USER/remote-name/`)
   - For exploring all remote files
   - Only when connected
   - Like plugging in a USB drive

### Directory Structure
```
# Local Sync Targets (for applications)
~/ObsidianVaults/MyVault/     ← Point Obsidian here
~/Documents/MyProject/        ← Point IDE here
~/Documents/important.txt     ← Always available

# Remote Browse Mounts (for exploration)  
/media/$USER/onedrive/        ← Browse when connected
/media/$USER/gdrive/          ← Browse when connected
```

## Core Commands

### Setup (run once)
```bash
./setup.sh                    # Interactive production setup
```

### Daily Use
```bash
./scripts/status.sh           # Check overall status
./scripts/ordo-sync.sh status # Check sync targets
```

### Manual Operations
```bash
./scripts/ordo-sync.sh sync         # Force sync now
./scripts/ordo-sync.sh daemon &     # Start background sync
./scripts/ordo-sync.sh conflicts    # View/resolve conflicts
./scripts/automount.sh              # Mount remotes for browsing
```

### Add New Sync Targets
```bash
./scripts/ordo-sync.sh init ~/Documents/NewProject gdrive:Projects/NewProject
```

## Key Benefits

### For Users
- **Never lose work** - Files always available locally
- **No application crashes** - Network issues don't affect apps
- **Simple workflow** - Edit locally, sync happens automatically
- **Browse everything** - Access all remote files when needed

### For Developers  
- **Reliable development** - IDE never freezes on network issues
- **Version control works** - Git repos are truly local
- **Build systems work** - No network dependencies in build process
- **Debugging works** - No mysterious network-related hangs

### For Obsidian Users
- **Vault always opens** - Never crashes on network drops
- **Fast search/indexing** - All files are local
- **Plugin compatibility** - Plugins work with local files
- **Mobile sync** - Background sync keeps mobile app current

## Requirements

- **rclone** installed and configured with your cloud storage
- **Linux with FUSE support** (usually pre-installed)
- **Sufficient local disk space** for sync targets

## Troubleshooting

### Sync Issues
```bash
./scripts/ordo-sync.sh status     # Check sync status
./scripts/ordo-sync.sh conflicts  # View conflicts
./scripts/ordo-sync.sh sync       # Force sync
```

### Mount Issues
```bash
./scripts/status.sh               # Check mount status  
./scripts/unmount-all.sh          # Clean unmount
./scripts/automount.sh            # Remount for browsing
```

### Logs
- **Sync logs**: `logs/ordo-sync.log`
- **Mount logs**: `logs/automount.log`
- **Conflicts**: `conflicts/` directory

## Configuration Files

### `config/sync-targets.conf` - Local Sync Targets
```
# Format: local_path|remote_path|sync_frequency_seconds
/home/user/ObsidianVaults/MyVault|onedrive:Documents/ObsidianVaults/MyVault|300
/home/user/Documents/Project|gdrive:Projects/Project|180
```

### `config/remotes.conf` - Remote Browsing (Optional)
```
# List rclone remotes for browsing mounts
onedrive
gdrive
```

## Philosophy

**Applications should never know files are synced.**

- Point applications to `~/Documents/MyProject/` (local)
- NOT to `/media/$USER/gdrive/Projects/MyProject/` (remote)
- Background sync keeps local files current with remote
- Browse remote files separately when needed

## Migration from Mount-Based Systems

If you're coming from a mount-based approach:

1. **Stop pointing applications to mount points**
2. **Run `./setup.sh` to create local sync targets**  
3. **Point applications to new local paths**
4. **Let background sync handle synchronization**

## Advanced Usage

### Daemon Management
```bash
# Start daemon
nohup ./scripts/ordo-sync.sh daemon > /dev/null 2>&1 &

# Find daemon PID
ps aux | grep ordo-sync

# Stop daemon  
kill <PID>
```

### Custom Sync Frequencies
```bash
# Sync every 1 minute (60 seconds)
./scripts/ordo-sync.sh init ~/Documents/Critical onedrive:Critical 60

# Sync every 10 minutes (600 seconds)  
./scripts/ordo-sync.sh init ~/Documents/Normal gdrive:Normal 600
```

---

**Motto**: Local files that sync in background. Zero application interference.

**Result**: From complex mount-based solutions with emergency fix scripts to simple local-first approach that just works.