# Generic Security Incident Playbook

Purpose: A concise, repeatable sequence for handling source repository security incidents (secret leaks, credential exposure, sensitive file commits).

## 1. Detect & Contain
- Identify leaked artifact (file path / commit hash / branch).
- Immediately stop further spread:
  - Add to `.gitignore`.
  - Add/update pre-commit hook to block pattern.
  - If highly sensitive & public repo: temporarily make private / restrict access.

## 2. Assess Impact
- What type of secret? (API key, SSH private key, database dump, password vault, token, PII.)
- Exposure window: first commit timestamp until containment commit.
- Distribution: forks, clones, CI logs, build artifacts, package registries.

## 3. Eradicate (Repo Hygiene)
Choose appropriate removal method:
- Single recent commit: `git reset --soft HEAD~1` (if not pushed) then recommit without secret.
- Already pushed: history rewrite.
  - Preferred: `git filter-repo --path <file> --invert-paths` or path-glob.
  - Alternative: BFG: `java -jar bfg.jar --delete-files 'secret.txt'`.
  - Legacy: `git filter-branch` (last resort).
- Force-push (`--force --all --tags`).
- Invalidate caches: GitHub will garbage collect; you cannot fully guarantee deletion if already copied—assume compromise.

## 4. Rotate & Revoke
- Revoke tokens / API keys / OAuth clients (in provider dashboards).
- Rotate passwords; enforce session invalidation if possible.
- Regenerate SSH keys; remove old public keys from servers/services.
- Rotate encryption keys (KMS / Vault) if exposed or derivable.
- Update CI/CD secrets and deployment systems.
- Document each rotated item: who, what, when, where new value stored.

## 5. Verify Purge
```bash
git rev-list --objects --all | grep -E '(secret-file|pattern)' || echo 'OK'
git log --name-only | grep -i 'secret-file' || echo 'OK'
```
- Check workflow / build artifacts for residual copies.
- Scan repo with a secret scanner (e.g., `gitleaks`, `trufflehog`).

## 6. Communicate
- Internal notification: summary (what leaked, impact, mitigations, rotation status).
- External (if required): responsible disclosure or security advisory.
- Provide re-clone instructions:
```bash
git fetch --all
git reset --hard origin/main
```

## 7. Hardening / Prevention
- Expand `.gitignore`.
- Enforce pre-commit scanning (gitleaks hook, custom script).
- CI pipeline secret scanning gate.
- Principle of least privilege for tokens.
- Shorter token lifetimes / automatic rotation policy.
- Add `SECURITY.md` with disclosure process.

## 8. Post-Incident Review
- Timeline of events.
- Root cause (process / tooling / human error).
- What worked, what failed.
- Action items with owners & due dates.

## 9. Tooling Quick Reference
- History rewrite: `git filter-repo` or BFG.
- Scanner examples:
  - `gitleaks detect --source .`
  - `trufflehog filesystem --directory .`
- Key generation/rotation (examples):
  - SSH: `ssh-keygen -t ed25519 -C 'rotated <date>'`
  - GitHub PAT revoke: Settings > Developer settings > Tokens.

## 10. Minimal Command Cheat Sheet
```bash
# Add ignore + remove from index
echo 'secret.txt' >> .gitignore
git rm --cached secret.txt
git commit -m 'chore(security): remove secret'

# Rewrite history (keep only paths NOT secret)
git filter-repo --path secret.txt --invert-paths

# Force push
git push --force --all && git push --force --tags

# Verify
git rev-list --objects --all | grep secret.txt || echo 'OK'
```

## Incident Log Template
```
Incident: <title>
Detected: <timestamp>
Reporter: <name>
Artifact(s): <files/identifiers>
First Appearance Commit: <hash>
Actions:
  - <time> Added ignore
  - <time> Removed from index
  - <time> History rewritten (command)
  - <time> Force-pushed
Rotation Summary:
  - <secret> rotated at <time> (owner)
Outstanding: <list>
Close Criteria: <conditions>
Status: OPEN|MONITOR|CLOSED
```

---
Use this playbook as the starting point for any future leak or secret exposure; tailor per incident.
