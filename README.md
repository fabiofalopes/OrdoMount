# Ordo

Bash scripts for automated rclone mounting with VFS caching.

## Quick Start

```bash
git clone <repository-url>
cd OrdoMount
./ordo/scripts/init.sh
```

Edit `ordo/config/remotes.conf` and add your rclone remotes:
```
gdrive-personal
onedrive-work
s3-backup
```

Mount all remotes:
```bash
./ordo/scripts/automount.sh
```

Files available at `~/mounts/[remote-name]/`

## Requirements

- rclone installed and configured
- Linux/macOS with bash
- Existing rclone remotes (`rclone config`)

## Scripts

| Script | Purpose |
|--------|---------|
| `init.sh` | Initialize directory structure |
| `automount.sh` | Mount all configured remotes |
| `mount-remote.sh <remote>` | Mount specific remote |
| `unmount-all.sh` | Unmount all rclone mounts |
| `status.sh` | Check mount status |
| `check-connectivity.sh` | Test connectivity |
| `remount-all.sh` | Remount after connectivity issues |

## Features

- Location independent (works from any directory)
- VFS caching (10GB, 24h retention)
- Offline file access for cached content
- Automatic connectivity recovery
- Enhanced buffering (2GB read-ahead)

## Troubleshooting

Mount issues after connectivity loss:
```bash
./ordo/scripts/check-connectivity.sh
./ordo/scripts/remount-all.sh
```

## Documentation

- [Ordo README](ordo/README.md) - Detailed documentation
- [Development Plan](docs/ordo-development-plan.md) - Architecture notes
- [rclone Reference](docs/rclone_commands_reference.md) - Command reference