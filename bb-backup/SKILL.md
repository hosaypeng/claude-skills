---
name: bb-backup
description: "Push a backup of the business_belts folder to its private GitHub repo. Use when user says 'bb-backup', 'backup business belts', 'push business belts', or 'save business belts'."
user-invocable: true
argument-hint: "[commit message] (optional - defaults to 'update')"
---

# Business Belts Backup

Push the latest state of the `business_belts` folder to its private GitHub repo.

## Configuration

The skill reads its paths from `~/.claude/skills/bb-backup/config.json`:

```json
{
  "local_path": "<path to business_belts folder>",
  "remote_repo": "<github repo URL>"
}
```

## Instructions

1. Read `~/.claude/skills/bb-backup/config.json` to get `local_path` and `remote_repo`.
2. Set the commit message from the skill argument, defaulting to `"update"` if none provided.

3. Run the backup:

```bash
cd "$local_path" && \
git add -A && \
git status --short
```

4. If there are no changes (working tree clean), report "Nothing to back up — already up to date." and stop.

5. If there are changes, commit and push:

```bash
cd "$local_path" && \
git commit -m "<message>

Co-Authored-By: Claude <noreply@anthropic.com>" && \
git push
```

6. Report how many files changed and confirm the push succeeded.

## Troubleshooting

- **"not a git repository"**: Re-initialize with `git init` and re-add the remote from config.json.
- **Push rejected**: Run `git pull --rebase` first, then push again.
- **Large files fail**: GitHub has a 100MB file size limit. Check with `git ls-files | xargs ls -la | sort -k5 -rn | head`.
