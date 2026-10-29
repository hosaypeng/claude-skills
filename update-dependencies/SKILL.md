---
user-invocable: true
name: update-dependencies
description: "After moving, renaming or deleting notes or folders in the Obsidian vault, find everything that still points at the old paths: AGENTS/CLAUDE files, hooks, scripts, LaunchAgents, memory, wikilinks and the vault-rag index. Use when user says 'update vault dependencies', 'I moved notes', 'I renamed notes', 'sweep vault deps', or 'after vault restructure'."
argument-hint: "[--ref <rev> | --since <date>] [--move OLD NEW]"
---

# Update Vault Dependencies

Finds what still references vault paths that moved or were deleted. Report first. The only vault edit this skill makes is a wikilink rewrite, and only after the user confirms. Files outside the vault are never edited.

## 1. Find what moved and what points at it

```bash
python3 -B -I ~/.claude/skills/update-dependencies/scripts/find_moved_refs.py [options]
```

Show the report as printed. The script is read-only (git plumbing only, it never touches the index) and compares the vault's git history plus the working tree, so a move is seen whether or not it was committed. Always run it as `python3 -B -I` (stdlib only, system Python 3.9, no `__pycache__`).

- The default base is the last commit older than 2 days, because the vault auto-commits every 6 hours and a move is soon buried under later commits. If it is unclear when the restructure began, ask the user, then pass `--since <date>` (or `--ref <rev>`) to start before it. The report header prints the commit range.
- `--ref <rev>` sets the base commit (`--ref HEAD` = uncommitted changes only).
- `--move OLD NEW` adds a move git cannot see (repeatable). `NEW` of `-` means deleted. An absolute `OLD` covers a relocated vault root.
- `--all` lifts the 60-line cap on long lists. `--vault <dir>` points at another checkout.

Sections: What moved; External references (`file:line` in AGENTS/CLAUDE files, hooks, `settings.json`, other skills, `agent-config/bin`, `vault-rag`, LaunchAgent plists, memory); Wikilinks to update (including bare `[[name]]` links that now silently resolve to a different note); Duplicate-basename risks; vault-rag coverage; Standing checks (informational, shown on every run: leftover paths of the old iCloud vault and top-level dirs outside `DIRS_TO_INDEX`). `All clear` ignores the standing checks.

## 2. Run the existing audits

Do not re-implement them:

```bash
bash ~/.claude/skills/audit-vault/scripts/audit_all.sh links
bash ~/.claude/skills/audit-paths/scripts/audit_paths.sh all
```

`links` reports broken wikilinks and duplicate basenames across the whole vault. audit-paths reports dead paths in CLAUDE.md, memory and LaunchAgent plists.

## 3. Refresh the search index

Tell the user to run `~/Code/agent-config/bin/vault-rag-index.sh`. It prunes stale paths itself and also runs daily at 04:00, but semantic search shows old paths until then. Never edit `~/Code/vault-rag/index_state.json` by hand.

## 4. Rewrite wikilinks (only after explicit confirmation)

Show the "Wikilinks to update" list and ask first. Proposals marked `[ambiguous]` need the user's pick. Then:

1. Run the checkpoint: `bash ~/.claude/skills/update-dependencies/scripts/checkpoint_vault.sh`. It refuses to run from 10 minutes before to 20 minutes after 00:00, 06:00, 12:00 or 18:00 (auto-sync can start late and would commit a half-edited tree), then stages everything and tags `checkpoint-<timestamp>` on a snapshot (or on HEAD if the tree is clean). Finish all rewrites before the next window; it prints the minutes left.
2. Rewrite each link with the Edit tool, keeping `!`, `#heading` and `|alias`.
3. Re-run `find_moved_refs.py` and `audit_all.sh links`. The wikilink list should be empty.
4. Roll back one file with `git -C ~/Documents/obsidian checkout <tag> -- <path>`.

## Rules

- Never auto-fix external files. Report `file:line` with the proposed edit and let the user decide.
- A hit tagged `[line also mentions the new path]` usually narrates the move (a memory note). It is history, not a stale reference.
- Never hand-edit `50_areas/personal/directory_tree.md`. A Stop hook regenerates it from `~/Code/agent-config/bin/update_dir_tree.py`, so fix the generator.
- `~/Documents/journal/` is read-only.
- Ask before deleting a note. Private files listed by exact path in the vault `.gitignore` (such as `directory_tree.md`) stay where they are: a moved copy is no longer ignored and the next auto-sync pushes it.
- This skill sits in a public repo: keep secrets and personal data out of it.

## Troubleshooting

- **`error: unknown revision` or `not a git repository`**: the `--ref` commit does not exist, or `--vault` is not a repo root.
- **A moved file is missing from "What moved"**: git cannot see moves of gitignored files, and the move may predate the base. A heavy edit during a move can show as delete plus add. Pass the pair with `--move OLD NEW`, or an earlier `--since`.
- **Too many hits**: narrow the base (`--ref HEAD`). Basename-only matches are skipped when the old filename still exists elsewhere.
- **`skipped` or `missing` lines under Notes**: that source was not checked (absent, binary or over 1 MB). Add its new path to `SOURCE_PATTERNS` in the script.
