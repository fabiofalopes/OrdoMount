# Ordo Development Plan

## Project Overview

Create an `ordo` directory in the user's home folder containing simple bash scripts that automate rclone mounting with intelligent VFS caching. Focus on the core functionality: automatic mounting of existing remotes on startup with robust logging and caching.

## Core Architecture

**Location**: `~/ordo/` (directory approach for system-wide availability)
**Target Environment**: Linux/macOS with rclone already installed and configured
**Primary Goal**: Automate mounting of existing rclone remotes with VFS caching

## Directory Structure

```
~/ordo/
├── scripts/
│   ├── automount.sh      # Main script - mount all configured remotes
│   ├── mount-remote.sh   # Mount single remote with VFS caching
│   ├── unmount-all.sh    # Clean unmount of all remotes
│   └── status.sh         # Check mount status and health
├── config/
│   └── remotes.conf      # List of remotes to auto-mount
├── logs/
│   ├── automount.log     # Main operations log
│   └── mount-errors.log  # Error-specific logging
├── cache/                # VFS cache directory
└── README.md             # Simple usage instructions
```

## Development Phases

### Phase 1: Core Infrastructure
**Goal**: Set up the basic directory structure and configuration system

**Tasks**:
1. Create `ordo` directory structure in home folder
2. Implement `remotes.conf` format for listing available remotes
3. Create basic logging infrastructure
4. Write simple README with usage instructions

**Technical Details**:
- `remotes.conf` format: Simple list of rclone remote names (one per line)
- Logging with timestamps and operation status
- Git-ignore cache and logs directories

### Phase 2: Remote Detection and Validation
**Goal**: Automatically discover and validate existing rclone remotes

**Tasks**:
1. Parse `rclone listremotes` output to get available remotes
2. Cross-reference with `remotes.conf` to determine what to mount
3. Validate remote connectivity before attempting mount
4. Create mount directories in `~/mounts/` if they don't exist

**Technical Details**:
- Use `rclone listremotes` to get configured remotes
- Test connectivity with `rclone lsd remote:` before mounting
- Create mount points: `~/mounts/[remote-name]/`
- Log validation results for troubleshooting

### Phase 3: Smart Mounting with VFS Cache
**Goal**: Implement the core mounting functionality with intelligent caching

**Tasks**:
1. Create `mount-remote.sh` for single remote mounting
2. Implement VFS caching with optimal flags
3. Handle mount failures gracefully
4. Add daemon mode for background operation

**Technical Details**:
- Mount command template:
  ```bash
  rclone mount [remote]: ~/mounts/[remote] \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --cache-dir ~/ordo/cache \
    --daemon \
    --allow-non-empty \
    --log-file ~/ordo/logs/mount-[remote].log
  ```
- Check if already mounted before attempting mount
- Verify mount success after operation
- Log all mount operations with timestamps

### Phase 4: Automation Script
**Goal**: Create the main automation script that handles all remotes

**Tasks**:
1. Implement `automount.sh` - the main entry point
2. Loop through configured remotes and mount each
3. Handle partial failures (some remotes mount, others fail)
4. Provide clear status reporting

**Technical Details**:
- Read remotes from `remotes.conf`
- Validate each remote before mounting
- Continue on individual failures, log everything
- Final status report: what mounted successfully, what failed
- Exit codes for scripting integration

### Phase 5: Status and Management
**Goal**: Provide visibility into current state and basic management

**Tasks**:
1. Create `status.sh` for checking current mounts
2. Implement `unmount-all.sh` for clean shutdown
3. Add health checking for mounted remotes
4. Provide cache usage information

**Technical Details**:
- Use `mount | grep rclone` to check active mounts
- Test mounted remotes with simple `ls` operations
- Show cache directory size and usage
- Detect stale mounts and authentication issues

## Key Implementation Details

### Configuration Management
- `remotes.conf`: Simple text file, one remote name per line
- Comments supported with `#` prefix
- Empty lines ignored
- Example:
  ```
  # Work accounts
  onedrive-work
  gdrive-work
  
  # Personal accounts  
  onedrive-personal
  gdrive-personal
  ```

### Error Handling Strategy
- Never fail silently - log everything
- Continue processing other remotes if one fails
- Provide clear error messages for common issues:
  - Remote not configured in rclone
  - Authentication expired
  - Network connectivity issues
  - Mount point already in use

### Logging Approach
- Timestamp all log entries
- Separate logs for different operations
- Rotate logs to prevent disk space issues
- Include rclone command output in logs for debugging

### VFS Cache Configuration
- Default cache size: 10GB (configurable)
- Cache age: 24 hours (configurable)
- Cache location: `~/ordo/cache/`
- LRU eviction for automatic management

## Integration Points

### System Startup
- Provide example systemd service file (Linux)
- Provide example launchd plist (macOS)
- Document manual startup integration

### Existing rclone Configuration
- Leverage existing `~/.config/rclone/rclone.conf`
- No modification of rclone configuration required
- Work with any existing remote types

## Success Metrics

1. **Reliability**: Script successfully mounts 95%+ of configured remotes
2. **Performance**: Mounting process completes within 30 seconds
3. **Usability**: Clear logs make troubleshooting straightforward
4. **Maintenance**: Zero daily intervention required once configured
5. **Compatibility**: Works with Google Drive, OneDrive, ProtonDrive remotes

## Next Steps

1. Start with Phase 1: Create basic directory structure and configuration
2. Implement remote detection and validation (Phase 2)
3. Build core mounting functionality (Phase 3)
4. Create main automation script (Phase 4)
5. Add status and management tools (Phase 5)
6. Test with real remotes and refine based on usage

This plan focuses purely on the core automation functionality you described, avoiding feature creep while ensuring robust, reliable operation of the essential mounting and caching workflow.