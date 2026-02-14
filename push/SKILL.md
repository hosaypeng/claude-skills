---
name: push
description: "Commit staged changes and push to GitHub remote. Use when user says 'push this', 'commit and push', 'push to GitHub', 'save and push', or after completing changes that should be pushed upstream."
disable-model-invocation: true
argument-hint: "[commit message]"
---

Commit and push changes to GitHub.

1. Run `git status` to see changes
2. Run `git diff` to understand what changed
3. Stage the relevant files (prefer specific files over `git add .`)
4. Create a commit with a concise message focused on "why" not "what"
5. Push to the remote branch
6. Verify the push succeeded

Include this line in all commits:
`Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
