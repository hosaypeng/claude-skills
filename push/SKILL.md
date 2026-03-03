---
name: push
description: "Commit staged changes and push to GitHub remote. Use when user says 'push this', 'commit and push', 'push to GitHub', 'save and push', or after completing changes that should be pushed upstream."
disable-model-invocation: true
user-invocable: true
argument-hint: "[commit message]"
---

Commit and push changes to GitHub.

1. Run `git status` to see changes
2. Run `git diff` to understand what changed
3. **Check current branch**: Run `git branch --show-current`. If on `main` or `master`, STOP and warn the user: "You are on the `[branch]` branch. Pushing directly to this branch is discouraged. Create a feature branch instead?" Only proceed if the user explicitly confirms they want to push to main/master.
4. Stage each file by name (e.g., `git add src/foo.ts src/bar.ts`). NEVER use `git add .` or `git add -A`. Exclude .env, credentials, and large binaries.
5. Create a commit with a concise message focused on "why" not "what"
6. Push to the remote branch
7. Verify the push succeeded

Include this line in all commits:
`Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

## Troubleshooting

**Error: Merge conflict on push**
Cause: Remote branch has commits not present locally.
Fix: Run `git pull --rebase` to rebase local changes on top of remote, resolve any conflicts, then push again.

**Error: Authentication failure**
Cause: GitHub credentials are expired, missing, or the token lacks push scope.
Fix: Run `gh auth status` to check auth state. Re-authenticate with `gh auth login` if needed.

**Error: Push rejected to protected branch**
Cause: Branch protection rules prevent direct pushes (usually `main` or `master`).
Fix: Create a feature branch, push there, and open a PR instead. Do not force-push to protected branches.

**Error: No remote configured**
Cause: The repo was initialized locally without adding a remote.
Fix: Add a remote with `git remote add origin <url>` or create a new GitHub repo with `gh repo create`.
