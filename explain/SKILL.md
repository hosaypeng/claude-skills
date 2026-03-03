---
name: explain
description: "Explain a file, folder, or entire codebase with terminal output and an interactive HTML slide deck. Use when user says 'explain this code', 'what does this project do', 'walk me through this repo', 'explain this file', 'visual overview', or 'make slides for this repo'."
user-invocable: true
argument-hint: "[path] (optional - defaults to current directory)"
---

# Explain

Generate a clear explanation of code structure and purpose. For directory and repo scopes, also produce an interactive HTML slide deck. For single-file explanations, skip the slide deck unless the user explicitly requests it (e.g., "make slides").

## Determine Scope

1. If argument is a file path → Single file explanation
2. If argument is a directory path → Directory explanation
3. If no argument or "." → Entire repo explanation

---

## Phase 1: Terminal Explanation

### Single File Explanation

When explaining a single file:

1. Read the file contents
2. Identify the language and framework
3. Explain:
   - **Purpose**: What this file is responsible for
   - **Key exports**: Functions, classes, constants exposed
   - **Dependencies**: What it imports and why
   - **Integration**: How it connects to the rest of the codebase
4. Keep it concise - focus on "what" and "why", not line-by-line

### Directory Explanation

When explaining a directory:

1. List all files in the directory
2. Identify patterns (components, utilities, services, etc.)
3. Explain:
   - **Responsibility**: What this directory owns
   - **Key files**: Most important files and their roles
   - **Internal structure**: How files relate to each other
   - **Public API**: What this directory exports to the rest of the app
4. Include a visual tree of the directory

### Repository Explanation

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

### Terminal Output Format

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

---

## Phase 2: Visual Slide Deck

After the terminal explanation, generate an interactive self-contained HTML slide deck using the information gathered.

### Slide 1 - Title
- Project name (large heading)
- Tech stack badges (styled inline spans)
- One-sentence description

### Slide 2 - Architecture Overview
- CSS-only diagram showing how major components connect
- Use flexbox/grid boxes with labeled connections (arrows via CSS borders/pseudo-elements)
- Show the primary architectural pattern (monolith, client-server, microservices, etc.)

### Slide 3 - Directory Structure
- Visual file tree with folder icons (Unicode) and brief annotations
- Highlight the most important directories
- Style as a code block with color-coded annotations

### Slide 4 - Key Files
- Card layout showing 5-10 critical files
- Each card: file path, purpose, what it connects to
- Group by layer/concern if applicable

### Slide 5 - Data/Request Flow
- Step-by-step visual flow diagram
- Numbered steps showing how data moves through the system
- Use CSS boxes connected by arrows (borders + pseudo-elements)

### Slide 6 - Entry Points & Commands
- Table or card layout of available commands
- Categories: build, run, test, deploy
- Include the actual command strings in monospace

For single-file explanations, Phase 2 is skipped by default (terminal explanation is sufficient). If the user explicitly requests slides (e.g., "make slides", "generate a deck"), adapt the slides: use slides 1 (title/file info), 2 (structure/exports), 3 (dependencies/integration), and skip the rest if not applicable. Combine or reduce slides to fit the scope.

### HTML/CSS/JS Requirements

The generated HTML file MUST:

- Be a single file with all CSS and JS inlined (no external dependencies)
- Use vanilla HTML, CSS, and JS only (no frameworks, no CDN links)
- Support keyboard navigation: Left/Right arrows to move between slides
- Show a slide progress indicator (e.g., "2 / 6" or a progress bar)
- Include a dark/light theme toggle button (persist choice in localStorage)
- Default to dark theme
- Work completely offline
- Use a clean, minimal design with good typography (system font stack)
- Be responsive (work on both desktop and mobile viewports)

Use the CSS foundation and JS slide navigation from `~/.claude/skills/explain/references/slide_template.md`

### Save the File

- Default filename: `codebase-overview.html` in the project root
- If the user specifies a custom name via argument, use that instead
- After writing the file, tell the user: "Open `codebase-overview.html` in your browser. Use arrow keys to navigate slides."

---

## Rules

- Be concise - developers want quick orientation, not novels
- Use path references so readers can jump to files
- Detect and mention architectural patterns when present
- If a README.md exists, use it to confirm the project description and commands, but write your own structural analysis. Do not copy README paragraphs into the output.
- For monorepos, explain the package/workspace structure
- Skip node_modules, .git, build artifacts, and other generated directories
- Never include external URLs, CDN links, or `<script src>` tags in the HTML
- Never use images in the HTML - all visuals must be CSS/Unicode only
- Keep the HTML file under 500 lines when possible
- Use semantic HTML (`<section>`, `<header>`, `<nav>`)
- Ensure text is readable at default zoom (min 16px body text)
- Architecture diagrams should reflect the ACTUAL codebase, not generic templates
- If the codebase is very simple (< 5 files), combine slides 4 and 5

## Troubleshooting

**Error: File is unreadable or binary**
Cause: Target is a compiled binary, image, or non-text file.
Fix: Skip binary files and focus on source code. If the user points to a binary, explain what it likely is based on its extension and location.

**Error: Empty repository or directory**
Cause: The directory has no recognizable source files (freshly initialized repo, or only contains generated artifacts).
Fix: Report that the directory appears empty or contains no source code. Suggest the user check if they're pointing to the right path.

**Error: Permission denied reading files**
Cause: File or directory permissions prevent access.
Fix: Ask the user to check permissions with `ls -la`. Files may need `chmod` or the skill may need to run from a different user context.

**Error: Repository has no recognizable structure**
Cause: The directory contains only data files, configs, or non-standard project layouts with no detectable tech stack.
Fix: Fall back to a generic directory overview. Use file extensions and directory names to infer purpose. Ask the user to describe the project if detection fails entirely.

**Error: HTML file write fails**
Cause: Disk full, permissions issue, or the target path is invalid.
Fix: Check disk space with `df -h` and directory permissions with `ls -la`. Try writing to an alternate location (e.g., `/tmp/codebase-overview.html`) if the project root isn't writable.

**Error: Generated HTML exceeds 500 lines for large codebases**
Cause: The project has many components, resulting in verbose slide content.
Fix: Prioritize the most important components. Limit Key Files to top 8, collapse less critical directories in the tree, and summarize secondary data flows instead of diagramming all of them.
