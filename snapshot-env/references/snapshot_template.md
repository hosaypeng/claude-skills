# Snapshot Output Templates

## JSON Template

Create snapshot file: `scratchpad/snapshots/snapshot-[timestamp].json`

```json
{
  "snapshot_version": "1.0",
  "created_at": "ISO-8601 timestamp",
  "task": {
    "name": "task description",
    "working_directory": "/path/to/dir",
    "files_involved": ["file1.py", "file2.js"]
  },
  "system": {
    "os": "Darwin",
    "version": "25.2.0",
    "architecture": "arm64"
  },
  "tools": {
    "python": "3.11.5",
    "node": "20.10.0",
    "npm": "10.2.3",
    "git": "2.42.0"
  },
  "dependencies": {
    "python": "requirements.txt hash or content",
    "node": "package-lock.json hash or content"
  },
  "environment": {
    "PATH": "[sanitized]",
    "SHELL": "/bin/zsh",
    "LANG": "en_US.UTF-8"
  },
  "git": {
    "branch": "main",
    "commit": "abc123...",
    "clean": true,
    "remote": "https://github.com/user/repo"
  }
}
```

## Markdown Template

Also create human-readable: `scratchpad/snapshots/snapshot-[timestamp].md`

```markdown
# Environment Snapshot

**Created**: [timestamp]
**Task**: [description]
**Directory**: [path]

## System
- OS: Darwin 25.2.0 (arm64)
- Shell: /bin/zsh

## Tools
- Python: 3.11.5
- Node.js: 20.10.0
- Git: 2.42.0

## Dependencies
### Python
[content or hash of requirements.txt]

### Node.js
[content or hash of package.json]

## Git
- Branch: main
- Commit: abc123def456
- Status: clean
- Remote: https://github.com/user/repo

## Reproduction Steps
1. Clone repo from [remote]
2. Check out commit [sha]
3. Install dependencies: [commands]
4. Verify tool versions match above
5. Run task: [task description]

## Files
- [list of relevant files with checksums]
```
