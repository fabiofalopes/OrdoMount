# ⚠️ ARCHIVED: Ordo Requirements (legacy mount/VFS concept)

This document captures the initial mount-first vision (~/mounts with VFS caching). It has been superseded by the local-first sync architecture.

See current docs:
- `docs/ANALYSIS-AND-STREAMLINED-PLAN.md`
- `docs/IMPLEMENTATION-SUMMARY.md`
- `ordo/README.md`

# Ordo: Simple rclone Automation Scripts

## What We Actually Need

After years of overcomplicating this, here's what we really want: **simple scripts that automate rclone workflows**. No bloated UI, no complex architecture - just smart automation around rclone's existing functionality.

## The Reality Check

- rclone already does everything we need perfectly
- The Python GUI was cute but ultimately pointless - just a button to run rclone commands
- We don't need 30 different scripts or complex wrappers
- We need automation for the repetitive parts: mounting, unmounting, startup, and handling auth issues

## Core Use Case

**Primary Goal**: Seamlessly access cloud files as if they were local, with automatic mounting and intelligent caching.

**Target Providers**: 
- Google Drive (multiple accounts)
- OneDrive (multiple accounts) 
- ProtonDrive

**Key Workflow**:
1. System starts up
2. All configured remotes automatically mount to `~/mounts/[remote-name]`
3. Applications can directly access cloud files through file system
4. Intelligent caching for frequently accessed files
5. Graceful handling of auth issues (especially Google Drive)

## What We're Building

A collection of focused scripts that handle:

### 1. Startup Automation (`ordo-startup.sh`)
- Auto-mount all configured remotes on system boot
- Create mount directories if they don't exist
- Log all operations with timestamps
- Handle mount failures gracefully

### 2. Connection Management (`ordo-connect.sh`)
- Add new remote connections (interactive)
- Handle OAuth flows for different providers
- Validate and test connections
- Store connection configs

### 3. Mount Management (`ordo-mount.sh` / `ordo-unmount.sh`)
- Smart mounting with VFS caching enabled
- Clean unmounting with cache preservation
- Handle mount point creation and cleanup

### 4. Status and Maintenance (`ordo-status.sh`)
- Check what's mounted/unmounted
- Detect auth issues (especially Google Drive re-auth needs)
- Show cache status and usage
- Provide quick reconnect options

## Key Insights from rclone Analysis

**rclone VFS Cache is the Solution**:
- `--vfs-cache-mode full` provides exactly what we need for Obsidian and similar apps
- **On-demand caching**: Files cached automatically as you access them
- **Sparse file support**: Only downloads parts of files you actually read
- **LRU eviction**: Automatically removes least recently used files when cache fills
- **Usage-based**: No need to explicitly mark files for caching - it adapts to your patterns
- Offline access to cached files without manual configuration

**Two Cache Systems Available**:
1. **VFS Cache** (what we want): Built into mount, file-level caching
2. **Cache Backend**: Separate backend wrapper (overkill for our needs)

**Simplified Architecture**:
- One smart mount script using VFS caching
- No separate cache management needed
- Focus on mount/unmount automation and status monitoring

**How This Compares to Native Cloud Clients**:

| Feature | OneDrive Native | rclone VFS | Advantage |
|---------|----------------|------------|-----------|
| **Caching Strategy** | Selective sync + on-demand | Pure on-demand | rclone: More efficient disk usage |
| **Explicit Control** | Mark folders "Always available" | Automatic based on usage | rclone: Zero configuration needed |
| **Cache Management** | Manual selection | LRU algorithm | rclone: Adapts to your patterns |
| **Multiple Accounts** | Limited support | Unlimited | rclone: Better for power users |
| **Cross-Platform** | Platform-specific clients | Universal | rclone: Works everywhere |

## Technical Approach

**Keep It Simple**:
- Pure bash scripts leveraging rclone commands
- Minimal dependencies (just rclone + standard Unix tools)
- Single git repository for easy management and updates
- Clear logging to `~/projects/ordo/logs/`
- Configuration in `~/projects/ordo/config/`

**Mount Strategy**:
- Standard location: `~/mounts/[remote-name]`
- Use rclone mount with `--vfs-cache-mode full` for intelligent caching
- Enable `--daemon` and `--allow-non-empty` for seamless operation
- Cache location: `~/projects/ordo/cache/` (git-ignored)
- Leverage rclone's built-in VFS caching (no custom cache management needed)

**Authentication Handling**:
- Let rclone handle OAuth flows (it's already great at this)
- Detect when re-auth is needed
- Provide clear instructions/automation for re-auth

**Example Mount Command**:
```bash
rclone mount onedrive: ~/mounts/onedrive \
  --vfs-cache-mode full \
  --vfs-cache-max-size 10G \
  --vfs-cache-max-age 24h \
  --cache-dir ~/projects/ordo/cache \
  --daemon \
  --allow-non-empty \
  --log-file ~/projects/ordo/logs/mount.log
```

**Cache Behavior**:
- Files you use regularly (like Obsidian vault) stay cached automatically
- Cache size limited to 10G, oldest unused files evicted when full
- Files not accessed for 24h are automatically removed
- No manual "pin" or "always available" configuration needed

**Key VFS Flags We'll Use**:
- `--vfs-cache-mode full`: Cache both reads and writes for maximum compatibility
- `--vfs-cache-max-size 10G`: Prevent cache from filling disk
- `--vfs-cache-max-age 24h`: Remove files not accessed for 24 hours
- `--vfs-cache-poll-interval 1m`: Check for stale files every minute
- `--cache-dir`: Centralized cache location for all mounts

## Key Requirements

1. **Zero Manual Intervention**: Once configured, everything should "just work"
2. **Multiple Accounts**: Support multiple Google Drive, OneDrive accounts
3. **Startup Integration**: Auto-mount on system boot
4. **Intelligent Caching**: Cache frequently accessed files locally
5. **Robust Logging**: Clear logs for troubleshooting
6. **Graceful Failures**: Handle network issues, auth problems elegantly
7. **Minimal Overhead**: Lightweight, fast, no bloat

## File Structure
```
~/projects/ordo/          # Git repository
├── scripts/
│   ├── ordo-startup.sh   # Auto-mount on boot
│   ├── ordo-connect.sh   # Add/manage connections  
│   ├── ordo-mount.sh     # Smart mounting with VFS cache
│   ├── ordo-unmount.sh   # Clean unmounting
│   └── ordo-status.sh    # Status and maintenance
├── config/
│   └── mounts.conf       # Mount configurations
├── logs/                 # Git-ignored
│   ├── startup.log       # Startup operations
│   ├── mount.log         # Mount/unmount operations
│   └── auth.log          # Authentication issues
├── cache/                # Git-ignored VFS cache
└── README.md
```

## Success Criteria

- Boot machine → all cloud drives available in file manager
- Open app that needs cloud file → it just works
- Network issues → graceful degradation with cached files
- Auth expires → clear notification and easy re-auth
- Multiple accounts → each mounted to separate folders
- Zero daily maintenance required

This is about making cloud storage as seamless as local storage, with the minimum viable automation layer on top of rclone's excellent foundation.