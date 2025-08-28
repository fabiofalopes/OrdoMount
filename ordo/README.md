# Ordo - Simple rclone Automation

Ordo automates rclone mounting with intelligent VFS caching for seamless cloud storage access.

## Quick Start

1. **Configure your remotes**: Edit `config/remotes.conf` and list your rclone remotes
2. **Run automount**: `./scripts/automount.sh`
3. **Check status**: `./scripts/status.sh`

## Directory Structure

- `scripts/` - Main automation scripts
- `config/` - Configuration files
- `logs/` - Operation logs (git-ignored)
- `cache/` - VFS cache directory (git-ignored)

## Scripts

- `automount.sh` - Mount all configured remotes with VFS caching
- `mount-remote.sh` - Mount a single remote
- `unmount-all.sh` - Clean unmount of all remotes
- `remount-all.sh` - Remount all configured remotes (useful after connectivity issues)
- `status.sh` - Check mount status and health
- `check-connectivity.sh [remote]` - Test connectivity and diagnose offline issues

## Requirements

- rclone installed and configured with your cloud providers
- Existing rclone remotes configured (use `rclone config`)

## Mount Location

All remotes are mounted to: `~/mounts/[remote-name]/`

## Cache Configuration

- Location: `~/ordo/cache/`
- Max size: 10GB (configurable)
- Max age: 24 hours
- Mode: Full VFS caching for maximum compatibility

## Offline Behavior

When internet connectivity is lost:

- **Cached files remain accessible** - Files that were previously accessed are available offline
- **Mount points stay active** - The mount directory remains but uncached files become inaccessible
- **Automatic recovery** - When connectivity returns, access is restored automatically

### Handling Connectivity Issues

If you experience issues after connectivity loss:

1. **Check connectivity**: `./scripts/check-connectivity.sh`
2. **Remount if needed**: `./scripts/remount-all.sh`
3. **Monitor status**: `./scripts/status.sh`

### Enhanced Offline Settings

The mount script includes optimizations for offline usage:
- 2GB read-ahead buffer
- 128MB chunk sizes for efficient caching
- 60-second timeout with 3 retries
- Aggressive local caching for better offline access