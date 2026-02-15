---
name: snapshot-env
description: "Capture a reproducible environment snapshot with exact tool versions, dependencies, git state, and system info. Use when user says 'snapshot my environment', 'capture env', 'save environment state', or before risky operations to enable reproduction."
---

# Environment Snapshot Task

You are executing the `/snapshot-env` skill to capture a reproducible environment snapshot.

## Philosophy

From "How to Get Out of Your Agent's Way":
> "Systems that are not reproducible cannot be trusted to run unattended."

Fresh environments surface correctness. Persistent environments obscure it.

For reproducibility, we need to capture:
- Exact dependency versions
- Environment variables used
- Tool versions
- Task configuration
- Execution context

## Objectives

Create a complete snapshot of the current environment so this agent run can be reproduced exactly.

## What to Capture

### 1. System Information
```json
{
  "system": {
    "os": "Darwin/Linux/Windows",
    "version": "OS version",
    "architecture": "x86_64/arm64",
    "hostname": "machine name",
    "user": "username"
  }
}
```

### 2. Tool Versions
Detect and record versions of:
- Python (`python --version`)
- Node.js (`node --version`)
- npm/yarn/pnpm
- Go (`go version`)
- Rust (`rustc --version`)
- Git (`git --version`)
- Docker (`docker --version`)
- Other relevant tools in PATH

### 3. Project Dependencies
Based on project type:
- **Python**: `requirements.txt` or `Pipfile.lock` or `poetry.lock`
- **Node.js**: `package-lock.json` or `yarn.lock` or `pnpm-lock.yaml`
- **Go**: `go.mod` and `go.sum`
- **Rust**: `Cargo.lock`

### 4. Environment Variables
Capture relevant env vars (excluding secrets):
- PATH
- SHELL
- LANG/LC_*
- *_VERSION variables
- Project-specific vars (ask user if unsure)

**Never capture**: passwords, API keys, tokens, credentials

### 5. Task Configuration
- Working directory
- Files involved
- Commands that were run
- Timestamp

### 6. Git Context (if in repo)
- Current branch
- Latest commit SHA
- Dirty/clean state
- Remote URL (without credentials)

## Output Format

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

## Process

1. **Detect Project Type**:
   - Scan working directory for project files
   - Identify languages and frameworks in use

2. **Gather System Info**:
   - Run system commands to get OS, arch, etc.
   - Record timestamp

3. **Capture Tool Versions**:
   - Check which tools are available
   - Record exact versions

4. **Extract Dependencies**:
   - Find lock files
   - Hash or include content
   - Note if dependencies are out of sync

5. **Capture Environment**:
   - Get env vars (sanitize secrets)
   - Record working directory

6. **Git Context**:
   - If in git repo, capture commit/branch
   - Note clean/dirty state

7. **Save Snapshots**:
   - Write JSON file
   - Write markdown file
   - Create README if needed

8. **Report to User**:
   - Show snapshot location
   - List what was captured
   - Note any warnings (dirty git state, missing tools, etc.)

## Acceptance Criteria

- Snapshot contains enough info to reproduce the environment
- Both JSON and markdown versions are created
- Secrets are not captured
- File hashes/checksums are included
- Timestamp is in ISO-8601 format
- User knows where to find the snapshot

## Constraints

- Never capture credentials, API keys, or secrets
- Sanitize environment variables
- Keep snapshot files in scratchpad only
- Make snapshots self-documenting
- Include warnings about non-reproducible state

## Use Cases

- Before starting risky operations
- When handing off work to another agent/person
- Creating reproducible bug reports
- Documenting successful autonomous runs
- Compliance/audit trails

## Troubleshooting

**Error: Tool not found (e.g., `node: command not found`)**
Cause: The tool isn't installed or isn't in the current PATH.
Fix: Record the tool as "not installed" in the snapshot instead of failing. Note it in the warnings section so the user knows the snapshot is incomplete for that tool.

**Error: Permission denied running version commands**
Cause: The tool binary exists but isn't executable, or requires elevated permissions.
Fix: Skip the tool and note the permission issue in the snapshot. Suggest the user check permissions with `ls -la $(which <tool>)`.

**Error: Scratchpad directory not writable**
Cause: Permissions or disk space prevent writing snapshot files.
Fix: Check with `df -h` and `ls -la`. Fall back to writing the snapshot to the current working directory or output it directly to the terminal.

Execute environment snapshot now.
