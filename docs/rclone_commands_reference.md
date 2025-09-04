# ⚠️ ARCHIVED: rclone mount reference (legacy examples)

This page contains legacy examples using `~/mounts`. Ordo now mounts for browsing under `/media/$USER/<remote>/` and uses local-first sync for apps. Prefer using `./ordo/scripts/automount.sh` and `./ordo/scripts/mount-remote.sh`.

# rclone Commands Used in Ordo

## Command Summary

### 1. `rclone listremotes`
**Purpose**: Lists all configured remote storage connections  
**Usage**: Discover available remotes for mounting/browsing and configuration  
**Output format**: Each remote name followed by a colon (e.g., `GoogleDrive:`, `OneDrive:`)  
**Script context**:
```bash
while read -r line; do
    drives+=("${line%:}")
done < <(rclone listremotes)
```

### 2. `rclone mount`
**Purpose**: Mounts a remote for browsing (not for apps)  
**Recommended**: Use Ordo’s scripts which set safe options and mount at `/media/$USER/<remote>/`.

Script wrapper used by Ordo:
```bash
./ordo/scripts/mount-remote.sh <remote>
```

## Command Flow

1. **Discovery**: `rclone listremotes` discovers all configured remote drives
2. **Mounting**: `rclone mount` with daemon mode mounts the selected drive to a local path
3. **Unmounting**: Uses system `fusermount -uz` command (not rclone) to unmount drives

## Mount Path Convention (current)

```
/media/$USER/<remote>
```

## Example Commands for OpenDrive Case

Based on a configured remote named `onedrive-f6388` (actually OpenDrive, not Microsoft OneDrive):

### List your configured remotes
```bash
rclone listremotes
# Output: onedrive-f6388:
```

### Mount a remote (recommended)
```bash
./ordo/scripts/mount-remote.sh onedrive-f6388
# Mount point: /media/$USER/onedrive-f6388
```

### Check if mounted
```bash
mountpoint /media/$USER/onedrive-f6388
```

### Unmount
```bash
fusermount -uz /media/$USER/onedrive-f6388
# or
rclone umount /media/$USER/onedrive-f6388
```

## Troubleshooting

### OpenDrive IP Blacklist Error
If you get this error:
```
CRITICAL: Failed to create file system for "onedrive-f6388:": failed to create session: 
Your current IP address (xxx.xxx.xxx.xxx) is blacklisted. Please login at www.opendrive.com/login 
using valid credentials and the IP address will be removed from the blacklist. (Error 403)
```

**Solution**:
1. Go to https://www.opendrive.com/login
2. Log in with your OpenDrive credentials
3. This will remove your IP from the blacklist
4. Try the mount command again

### Test connection before mounting
```bash
rclone lsd onedrive-f6388:
# This will list directories and test if connection works
```

### Reconfigure if authentication fails
```bash
rclone config reconnect onedrive-f6388:
# This will refresh the authentication tokens
```

## Notes

- The script only uses 2 rclone commands total
- Unmounting is handled by the system `fusermount` utility, not rclone
- All rclone operations are performed with the configured remotes (no authentication handling in the script)
- The `--daemon` flag ensures mount operations don't block the terminal
- The `--allow-non-empty` flag prevents errors when mounting to directories that aren't completely empty
- For OneDrive specifically, ensure you've completed the OAuth authentication during `rclone config`