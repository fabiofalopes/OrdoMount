# Ordo Sync – State Report (2025-09-05)

## Summary
- Goal: OneDrive-like responsiveness for ~/Documents (and Obsidian vaults) across Linux and macOS, with bidirectional safety.
- Current engine: rclone bisync orchestrated by `ordo/scripts/ordo-sync.sh`.
- Today’s upgrades:
  - Added local file-change watcher (inotify) to trigger near-immediate sync on local edits/creates/deletes.
  - Added guarded sync runner to prevent overlap and flapping.
  - Added periodic remote poller so remote-originating changes (e.g., Mac → OneDrive) get pulled down without manual action.

Result: Local → remote propagation is now seconds after save; remote → local is bounded by a configurable poll interval (default 300s; can set to 60–120s for snappier pulls).

## What’s happening under the hood
- Local changes
  - `inotifywait` watches configured local roots (e.g., `/home/fabio/Documents`).
  - On events (create, delete, modify, move, close_write, attrib), we debounce ~2s then run a guarded `sync_all()` (rclone bisync per target).
  - Guard uses a lock to prevent concurrent bisync runs.
- Remote changes
  - There’s no native “push” from OneDrive into your local filesystem copy unless you run a full sync client.
  - We added a lightweight poller: every `ORDO_REMOTE_POLL_INTERVAL` seconds, run a guarded `sync_all()` to fetch remote changes.
  - This converts remote → local latency from “whenever you manually run sync” to a bounded interval.
- Safety and resiliency already in place
  - First-run and recovery `--resync` handling and a `.rclone-bisync-state` marker.
  - Stale rclone bisync lock detection and cleanup.
  - Retries and resilient rclone flags; optional wrapper timeout (disabled by default).
  - Verify mode that skips if a bisync is active.

## Observations from the session
- The perceived “hangs” previously were the long first `--resync` computing listings; it completed and subsequent runs are quick.
- With the watcher running, a local file addition synced to OneDrive and appeared on Mac shortly after.
- Deletion you performed on Linux didn’t reflect immediately in the browser earlier because the daemon wasn’t running at that moment (or remote polling hadn’t fired yet). With the new watcher + poller, local deletes trigger a sync quickly; remote-origin deletes arrive within the poll window.

## Latency expectations
- Local → remote: typically 2–10 seconds after the last write (debounce + bisync runtime).
- Remote → local: `ORDO_REMOTE_POLL_INTERVAL` (default 300s). Recommend 60–120s for active work hours.

## Tunables (env vars)
- ORDO_REMOTE_POLL_INTERVAL: seconds between remote polls in daemon watch mode (default 300). Set 60–120 for snappier pulls.
- ORDO_BISYNC_TIMEOUT_SEC: external timeout for bisync (0 or unset = no timeout). Keep 0 during large initial syncs.
- ORDO_FORCE_RESYNC=1: forces next run to use `--resync` (use only for recovery).
- ORDO_USE_EXCLUDES=0: disables exclusions if you want a “sweep” run.

## Operational guidance
- Start the daemon (watch mode with remote polling): it will print “Watching directories” and “Remote polling enabled …”. Leave it running.
- Do not run multiple bisyncs in parallel; the wrapper prevents overlaps.
- Use `./scripts/ordo-sync.sh verify` to dry-run health when idle.

## Recommendations / next steps
1) Make it persistent
- Run as a systemd user service so it auto-starts on login and restarts on failure (see `ordo/systemd/ordo-sync.service`).
- Set `Environment=ORDO_REMOTE_POLL_INTERVAL=60` for faster remote pulls during work hours.

2) Fine-tune responsiveness vs. load
- Use 60–120s remote poll interval when actively editing; increase to 300–600s otherwise.
- Keep excludes on to reduce noise; maintain the filter list as needed.

3) Health checks
- Daily `verify` (dry-run) with logs; alert if “drift detected” or if `.path{1,2}.lst` go missing.

4) Edge case care
- Avoid interrupting `--resync` runs; that’s when listings are rebuilt.
- If bisync refuses due to missing state, set `ORDO_FORCE_RESYNC=1` for one recovery run.

## Success criteria
- Local edits/deletes appear on OneDrive within ~seconds.
- Remote edits/deletes appear locally within 1–2 minutes (configurable).
- No overlap/locking issues; no silent exits; conflict suffixes recorded if needed.

## Appendix: Commands (optional)
- Manual one-off sync: `./scripts/ordo-sync.sh sync`
- Verify (dry-run): `./scripts/ordo-sync.sh verify`
- Start daemon (watch mode): `./scripts/ordo-sync.sh daemon`

---
Maintainer notes: If latency is still too high, we can further shorten the poll interval, or explore leveraging backend delta APIs more aggressively when supported by rclone’s OneDrive backend. For now, the watch+poll model provides reliable, bounded propagation without needing a full-blown sync client.
