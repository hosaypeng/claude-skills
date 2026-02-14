---
name: explain
description: "Explain a file, folder, or entire codebase structure and purpose in the terminal. Use when user says 'explain this code', 'what does this project do', 'walk me through this repo', 'explain this file', or 'what is this folder for'."
user-invocable: true
argument-hint: "[path] (optional - defaults to current directory)"
---

# Explain

Generate a clear explanation of code structure and purpose. Adapts based on whether the target is a file, directory, or entire repository.

## Determine Scope

1. If argument is a file path → Single file explanation
2. If argument is a directory path → Directory explanation
3. If no argument or "." → Entire repo explanation

## Single File Explanation

When explaining a single file:

1. Read the file contents
2. Identify the language and framework
3. Explain:
   - **Purpose**: What this file is responsible for
   - **Key exports**: Functions, classes, constants exposed
   - **Dependencies**: What it imports and why
   - **Integration**: How it connects to the rest of the codebase
4. Keep it concise - focus on "what" and "why", not line-by-line

## Directory Explanation

When explaining a directory:

1. List all files in the directory
2. Identify patterns (components, utilities, services, etc.)
3. Explain:
   - **Responsibility**: What this directory owns
   - **Key files**: Most important files and their roles
   - **Internal structure**: How files relate to each other
   - **Public API**: What this directory exports to the rest of the app
4. Include a visual tree of the directory

## Repository Explanation

When explaining an entire repo:

1. Check for README.md, package.json, Cargo.toml, go.mod, etc.
2. Identify the tech stack from config files
3. Map the directory structure
4. Explain:
   - **Overview**: What this project does (1-2 sentences)
   - **Tech Stack**: Languages, frameworks, databases detected
   - **Architecture**: Pattern used (monolith, microservices, clean architecture, etc.)
   - **Structure**: Directory tree with purpose of each top-level folder
   - **Entry Points**: Where execution starts, main files
   - **Commands**: Build, test, run commands if detectable
5. Keep the overview high-level - link to paths for details

## Output Format

Use this structure for repo/directory explanations:

```markdown
# [Project/Directory Name]

## Overview
[1-2 sentence description]

## Tech Stack
- [Framework/Language]
- [Database if applicable]
- [Key libraries]

## Structure
├── folder/     → [purpose]
├── folder/     → [purpose]
└── file        → [purpose]

## Key Files
- `path/to/file` → [what it does]
- `path/to/file` → [what it does]

## Entry Points
- `path/to/main` → [description]

## Commands
- `command` → [what it does]
```

## Rules

- Be concise - developers want quick orientation, not novels
- Use path references so readers can jump to files
- Detect and mention architectural patterns when present
- If you find a README.md, incorporate its info but don't just repeat it
- For monorepos, explain the package/workspace structure
- Skip node_modules, .git, build artifacts, and other generated directories
