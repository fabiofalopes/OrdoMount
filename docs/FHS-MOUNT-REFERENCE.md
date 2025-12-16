# Linux Remote Filesystem Mounting: Optimal Locations for KDE/Dolphin Integration

## Executive Summary

For optimal integration with KDE Dolphin's remote connections tab and seamless system-wide compatibility, remote filesystems should be mounted according to the Filesystem Hierarchy Standard (FHS) guidelines, with specific considerations for KDE's architecture.

## Understanding KDE's Remote Connection Architecture

### KDE's Dual Approach to Remote Access

KDE uses two primary methods for handling remote connections:

1. **KIO Slaves** - KDE's native virtual filesystem protocol
2. **Traditional FUSE mounting** - Standard Linux filesystem mounting

When you see remote connections appearing in Dolphin's "Remote" tab without explicit configuration, this is KDE's KIO system at work. KDE uses its own file access lib called KIO. KDE apps all use KIO, so when you open something from Dolphin into another KDE app, it opens just fine (you will notice the smb:// URL is passed as-is to the app, not a mountpoint).

### The Integration Challenge

The issue you're experiencing occurs because you're using traditional filesystem mounting (creating folders in ~/mounts) while KDE expects to handle remote connections through its KIO system. This creates a disconnect between the system-level mount and KDE's remote connection management.

## Optimal Mount Point Locations

### 1. `/media/` - The FHS Standard for User Mounts

**Best Choice for Most Users**

This directory contains subdirectories which are used as mount points for removable media such as floppy disks, cdroms and zip disks. FHS states that /media is for users and /mnt is for admins.

**Structure:**
```
/media/
├── username/
│   ├── onedrive-personal/
│   ├── onedrive-work/
│   ├── google-drive/
│   └── ssh-server/
```

**Advantages:**
- Follows FHS standards
- System-wide visibility
- Better integration with system tools
- Can be included by updatedb for locate functionality

### 2. `/run/media/username/` - Modern Distribution Standard

**Current Default on Many Distributions**

In Fedora however it is /run/media/user, and this is becoming the standard for automated mounting systems.

**Advantages:**
- Used by modern mount managers
- Automatic cleanup on reboot
- Better isolation between users

**Disadvantages:**
- /run can't be reasonably included by updatedb
- Some applications may have access issues

### 3. `/mnt/` - Administrative Temporary Mounts

**Not Recommended for Permanent Remote Mounts**

This directory is provided so that the system administrator may temporarily mount a filesystem as needed. The content of this directory is a local issue and should not affect the manner in which any program is run.

### 4. `~/mounts/` - Home Directory Mounts

**Your Current Approach - Suboptimal**

While functional, this approach has several drawbacks:
- Poor system integration
- Limited visibility to other applications
- Inconsistent with FHS standards
- May not integrate well with KDE's device management

## Recommended Implementation Strategy

### Option 1: Use KioFuse (Recommended)

KioFuse bridges the gap between KDE's KIO system and traditional filesystem access. KioFuse allows you to mount remote directories into the root hierarchy of your local file system, thereby exposing KDE's advanced access capabilities (SSH, SAMBA/Windows, FTP, TAR/GZip/BZip2, WebDav, etc) to POSIX-compliant applications.

**Setup Process:**
1. Install kio-fuse package
2. Enable kio-fuse service
3. Access remote connections through Dolphin normally
4. KioFuse automatically exposes them at `/run/user/$(id -u)/kio-fuse/`

### Option 2: Manual Mounting in /media

**For Traditional FUSE/SSHFS Mounts:**

1. Create mount points:
   ```bash
   sudo mkdir -p /media/$USER/onedrive-personal
   sudo chown $USER:$USER /media/$USER/onedrive-personal
   ```

2. Mount with proper options:
   ```bash
   # For SSHFS
   sshfs user@server:/path /media/$USER/server-name -o uid=$(id -u),gid=$(id -g)
   
   # For OneDrive (using rclone)
   rclone mount onedrive-remote: /media/$USER/onedrive-personal --daemon --vfs-cache-mode writes
   ```

3. Add to fstab for persistence:
   ```bash
   # Add appropriate fstab entries for automatic mounting
   ```

## Integration with Dolphin's Remote Tab

### Understanding the Remote Tab Behavior

Network folders show up in a special location of Konqueror and Dolphin called a virtual folder. This virtual folder is accessed by typing remote:/ in the location bar.

The remote tab typically shows:
- KIO-based connections (sftp://, smb://, ftp://)
- Mounted network filesystems detected by the system
- Bookmarked remote locations

### Making Traditional Mounts Appear Correctly

To ensure your manually mounted remote filesystems integrate properly:

1. **Use standard mount points** (`/media/` or `/run/media/`)
2. **Ensure proper permissions** (mounted with user ownership)
3. **Use appropriate filesystem types** that KDE recognizes
4. **Consider using .desktop files** to create custom entries

## Troubleshooting Common Issues

### Mount Points Not Appearing in Dolphin

1. Check if the filesystem is properly mounted with correct permissions
2. Verify KDE can access the mount point
3. Restart Dolphin or the Plasma session
4. Check if solid-device-manager recognizes the mount

### Performance Issues

- KIO slaves may be slower for large file operations
- Traditional mounts offer better performance for intensive I/O
- Consider the trade-off between integration and performance

## Final Implementation Recommendations

### For Your Specific Use Case

Based on your requirements for both general remote access and local cached versions:

**Recommended Directory Structure:**
```
/media/your-username/
├── onedrive-base/           # Live remote connection (internet required)
├── onedrive-local/          # Local cached/synchronized copy
├── googledrive-base/        # Live remote connection (internet required)  
├── googledrive-local/       # Local cached/synchronized copy
├── ssh-servers/
│   ├── server1/             # SSH mounts to various servers
│   └── server2/
└── temp-mounts/             # For temporary remote connections
```

**Implementation Script:**
```bash
#!/bin/bash
# Setup script for dual remote/local mount strategy

USER_MEDIA="/media/$USER"

# Create directory structure
sudo mkdir -p "$USER_MEDIA"/{onedrive-{base,local},googledrive-{base,local},ssh-servers,temp-mounts}
sudo chown -R $USER:$USER "$USER_MEDIA"

# Mount remote bases (internet-dependent)
rclone mount onedrive: "$USER_MEDIA/onedrive-base" \
    --uid $(id -u) --gid $(id -g) --allow-other --daemon \
    --vfs-cache-mode writes --dir-cache-time 5m

rclone mount gdrive: "$USER_MEDIA/googledrive-base" \
    --uid $(id -u) --gid $(id -g) --allow-other --daemon \
    --vfs-cache-mode writes --dir-cache-time 5m

# Setup bidirectional sync for local copies
rclone bisync onedrive: "$USER_MEDIA/onedrive-local" --create-empty-src-dirs &
rclone bisync gdrive: "$USER_MEDIA/googledrive-local" --create-empty-src-dirs &

echo "Mount points created in $USER_MEDIA"
echo "Remote bases: Always require internet connection"
echo "Local copies: Available offline after initial sync"
```

### Best Practices Summary

1. **For maximum system compatibility:** Use `/media/$(whoami)/` structure
2. **For user permissions:** Always mount with `--uid $(id -u) --gid $(id -g)` options
3. **For KDE integration:** Consider KioFuse for advanced KDE features
4. **For performance:** Use traditional FUSE mounts in `/media/` for intensive operations
5. **For dual access:** Implement both remote and local cached versions
6. **For persistence:** Use systemd user services instead of fstab for user mounts
7. **Avoid home directory mounts** for system-wide accessibility and integration

### Security Considerations

- **Mount points in `/media/$USER/` are visible system-wide but only accessible by your user**
- **Use `allow_other` FUSE option carefully - it allows other users to see the mount point**
- **Remote credentials are stored in rclone/SSH configuration files - ensure proper permissions**
- **Consider using keyring integration for credential management**

### Migration from `~/mounts/` to `/media/$USER/`

**Safe Migration Steps:**
```bash
# 1. Unmount existing mounts
fusermount -u ~/mounts/onedrive

# 2. Create new structure in /media
sudo mkdir -p /media/$USER/onedrive-base
sudo chown $USER:$USER /media/$USER/onedrive-base

# 3. Update mount commands to use new location
rclone mount onedrive: /media/$USER/onedrive-base [options]

# 4. Update any scripts/bookmarks pointing to old locations

# 5. Remove old mount directory (after verifying everything works)
rmdir ~/mounts/onedrive
```

This comprehensive approach provides you with the flexibility of both always-available remote access (when internet is available) and local cached copies for offline work, while following Linux filesystem standards and ensuring optimal integration with KDE and other desktop environments.