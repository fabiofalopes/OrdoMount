# Ordo Analysis & Streamlined Plan

## Current State Assessment

### What We Have (11 Scripts)
- `automount.sh` - Mount all remotes with VFS caching
- `mount-remote.sh` - Mount single remote with complex VFS settings
- `unmount-all.sh` - Unmount all mounts
- `force-unmount.sh` - Force unmount stuck mounts
- `emergency-fix.sh` - Kill processes and remount everything
- `remount-all.sh` - Unmount and remount all
- `network-monitor.sh` - Auto-remount on network restore
- `check-connectivity.sh` - Check mount connectivity and cache
- `status.sh` - Show mount status
- `init.sh` - Initialize directory structure
- `sync-vault.sh` - New bidirectional sync approach (just created)

### The Core Problem
**Mount-based approach causes application instability**:
- Apps like Obsidian crash when network drops
- VFS caching doesn't prevent connection-dependent behavior
- Multiple "emergency fix" scripts indicate fundamental instability
- Over-engineered solutions to wrong problem

### The Real Solution Insight
**Local-first with background sync** (like OneDrive/Dropbox):
- Applications always work with local files in home directory
- Background process handles bidirectional sync transparently
- Zero application crashes due to network issues
- Simple, predictable behavior - apps don't know files are synced

## Refined Hybrid Approach

### Two-Tier System (Clarified Purpose)
1. **Remote Browse Mounts** (`/media/$USER/`) - for browsing/exploring all remote files when connected
2. **Local Sync Targets** (`~/Documents/`, `~/ObsidianVaults/`) - for files that applications actually use

### Core Philosophy
- **Applications point to local files only** - never to remote mounts
- **Remote mounts are for human browsing** - like plugging in a USB drive to explore
- **Background sync keeps local files current** - transparent to applications
- **No application ever knows files are synced** - they just work with local files

### Benefits of This Approach
- **Obsidian always works**: Points to `~/ObsidianVaults/MyVault/` (always local)
- **Browse everything**: `/media/$USER/onedrive-base/` for exploring when connected
- **Zero crashes**: Apps never touch network-dependent paths
- **Simple workflow**: Edit locally, sync happens in background

## Streamlined Plan

### Phase 1: Clean Up Existing Scripts

#### DELETE (8 scripts solving wrong problems):
- `emergency-fix.sh` - symptom of broken approach
- `force-unmount.sh` - symptom of broken approach  
- `network-monitor.sh` - over-engineering
- `remount-all.sh` - symptom of broken approach
- `check-connectivity.sh` - unnecessary complexity
- `sync-vault.sh` - replace with unified solution

#### KEEP & ADAPT (3 scripts):
- `automount.sh` - keep for full remote mounting
- `status.sh` - adapt to show both mounts and sync status
- `init.sh` - adapt for new hybrid setup

#### SIMPLIFY MOUNT SCRIPTS:
- `mount-remote.sh` - simplify VFS settings, remove over-engineering
- `unmount-all.sh` - keep simple version

### Phase 2: Create Unified Sync Solution

#### Single New Script: `ordo-sync.sh`
```bash
ordo-sync.sh [command] [target]

Commands:
- init <local-path> <remote-path>  # Setup new sync target
- sync [target]                    # One-time sync (all if no target)  
- daemon [interval]                # Background sync daemon
- status                          # Show sync status
- conflicts                       # Show/resolve conflicts
```

### Phase 3: Configuration Simplification

#### New Config: `sync-targets.conf`
```
# Format: local_path|remote_path|sync_frequency_seconds
/home/user/Documents/ObsidianVaults/MyVault|onedrive-f6388:Documents/ObsidianVaults/MyVault|300
/home/user/Documents/ImportantFile.txt|onedrive-f6388:Documents/ImportantFile.txt|60
```

#### Keep Existing: `remotes.conf` 
```
# For full remote mounting (unchanged)
onedrive-f6388
g-drive-f6388
```

## Technical Architecture

### Core Principles
- **Minimal dependencies**: Just rclone + standard Unix tools
- **Local-first**: Critical files always available locally
- **Background sync**: Transparent to applications
- **Simple conflict resolution**: Timestamp-based with backups
- **Zero maintenance**: Set and forget

### Directory Structure
```
# Remote Browse Mounts (internet required, for exploration)
/media/$USER/
├── onedrive-base/                # Browse all OneDrive files (when connected)
└── gdrive-base/                  # Browse all Google Drive files (when connected)

# Local Sync Targets (always available, for applications)
~/ObsidianVaults/
└── MyVault/                      # Obsidian points here, syncs with remote
~/Documents/
├── ImportantProject/             # Local folder, syncs with remote
└── CriticalFile.txt             # Local file, syncs with remote
```

### Key Distinction
- **`/media/$USER/`**: Remote mounts for browsing (like USB drives)
- **`~/` directories**: Local files that applications use (with background sync)

### Mount Location Benefits (Following FHS Standards)
- **Dolphin integration**: Shows in "Remote" section automatically
- **System recognition**: Treated as proper removable media
- **Desktop notifications**: Mount/unmount notifications  
- **Consistent UX**: Same behavior as USB drives, network shares
- **Proper permissions**: User-owned, system-recognized

### Local Sync Behavior (The Core Innovation)
- **Transparent to apps**: Applications only see local files
- **Background daemon**: Syncs every N seconds when connected
- **Conflict resolution**: Create `.conflict` files for manual resolution
- **Offline resilience**: Apps work completely offline
- **Smart sync**: Only sync when files actually changed (checksums)
- **Bidirectional**: Local changes sync to remote, remote changes sync to local

### Remote Mount Behavior (For Browsing Only)
- **Startup**: Auto-mount configured remotes to `/media/$USER/`
- **Simple mounting**: Basic rclone mount, no complex VFS tuning
- **Connection-dependent**: Only works when internet available
- **Browse-only**: For exploring files, copying to local sync targets
- **No app dependencies**: Applications never point to these paths

## Implementation Details

### ordo-sync.sh Core Functions
1. **init_target()** - Setup local directory, initial sync from remote
2. **sync_target()** - Bidirectional sync with conflict detection
3. **daemon_mode()** - Background sync loop
4. **show_status()** - Display sync state and conflicts
5. **resolve_conflicts()** - Helper for conflict resolution

### Key Features
- **Smart detection**: Only sync when files actually changed
- **Atomic operations**: Use temp files, then move to prevent corruption
- **Clear logging**: Single log file with timestamps
- **Status reporting**: Easy to see what's syncing, what's conflicted
- **Error handling**: Graceful failures, clear error messages

### Conflict Resolution Strategy
1. **Detect conflicts**: Compare timestamps and checksums
2. **Create backups**: Save both versions with timestamps
3. **User choice**: Let user decide which version to keep
4. **Simple commands**: Easy conflict resolution workflow

## Expected Outcomes

### Before (Current State)
- Obsidian crashes when network drops
- Multiple emergency fix scripts needed
- Complex VFS tuning required
- Unpredictable behavior
- High maintenance overhead
- Apps pointing to network-dependent paths

### After (Streamlined)
- **Obsidian never crashes**: Points to `~/ObsidianVaults/MyVault/` (always local)
- **One sync daemon**: Background process handles all sync targets
- **Simple browsing**: `/media/$USER/onedrive-base/` for exploring files
- **Predictable behavior**: Apps work offline, sync happens transparently
- **Zero maintenance**: Set up once, works forever
- **Clear separation**: Browse remotely, work locally

## File Count Reduction
- **From**: 11 scripts solving wrong problems
- **To**: 5 scripts solving right problems
  - `ordo-sync.sh` (new unified sync)
  - `automount.sh` (simplified remote mounting)
  - `status.sh` (adapted for hybrid status)
  - `init.sh` (adapted for hybrid setup)
  - `unmount-all.sh` (simplified)

## Success Criteria
1. **Obsidian works offline**: Vault at `~/ObsidianVaults/MyVault/` always accessible
2. **Background sync**: Changes sync automatically when connected
3. **Browse all files**: `/media/$USER/onedrive-base/` for exploring when connected
4. **Zero crashes**: Network issues never affect applications
5. **Simple maintenance**: One daemon, clear status, easy conflicts
6. **Minimal dependencies**: Just rclone + Unix tools
7. **Clear workflow**: Edit locally, browse remotely, sync transparently

## Next Steps
1. Review and approve this plan
2. Implement `ordo-sync.sh` with core functionality
3. Adapt existing scripts for hybrid approach
4. Test with Obsidian vault sync
5. Add daemon mode for background sync
6. Clean up old scripts

---

**Motto**: Minimal dependencies. Just rclone + standard Unix tools. Local files that sync in background. Zero application interference.
## Key
 Insights from Friend's Feedback

### FHS Compliance & KDE Integration
- **Use `/media/$USER/`** for remote mounts (not `~/mounts/`)
- **Follows Filesystem Hierarchy Standard** for removable media
- **KDE Dolphin integration**: Shows in "Remote" section automatically
- **System-wide compatibility**: Consistent with USB drives, network shares

### Clear Separation of Concerns
- **Remote mounts**: For browsing/exploring (connection-dependent)
- **Local sync targets**: For applications (always available)
- **Never mix the two**: Apps point to local, humans browse remote

### The OneDrive Model
Applications like Obsidian should point to:
- `~/ObsidianVaults/MyVault/` (local, always available)

NOT to:
- `/media/$USER/onedrive-base/Documents/ObsidianVaults/MyVault/` (remote, connection-dependent)

The background sync daemon ensures the local copy stays current with the remote.

## Implementation Priority

### Phase 1: Core Sync Functionality
1. Create `ordo-sync.sh` with local sync targets
2. Test with Obsidian vault sync
3. Implement background daemon mode

### Phase 2: Proper Remote Mounting  
1. Update mount scripts to use `/media/$USER/`
2. Simplify mount logic (remove complex VFS tuning)
3. Focus on browse-only functionality

### Phase 3: Integration & Cleanup
1. Adapt status script for hybrid approach
2. Clean up old emergency fix scripts
3. Document clear usage patterns