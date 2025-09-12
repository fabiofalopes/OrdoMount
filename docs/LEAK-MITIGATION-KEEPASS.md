# KeePass Vault Leak Mitigation (Repo Hygiene + Rotation)

Date: 2025-09-11

This repository accidentally committed a KeePass vault under `ordo/cache/.../KeePassVaultWork/keepass_db_work_passwords.kdbx`. Although KeePass databases are encrypted, we must treat this as a leak: remove it from Git history and rotate affected credentials.

## Immediate steps (do now)

1) Stop further propagation
- Add ignores (done): `ordo/cache/` and `**/*.kdbx` in `.gitignore`.
- Install a pre-commit hook to block future commits (provided at `.githooks/pre-commit`). Enable it:

```bash
# From repo root
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

2) Remove the file from the working tree

```bash
git rm -r --cached ordo/cache
git commit -m "chore(security): remove cache and block .kdbx"
```

3) Rewrite Git history to purge the leaked file

Choose ONE method. `git filter-repo` is easiest; if unavailable, use BFG or filter-branch.

- Option A: git filter-repo (recommended)

```bash
# Install once (Debian/Ubuntu: pipx or pip)
pipx install git-filter-repo || pip install --user git-filter-repo

# Purge the paths from history
git filter-repo --path ordo/cache --path-glob "*.kdbx" --invert-paths
```

- Option B: BFG Repo-Cleaner

```bash
# Download BFG jar and run:
java -jar bfg.jar --delete-folders ordo/cache --delete-files "*.kdbx" --no-blob-protection
# Then:
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

- Option C: git filter-branch (slow, last resort)

```bash
git filter-branch --force --index-filter 'git rm -r --cached --ignore-unmatch ordo/cache *.kdbx' --prune-empty --tag-name-filter cat -- --all
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

4) Force-push rewritten history

```bash
git push --force --all
git push --force --tags
```

Notify collaborators they must re-clone or hard reset:

```bash
# For each local clone
git fetch --all
git reset --hard origin/main
```

5) Invalidate forks and caches
- Open a security notice in the repo describing that history was rewritten and why.
- If public: consider temporarily archiving/privating until rotation completes.
- GitHub will eventually drop cached blobs; rewriting plus force-push removes normal access.

## Credential rotation plan

Even though the .kdbx is encrypted, assume compromise:

- Change the KeePass master password and keyfile (if used). Save as a new vault file name.
- For every credential inside that vault:
  - Regenerate API keys and secrets.
  - Reset account passwords.
  - Revoke refresh tokens and OAuth client secrets.
  - Rotate SSH keys and remove the old public keys from servers/services.
  - Update environment variables and CI/CD secrets (GitHub Actions, etc.).
- Document what was rotated and when.

## Prevent recurrence

- Keep secrets and vaults out of the repo:
  - Store vaults only in your local `~/Documents` or secure storage, never under `ordo/cache` or inside this repo tree.
  - `.gitignore` includes `ordo/cache/` and `**/*.kdbx`.
- Enforce pre-commit checks:

```bash
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

- Optionally add server-side protection:
  - Require branch protection on `main`.
  - Add a CI job to scan for high-risk extensions and fail the build on detection.

## Verification checklist

- [ ] `git log -- ordo/cache` returns no results.
- [ ] `git rev-list --objects --all | grep -E "(ordo/cache|\.kdbx)"` returns nothing.
- [ ] Force-push completed; collaborators confirmed re-clone/reset.
- [ ] Rotation completed for all credentials in the vault.
- [ ] Pre-commit hook installed locally and in contributor docs.

## Quick commands

```bash
# Remove cached cache dir from index and commit
git rm -r --cached ordo/cache
git commit -m "chore(security): purge cache and block .kdbx"

# Rewrite history with filter-repo
git filter-repo --path ordo/cache --path-glob "*.kdbx" --invert-paths

# Force-push
git push --force --all && git push --force --tags

# Verify no leaked paths remain in history
git rev-list --objects --all | grep -E '(ordo/cache|\.kdbx)' || echo "OK: no matches"
```

---

If you want, I can run the safe parts (update .gitignore, remove from index) and prepare the filter-repo commands for you to execute.
