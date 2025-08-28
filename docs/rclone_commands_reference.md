# rclone Commands Used in ordo.sh

This document lists all the rclone commands utilized in the `ordo.sh` script for managing remote drive operations.

## Command Summary

### 1. `rclone listremotes`
**Purpose**: Lists all configured remote storage connections  
**Usage in script**: Used in the `get_drives()` function to retrieve available drives  
**Output format**: Each remote name followed by a colon (e.g., `GoogleDrive:`, `OneDrive:`)  
**Script context**:
```bash
while read -r line; do
    drives+=("${line%:}")
done < <(rclone listremotes)
```

### 2. `rclone mount`
**Purpose**: Mounts a remote storage as a local filesystem  
**Usage in script**: Used in the `mount_drive()` function to mount selected drives  
**Full command**: `rclone mount "$DRIVE_NAME_WITH_COLON" "$MOUNT_PATH" --allow-non-empty --daemon`  
**Parameters used**:
- `--allow-non-empty`: Allows mounting to non-empty directories
- `--daemon`: Runs the mount process in the background

**Script context**:
```bash
rclone mount "$DRIVE_NAME_WITH_COLON" "$MOUNT_PATH" --allow-non-empty --daemon
```

## Command Flow

1. **Discovery**: `rclone listremotes` discovers all configured remote drives
2. **Mounting**: `rclone mount` with daemon mode mounts the selected drive to a local path
3. **Unmounting**: Uses system `fusermount -uz` command (not rclone) to unmount drives

## Mount Path Convention

The script follows this pattern for mount paths:
```
/home/$USER/mounts/$DRIVE_NAME
```

Where:
- `$USER` is the current system user
- `$DRIVE_NAME` is the remote name without the trailing colon

## Example Commands for OpenDrive Case

Based on a configured remote named `onedrive-f6388` (actually OpenDrive, not Microsoft OneDrive):

### List your configured remotes
```bash
rclone listremotes
# Output: onedrive-f6388:
```

### Create mount directory
```bash
mkdir -p ~/mounts/onedrive-f6388
```

### Mount OpenDrive
```bash
rclone mount onedrive-f6388: ~/mounts/onedrive-f6388 --allow-non-empty --daemon
```

### Check if mounted
```bash
mountpoint ~/mounts/onedrive-f6388
# Output: /home/username/mounts/onedrive-f6388 is a mountpoint (if successful)
```

### Unmount OpenDrive
```bash
fusermount -uz ~/mounts/onedrive-f6388
```

### Alternative unmount (if fusermount fails)
```bash
rclone umount ~/mounts/onedrive-f6388
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