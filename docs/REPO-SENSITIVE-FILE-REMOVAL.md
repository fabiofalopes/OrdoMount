# Repository Sensitive File Removal & Hygiene Guide

Last Updated: 2025-09-12

This document provides a generic process for removing previously committed sensitive artifacts (e.g. password vaults, API key dumps, credentials) and hardening the repository to reduce recurrence. It intentionally avoids incident-specific details.

## Example Temporary Pre-Commit Hook (Optional)

You can (optionally) deploy a short‑lived local pre-commit hook during cleanup or while rolling out better controls. This example blocks ADDED / MODIFIED sensitive patterns but allows DELETIONS so you can purge them.

Create at `.githooks/pre-commit` then run:
```bash
git reset --hard origin/main
chmod +x .githooks/pre-commit
```

Example script (generic — adjust patterns for your context):
```bash
#!/usr/bin/env bash
set -euo pipefail

# Patterns considered sensitive (tune as needed)
SENSITIVE_PATTERNS=("*.kdbx" "*.pem" "*.pfx" "*.p12" "*.env" "*.env.*" "secrets/" "private-keys/" )

blocked=0
while IFS=$'\t' read -r status path || [[ -n "${status:-}" ]]; do
  [[ -z "${path:-}" ]] && continue
  for pat in "${SENSITIVE_PATTERNS[@]}"; do
    if [[ "$path" == $pat || "$path" == *"${pat#*/}"* ]]; then
      # Allow deletions so we can remove leaked files
      if [[ "$status" == D ]]; then
        echo "[hook] Allow delete: $path (matched $pat)" >&2
        continue
      fi
      echo "[hook] BLOCK: $path (matched pattern $pat; status=$status)" >&2
      blocked=1
    fi
  done
done < <(git diff --cached --name-status --no-renames | tr '\r' '\n')

if [[ $blocked -eq 1 ]]; then
  cat <<'EOT'
[hook] Commit blocked: staged changes include sensitive patterns.
To override (not recommended): git commit --no-verify
Either remove those files or move them outside the repository.
EOT
  exit 1
fi
exit 0
```

Notes:
- Prefer migrating to automated secret scanning in CI instead of relying on hooks long-term.
- Keep the pattern list minimal to avoid false positives that frustrate contributors.
```

## 5. Credential / Secret Rotation
Treat any exposed secret as compromised—even if encrypted.
- Rotate API keys, tokens, OAuth secrets.
- Regenerate SSH keys; remove old public keys from systems.
- Change passwords and revoke active sessions where applicable.
- Update CI/CD and infrastructure secret stores.
- Record what was rotated (timestamp, owner).

## 6. Verification
```bash
# Should return nothing if purge succeeded
git rev-list --objects --all | grep -E '(sensitive/dir|secretpattern)' || echo "OK: no matches"
# Log inspection
git log --name-only | grep -E '(sensitive/dir|secretpattern)' || echo "OK: not in commit logs"
```
Optional scanning:
```bash
gitleaks detect --source . || true
trufflehog filesystem --directory . || true
```

## 7. Hardening (Post-Clean)
- Maintain `.gitignore` rules for generated or secret-containing directories.
- Keep secrets **outside** the repository (local secure storage, secret manager, encrypted volume).
- Add CI secret scanning (fail build on new detections).
- Use shorter-lived tokens and periodic rotation policies.
- Document disclosure procedure in `SECURITY.md`.

## 8. Minimal Cheat Sheet
```bash
# 1. Remove from index
git rm -r --cached <path>
# 2. Commit
git commit -m "chore(security): remove sensitive artifacts"
# 3. Rewrite history
git filter-repo --path <path> --invert-paths
# 4. Force push
git push --force --all && git push --force --tags
# 5. Verify
git rev-list --objects --all | grep <path> || echo OK
```

## 9. Pre-Commit Hooks (Optional)
You may temporarily employ a local hook to block patterns during cleanup. After processes mature (ignores + CI scanning), maintaining the hook is optional. If removed, ensure other controls are in place.

## 10. Incident Log Template (Generic)
```
Incident: <type>
Detected: <timestamp>
Artifacts: <paths/globs>
First Commit: <hash>
Actions Timeline:
  - <time> Contained (ignore + removal)
  - <time> History rewritten (tool + options)
  - <time> Force push
  - <time> Rotation complete
Verification: <commands run & results>
Follow-ups: <hardening tasks>
Status: OPEN | MONITOR | CLOSED
```

---

Use this guide for any future removal of sensitive repository contents.
