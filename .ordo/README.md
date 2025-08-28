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
- `status.sh` - Check mount status and health

## Requirements

- rclone installed and configured with your cloud providers
- Existing rclone remotes configured (use `rclone config`)

## Mount Location

All remotes are mounted to: `~/mounts/[remote-name]/`

## Cache Configuration

- Location: `~/.ordo/cache/`
- Max size: 10GB (configurable)
- Max age: 24 hours
- Mode: Full VFS caching for maximum compatibility