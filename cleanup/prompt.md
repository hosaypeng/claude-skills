# Environment Cleanup Task

You are executing the `/cleanup` skill to remove accumulated environment garbage.

## Objectives

Clean up temporary state and accumulated artifacts to ensure a fresh environment for autonomous agent work.

## What to Clean

1. **Scratchpad directory**: `/private/tmp/claude-501/-Users-hsp-Library-CloudStorage-GoogleDrive-sheneemaid-gmail-com-My-Drive-mdw-biodata/34cf2072-5c75-426e-8825-8a8f7acc4af6/scratchpad`
   - Remove all temporary files
   - Archive anything that looks important (ask user first if unsure)

2. **Session artifacts**:
   - Check for orphaned processes
   - Look for stale lock files
   - Remove temporary downloads

3. **Environment state**:
   - List what was cleaned
   - Report disk space recovered
   - Log cleanup to `~/.claude/cleanup-log.txt`

## Constraints

- **DO NOT** delete anything in the user's working directory
- **DO NOT** remove important dotfiles or configs
- **DO** ask before removing anything that might be a user artifact
- **DO** provide a summary of what was cleaned

## Acceptance Criteria

- Scratchpad is cleared
- Summary report shows what was removed and space recovered
- Log entry created with timestamp
- Environment is ready for fresh agent runs

## Process

1. Scan the scratchpad and temp directories
2. Identify what can be safely removed
3. Ask user to confirm if there are any questionable items
4. Execute cleanup
5. Report results with statistics
6. Create log entry

Execute the cleanup now.
