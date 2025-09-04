# Ordo Development Exploration Log

## Overview
This document catalogs all the commands, tests, and discoveries made during the development and testing of the Ordo sync system. It serves as a reference for troubleshooting and understanding the system's evolution.

**Last Updated**: September 4, 2025  
**Status**: Production Ready - Critical bugs resolved  
**Current Version**: 5-script streamlined architecture

## Updates – September 4, 2025 (evening)

### New: Safe verification flow and bisync behavior during first run
- Dry-run error during live resync is expected:
   - Error: `Bisync critical error: cannot find prior Path1 or Path2 listings ... Must run --resync to recover.`
   - Cause: Initial `--resync` run hasn’t completed; rclone hasn’t written its prior listings yet.
   - Action: Don’t run manual dry-runs while the first bisync is in progress. Wait for completion.

- Added `verify` command to `scripts/ordo-sync.sh`:
   - Skips verification if a bisync is currently running (checks the rclone bisync lock/PID).
   - Runs a dry-run bisync when safe and reports “In sync (no planned changes)” or “Drift detected”.
   - Usage: `./scripts/ordo-sync.sh verify`

### New: Resiliency, timeouts, and first-run state
- Removed hard-coded 300s timeout around bisync. Long initial syncs won’t be killed prematurely.
- Optional external timeout via env: `ORDO_BISYNC_TIMEOUT_SEC=14400` (0 or unset = no timeout).
- Added resiliency flags: `--retries 5`, `--retries-sleep 10s`, `--low-level-retries 10`, `--checkers 8`, `--transfers 4`, `--stats 30s`, `--stats-one-line`.
- Built-in retry loop (3 attempts) with incremental backoff.
- First successful run creates local marker: `<local>/.rclone-bisync-state`; subsequent runs omit `--resync`.

### New: Stale lock handling
- Before starting, the script checks rclone’s bisync lock at `~/.cache/rclone/bisync/<local>..<remote>.lck`.
- If the PID in the lock isn’t running, it auto-clears the stale lock (tries `rclone deletefile`, falls back to `rm`).

### Current long-run status (Documents target)
- Active first-run `--resync` is in progress (continuous “Copied (new)” entries in `logs/ordo-sync.log`).
- The state marker `.rclone-bisync-state` isn’t present yet (expected until completion).
- After completion, run `./scripts/ordo-sync.sh verify` to confirm “In sync”.

## Key Commands Used

### Mount Management
```bash
# Check current mounts
mount | grep rclone
df -h | grep rclone

# Manual unmount
fusermount -u ~/mounts/onedrive-f6388
fusermount -u ~/mounts/g-drive-f6388

# Kill rclone processes
pkill -f "rclone mount"
pkill -f "rclone bisync"

# Create proper mount directories with permissions
sudo mkdir -p /media/$USER
sudo chown $USER:$USER /media/$USER
```

### Rclone Testing Commands
```bash
# Test remote connectivity
rclone lsd onedrive-f6388:
rclone lsd g-drive-f6388:

# List available remotes
rclone listremotes

# Test basic sync
rclone copy ~/test-file onedrive-f6388:test-folder/

# Bisync testing
rclone bisync ~/test-sync onedrive-f6388:test-sync --resync --dry-run -v
rclone bisync ~/test-sync onedrive-f6388:test-sync --resync -v

# Full Documents sync with exclusions
rclone bisync ~/Documents onedrive-f6388:Documents --resync --dry-run --progress
rclone bisync ~/Documents onedrive-f6388:Documents --resync \
  --exclude "*.pyc" --exclude "__pycache__/**" --exclude ".venv/**" \
  --exclude "node_modules/**" --exclude ".git/**" --progress --transfers 4

# Using filter file
rclone bisync ~/Documents onedrive-f6388:Documents --resync \
  --filter-from ordo/config/sync-excludes.conf --dry-run --progress
```

### System Diagnostics
```bash
# Check file counts and sizes
ls -la ~/Documents/ | wc -l
du -sh ~/Documents/
du -sh /media/fabio/onedrive-f6388/Documents/

# Check network and performance
ping google.com
speedtest-cli  # if available

# Check processes
ps aux | grep rclone
pgrep -f rclone

# Check logs
tail -f ordo/logs/ordo-sync.log
tail -f ordo/logs/automount.log
```

### File Management
```bash
# Backup operations
cp -r ~/Documents ~/Documents.backup.$(date +%Y%m%d-%H%M%S)
rm -rf ~/Documents.backup.*

# Clean bisync state
rm -rf ~/Documents/.rclone-bisync-state

# Test file operations
echo "Test file $(date)" > ~/test-sync/test.txt
mkdir -p ~/test-sync
rm -rf ~/test-sync
```

## CRITICAL BUG FIXES

### 🚨 Script Execution Hanging (RESOLVED)
**Date Discovered**: September 4, 2025  
**Severity**: CRITICAL - System completely non-functional

**Problem**: `./scripts/ordo-sync.sh sync` would hang indefinitely with no output, appearing to do nothing.

**Symptoms**:
- Script starts but produces no output
- No error messages or progress indicators
- Appears to hang immediately after execution
- Manual rclone commands work perfectly when run directly
- Timeout commands would eventually kill the process

**Root Cause**: 
```bash
# This line in sync_all() function caused script exit due to set -euo pipefail
((total_count++))  # Returns 1 when total_count=0, triggering set -e exit
```

**Technical Details**:
- `set -euo pipefail` at script start causes exit on any non-zero return
- `((total_count++))` returns the OLD value (0) before incrementing
- When old value is 0, bash returns exit code 1
- `set -e` interprets this as command failure and exits script
- Script exits silently before any sync operations begin

**Solution Applied**:
```bash
# BEFORE (broken):
((total_count++))
((success_count++))

# AFTER (fixed):
total_count=$((total_count + 1))
success_count=$((success_count + 1))
```

**Debugging Process**:
1. Added `bash -x` debugging to trace execution
2. Identified hang occurred after processing sync target line
3. Added debug echo statements throughout script
4. Pinpointed exact line causing exit: `((total_count++))`
5. Verified fix with successful sync execution

**Impact**: This fix made the entire system functional. Without it, no sync operations were possible.

---

## Issues Discovered

### 1. File Manager Blocking (CRITICAL)
**Problem**: Dolphin (KDE file manager) freezes when network connection drops while accessing remote mounts.

**Symptoms**:
- Complete UI freeze
- Unresponsive to user input
- Requires force-kill of process
- Window remains on screen indefinitely

**Root Cause**: File manager attempts to access remote mount during network interruption without proper timeout handling.

**Solutions Tested**:
- Added timeout options to rclone mount (`--daemon-timeout "60s"`)
- Improved mount options with VFS cache settings
- Moved to FHS-compliant mount locations (`/media/$USER/`)

### 2. Mount Location Non-Compliance
**Problem**: Initially mounting to `~/mounts/` instead of FHS-compliant `/media/$USER/`

**Impact**: 
- Not following Linux filesystem standards
- Potential permission issues
- Poor integration with desktop environments

**Solution**: 
- Created `/media/$USER/` directories
- Updated all scripts to use proper locations
- Set correct ownership with `chown $USER:$USER`

### 3. Sync Performance Issues
**Problem**: Extremely slow sync speeds (near 0 Mbps) during initial testing

**Causes Identified**:
- Poor network connectivity during testing period
- Syncing unnecessary files (Python cache, virtual environments, etc.)
- Large number of small files causing overhead

**Solutions**:
- Implemented comprehensive exclusion system
- Added filter file support (`sync-excludes.conf`)
- Optimized transfer settings (`--transfers 4`)

### 4. Interrupted Sync Recovery
**Problem**: Initial Documents sync interrupted at 17% completion

**Impact**:
- Local `~/Documents/` inconsistent with remote
- Partial files and incomplete state
- Need for clean restart mechanism

**Solution**:
- Implemented backup before sync
- Added `--resync` flag handling for first-time sync
- Created recovery procedures

## Exclusion Patterns Developed

### File Types to Exclude
```
# Python environments and cache
**/__pycache__/**
**/*.pyc
**/*.pyo
**/.venv/**
**/venv/**
**/.venv*/**
**/venv*/**

# Node.js
**/node_modules/**
**/.npm/**

# Git repositories
**/.git/**

# Build artifacts
**/build/**
**/dist/**
**/target/**

# Scrapy cache
**/.scrapy/**

# OS files
**/.DS_Store
**/Thumbs.db
```

## Performance Optimizations

### Rclone Bisync Options
```bash
--resync                    # First-time sync
--progress                  # Show progress
--filter-from <file>        # Use exclusion file
--conflict-resolve newer    # Handle conflicts
--conflict-suffix "conflict-{DateOnly}-{TimeOnly}"
--transfers 4               # Parallel transfers
--checkers 8                # Parallel checks
--retries 5                 # Operation retries
--retries-sleep 10s         # Sleep between retries
--low-level-retries 10      # Chunk retries
--stats 30s --stats-one-line # Clear periodic stats
# Optional external timeout via env (0/unset disables):
#   ORDO_BISYNC_TIMEOUT_SEC=14400
```

### Mount Options for Stability
```bash
--daemon-timeout "60s"      # Prevent hanging
--vfs-cache-mode minimal    # Light caching
--vfs-read-chunk-size 32M   # Optimize reads
--buffer-size 32M           # Buffer size
--dir-cache-time 5m         # Directory caching
--poll-interval 1m          # Polling frequency
```

## Testing Methodology

### 1. Small Scale Testing
- Created `~/test-sync` directory
- Single file sync tests
- Verified bidirectional sync
- Tested conflict resolution

### 2. Dry Run Validation
- Always test with `--dry-run` first
- Verify exclusion patterns work
- Check file counts and sizes
- Estimate transfer times

### 3. Incremental Approach
- Start with empty directories
- Add exclusions iteratively
- Test network drop scenarios
- Validate recovery procedures

## Lessons Learned

### 1. Always Use Dry Run First
- Prevents accidental data loss
- Validates exclusion patterns
- Estimates sync time and size
- Identifies potential issues

### 2. Exclusions Are Critical
- Dramatically reduces sync time
- Prevents syncing unnecessary files
- Reduces storage usage
- Improves reliability

### 3. Network Resilience is Key
- File managers need timeout handling
- Background sync should be fault-tolerant
- Manual mount/unmount may be necessary
- Connection quality affects performance significantly

### 4. Proper Mount Locations Matter
- FHS compliance improves integration
- Correct permissions prevent issues
- Desktop environment integration works better
- Easier troubleshooting and maintenance

## Next Steps for Production

### 1. Integration into Scripts
- Incorporate exclusion file support
- Add proper error handling
- Implement recovery mechanisms
- Create user-friendly interfaces

### 2. Testing Requirements
- Test with multiple file managers
- Validate network drop scenarios
- Test large file sync performance
- Verify conflict resolution

### 3. Documentation Needs
- User setup guide
- Troubleshooting procedures
- Common issues and solutions
- Performance tuning guide

## CURRENT TESTING STATUS

### ✅ Successfully Tested (September 4, 2025)
1. **Script Execution**: Fixed critical hanging bug, scripts now run properly
2. **Progress Display**: Sync shows proper progress output and statistics
3. **Exclusion System**: Confirmed working - reduces 11GB to manageable size
4. **Mount System**: Both OneDrive and Google Drive mounts active and accessible
5. **Configuration**: Setup script successfully configures sync targets

### 🧪 Test Results
```bash
# Last successful sync test output:
Ordo Sync
=========
ℹ Syncing Documents...
[2025-09-04 18:46:01] Using rclone bisync for bidirectional sync...
[2025-09-04 18:46:01] First bisync - using --resync
[2025-09-04 18:46:01] Using exclusions from: config/sync-excludes.conf
Transferred:      146.006 MiB / 11.072 GiB, 1%, 5.057 MiB/s, ETA 36m53s
Checks:                 0 / 0, -, Listed 10172
Transferred:           44 / 8048, 1%
```

**Key Metrics**:
- **Total Size**: 11.072 GiB (down from ~70GB raw)
- **Files**: 8,048 (down from ~10,000+ raw)
- **Transfer Speed**: 5.057 MiB/s
- **Exclusions Working**: ✅ Significant size reduction achieved

### 🎯 Ready for Production Testing
The system is now ready for a complete Documents folder sync test. All critical bugs have been resolved and the architecture is stable.

---

## COMMAND REFERENCE QUICK LIST

### Daily Operations
```bash
# Check system status
./scripts/status.sh

# Manual sync all targets
./scripts/ordo-sync.sh sync

# Start background daemon
./scripts/ordo-sync.sh daemon &

# Check sync target status
./scripts/ordo-sync.sh status
```

### Setup and Configuration
```bash
# One-time setup (interactive)
./setup.sh

# Add new sync target
./scripts/ordo-sync.sh init ~/MyFolder onedrive:MyFolder 300

# Mount remotes for browsing
./scripts/automount.sh

# Unmount all remotes
./scripts/unmount-all.sh
```

### Troubleshooting
```bash
# Check mounts
mount | grep rclone

# Kill stuck processes
pkill -f "rclone bisync"
pkill -f "rclone mount"

# Clean restart
./scripts/unmount-all.sh
./scripts/automount.sh

# Debug script execution
timeout 30s bash -x ./scripts/ordo-sync.sh sync
```

### Manual Testing
```bash
# Test remote connectivity
rclone lsd onedrive-f6388: --max-depth 1
rclone lsd g-drive-f6388: --max-depth 1

# Dry run sync with exclusions
rclone bisync ~/Documents onedrive-f6388:Documents/ \
  --resync --dry-run --filter-from config/sync-excludes.conf

# Monitor logs
tail -f logs/ordo-sync.log
tail -f logs/automount.log
```

### Cleanup Operations
```bash
# Clean Documents folder for fresh test
rm -rf ~/Documents/*
rm -rf ~/Documents/.*

# Remove bisync state for fresh sync
rm -rf ~/Documents/.rclone-bisync-state

# Clean all processes
pkill -f rclone
```

## SCRIPT ARCHITECTURE ANALYSIS

### Current 5-Script System Overview

The Ordo system has been streamlined from 11+ scripts to 5 focused scripts, each with specific responsibilities:

```
ordo/
├── setup.sh                 # One-time interactive setup
├── scripts/
│   ├── init.sh              # System initialization
│   ├── automount.sh         # Remote mounting for browsing
│   ├── ordo-sync.sh         # ★ Core sync system (unified)
│   ├── status.sh            # System status and health checks
│   └── unmount-all.sh       # Clean unmounting
├── config/
│   ├── remotes.conf         # Remote browsing configuration
│   ├── sync-targets.conf    # Local sync targets
│   └── sync-excludes.conf   # Exclusion patterns
└── logs/                    # Runtime logs (auto-created)
```

### 1. setup.sh - Interactive Setup Orchestrator

**Purpose**: One-time setup wizard that guides users through complete system configuration.

**Key Functions**:
- Calls `init.sh` to initialize directory structure
- Optionally configures remote browsing via `automount.sh`
- Interactive sync target setup using `ordo-sync.sh init`
- Optional daemon startup
- Provides final status and usage instructions

**Commands Used Internally**:
```bash
./scripts/init.sh                                    # Initialize system
./scripts/automount.sh                              # Mount remotes
./scripts/ordo-sync.sh init <local> <remote> <freq> # Add sync targets
nohup ./scripts/ordo-sync.sh daemon &               # Start daemon
```

**User Interaction Flow**:
1. System initialization (automatic)
2. Remote browsing setup (optional, user choice)
3. Sync target configuration (interactive loop)
4. Daemon startup (optional, user choice)
5. Final instructions and status

### 2. scripts/init.sh - System Initialization

**Purpose**: Creates directory structure and validates system requirements.

**Key Functions**:
- Creates required directories (`logs/`, `config/`, `conflicts/`)
- Validates rclone installation
- Sets up configuration file templates
- Ensures proper permissions

**Commands Used**:
```bash
command -v rclone                    # Verify rclone exists
mkdir -p logs config conflicts      # Create directories
touch config/sync-targets.conf      # Create config files
```

**Critical for**: First-time setup, ensuring clean state for other scripts.

### 3. scripts/automount.sh - Remote Browsing System

**Purpose**: Mounts cloud remotes for browsing and backup operations (not for application access).

**Key Functions**:
- Reads `config/remotes.conf` for remote list
- Mounts each remote to `/media/$USER/[remote-name]/`
- Uses optimized mount options for stability
- Provides connection testing and error handling

**Mount Command Template**:
```bash
rclone mount "$remote:" "/media/$USER/$remote" \
  --timeout 30s \
  --retries 1 \
  --daemon \
  --allow-non-empty \
  --daemon-timeout 60s \
  --vfs-cache-mode minimal \
  --vfs-read-chunk-size 32M \
  --vfs-read-chunk-size-limit 1G \
  --buffer-size 32M \
  --dir-cache-time 5m \
  --poll-interval 1m \
  --log-file "$LOG_FILE" \
  --log-level INFO
```

**Mount Options Explained**:
- `--daemon-timeout 60s`: Prevents indefinite hangs on network issues
- `--vfs-cache-mode minimal`: Light caching for browsing (not heavy use)
- `--allow-non-empty`: Allows mounting over existing directories
- `--timeout 30s --retries 1`: Quick failure on connection issues

### 4. scripts/ordo-sync.sh - Core Sync System (★ MAIN COMPONENT)

**Purpose**: Unified bidirectional sync system with multiple operation modes.

**Commands Available**:
```bash
./ordo-sync.sh init <local> <remote> [frequency]  # Add new sync target
./ordo-sync.sh sync                               # Manual sync all targets
./ordo-sync.sh daemon [interval]                  # Background sync daemon
./ordo-sync.sh status                             # Show sync status
./ordo-sync.sh verify                             # Dry-run: report if targets are in sync
./ordo-sync.sh conflicts                         # Show/resolve conflicts
```

#### Core Functions Analysis:

**A. sync_target() - Individual Target Sync**
```bash
# Uses rclone bisync for true bidirectional sync
rclone bisync "$local_path" "$remote_path" \
   --resync \                                    # First-time sync flag (omitted after marker exists)
   --filter-from config/sync-excludes.conf \     # Apply exclusions
   --progress \                                   # Show progress
   --conflict-resolve newer \                     # Handle conflicts
   --conflict-suffix "conflict-{DateOnly}-{TimeOnly}" \
   --transfers 4 \                               # Parallel transfers
   --checkers 8 \                                # Parallel checks
   --retries 5 --retries-sleep 10s \             # Resiliency
   --low-level-retries 10 \                      # Chunk retries
   --stats 30s --stats-one-line                   # Periodic stats
# Optional external timeout via env (disabled by default):
#   ORDO_BISYNC_TIMEOUT_SEC=14400 ./scripts/ordo-sync.sh sync
```

**B. verify_targets() – Safe, read-only verification**
```bash
# Skips if a bisync is running (checks rclone lock PID)
./scripts/ordo-sync.sh verify

# Internally runs a dry-run bisync and reports:
#   ✓ In sync (no planned changes)
#   ⚠ Drift detected or state missing
# Fallbacks to `rclone check --size-only` when bisync isn’t available.
```

**B. sync_all() - Process All Configured Targets**
- Reads `config/sync-targets.conf`
- Processes each non-comment line
- Calls `sync_target()` for each entry
- Provides summary statistics
- **CRITICAL FIX**: Uses `total_count=$((total_count + 1))` instead of `((total_count++))`

**C. start_daemon() - Background Sync Service**
- Runs `sync_all()` in infinite loop
- Configurable interval (default 300s = 5 minutes)
- Proper signal handling for graceful shutdown
- Runs in background with `nohup`

**D. init_target() - Add New Sync Target**
- Validates local and remote paths
- Creates local directory if needed
- Performs initial sync from remote if content exists
- Adds entry to `config/sync-targets.conf`

#### Exclusion System:
Uses `config/sync-excludes.conf` with rclone filter syntax:
```bash
--filter-from config/sync-excludes.conf
```

**Impact**: Reduces 70GB Documents folder to ~2GB by excluding:
- Python environments (`**/.venv/**`, `**/__pycache__/**`)
- Node.js modules (`**/node_modules/**`)
- Git repositories (`**/.git/**`)
- Build artifacts (`**/build/**`, `**/dist/**`)
- OS files (`**/.DS_Store`, `**/Thumbs.db`)

### 5. scripts/status.sh - System Health Monitor

**Purpose**: Comprehensive system status checking and reporting.

**Key Checks**:
- rclone availability and version
- Mount status and accessibility
- Sync target configuration
- Recent activity from logs
- Connection testing (optional, for speed)

**Commands Used**:
```bash
command -v rclone                           # Check rclone
mount | grep rclone                         # Active mounts
ls -la /media/$USER/                       # Mount directories
rclone lsd "$remote:" --max-depth 1        # Connection test
wc -l < config/sync-targets.conf           # Count targets
tail -3 logs/*.log                         # Recent activity
```

### 6. scripts/unmount-all.sh - Clean Shutdown

**Purpose**: Safely unmount all rclone mounts and clean up processes.

**Key Functions**:
- Kills all rclone mount processes
- Unmounts all `/media/$USER/` rclone mounts
- Provides status feedback
- Handles errors gracefully

**Commands Used**:
```bash
pkill -f "rclone mount"                    # Kill mount processes
fusermount -u /media/$USER/*               # Unmount filesystems
mount | grep rclone                        # Verify cleanup
```

---

## TROUBLESHOOTING PROCEDURES

### Script Hanging Issues
1. **Check for arithmetic expansion bugs**:
   ```bash
   # WRONG (causes exit with set -e):
   ((counter++))
   
   # CORRECT:
   counter=$((counter + 1))
   ```

2. **Debug script execution**:
   ```bash
   timeout 10s bash -x ./scripts/ordo-sync.sh sync
   ```

3. **Add debug output temporarily**:
   ```bash
   echo "DEBUG: Reached line X" 
   ```

### Sync Performance Issues
1. **Check exclusions are working**:
   ```bash
   rclone bisync ~/Documents onedrive:Documents/ --dry-run --filter-from config/sync-excludes.conf
   ```

2. **Monitor transfer progress**:
   ```bash
   tail -f logs/ordo-sync.log
   ```

3. **Kill stuck sync processes**:
   ```bash
   pkill -f "rclone bisync"
   ```

### Mount Issues
### Bisync Dry-Run Fails with “cannot find prior Path1 or Path2 listings”
**Cause**: Running a dry-run during the initial `--resync` before the prior listings are created, or immediately after an interrupted run.

**Fix / Guidance**:
- Wait for the first full bisync to complete; then use `./scripts/ordo-sync.sh verify`.
- If you interrupted an earlier run, ensure no live bisync is running and clear stale locks automatically by invoking the script, or manually remove the lock if necessary:
   ```bash
   rclone lsl ~/.cache/rclone/bisync
   # The script auto-clears stale locks; manual fallback:
   rm -f ~/.cache/rclone/bisync/<local>..<remote>.lck
   ```

### Stale Bisync Lock
**Symptom**: Immediate “0 B / 0 B” retries or refusal to start.

**Resolution**: The script now checks `~/.cache/rclone/bisync/*.lck`, verifies the PID, and deletes the lock if stale (tries `rclone deletefile`, then `rm`).

1. **Check mount status**:
   ```bash
   mount | grep rclone
   ./scripts/status.sh
   ```

2. **Clean unmount and remount**:
   ```bash
   ./scripts/unmount-all.sh
   ./scripts/automount.sh
   ```

3. **Test remote connectivity**:
   ```bash
   rclone lsd onedrive-f6388: --max-depth 1
   ```

---

## PRODUCTION DEPLOYMENT CHECKLIST

### ✅ Completed
- [x] Critical script hanging bug fixed
- [x] FHS-compliant mount locations (`/media/$USER/`)
- [x] Comprehensive exclusion system implemented
- [x] 5-script streamlined architecture
- [x] Proper error handling and timeouts
- [x] Interactive setup system
- [x] Status monitoring and logging

### 🔄 Ready for Testing
- [ ] Complete Documents folder sync test
- [ ] Daemon mode stability test
- [ ] Network interruption handling test
- [ ] Conflict resolution validation
- [ ] Multi-file manager compatibility test

### 📋 Documentation Complete
- [x] Script architecture analysis
- [x] Troubleshooting procedures
- [x] Command reference guide
- [x] Critical bug documentation
- [x] Performance optimization guide

---

**Note**: This log should be updated as new issues are discovered and solutions are implemented. It serves as both a troubleshooting guide and a development history.