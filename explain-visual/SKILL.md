---
name: explain-visual
description: "Generate an interactive HTML slide deck that visually explains a codebase with architecture diagrams, file trees, and data flow. Use when user says 'explain this project visually', 'create a codebase presentation', 'visual overview', or 'make slides for this repo'."
user-invocable: true
argument-hint: "[path] (optional - defaults to current directory)"
---

# Explain Visual

Generate an interactive, self-contained HTML slide deck that visually explains a codebase. This is the visual companion to `/explain` - instead of terminal markdown, it produces a browser-based presentation.

## Step 1: Explore the Codebase

Use the Task tool with `subagent_type: Explore` (thoroughness: "very thorough") to map:

- **Project identity**: Name, one-liner description, tech stack
- **Architecture**: How major components connect (client/server, modules, services, layers)
- **Directory structure**: Top-level folders and their purposes
- **Key files**: The 5-10 most important files and what they do
- **Data/request flow**: How a typical request or action moves through the system
- **Entry points & commands**: How to build, run, test, deploy

Skip `node_modules`, `.git`, `build/`, `dist/`, and other generated directories.

If an argument path is provided, scope the exploration to that path. Otherwise explore the entire current working directory.

## Step 2: Generate the HTML Presentation

Write a single self-contained `.html` file with these exact slides:

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

Use this CSS foundation:

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #1a1a2e;
  --text: #e0e0e0;
  --accent: #4fc3f7;
  --card-bg: #16213e;
  --border: #0f3460;
}
[data-theme="light"] {
  --bg: #fafafa;
  --text: #1a1a2e;
  --accent: #0277bd;
  --card-bg: #ffffff;
  --border: #e0e0e0;
}
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  overflow: hidden;
  height: 100vh;
}
```

Use this JS structure for slide navigation:

```javascript
const slides = document.querySelectorAll('.slide');
let current = 0;

function showSlide(n) {
  slides.forEach(s => s.classList.remove('active'));
  current = Math.max(0, Math.min(n, slides.length - 1));
  slides[current].classList.add('active');
  document.getElementById('progress').textContent = `${current + 1} / ${slides.length}`;
}

document.addEventListener('keydown', e => {
  if (e.key === 'ArrowRight' || e.key === ' ') showSlide(current + 1);
  if (e.key === 'ArrowLeft') showSlide(current - 1);
});

showSlide(0);
```

## Step 3: Save the File

- Default filename: `codebase-overview.html` in the project root
- If the user specifies a custom name via argument, use that instead
- After writing the file, tell the user: "Open `codebase-overview.html` in your browser. Use arrow keys to navigate slides."

## Diagram Guidelines

Since no external libraries are allowed, build all diagrams with CSS:

- **Boxes**: `div` elements with border, border-radius, padding
- **Arrows**: CSS pseudo-elements (`::after`) with borders rotated 45deg, or Unicode arrows (→ ↓ ←)
- **Flow lines**: Thin divs with background color connecting boxes
- **Layout**: Flexbox or CSS Grid for positioning
- **Colors**: Use `var(--accent)` for highlights, `var(--border)` for connectors

## Rules

- Never include external URLs, CDN links, or `<script src>` tags
- Never use images - all visuals must be CSS/Unicode only
- Keep the HTML file under 500 lines when possible
- Use semantic HTML (`<section>`, `<header>`, `<nav>`)
- Ensure text is readable at default zoom (min 16px body text)
- Architecture diagrams should reflect the ACTUAL codebase, not generic templates
- If the codebase is very simple (< 5 files), combine slides 4 and 5

## Troubleshooting

**Error: Repository has no recognizable structure**
Cause: The directory contains only data files, configs, or non-standard project layouts with no detectable tech stack.
Fix: Fall back to a generic directory overview. Use file extensions and directory names to infer purpose. Ask the user to describe the project if detection fails entirely.

**Error: HTML file write fails**
Cause: Disk full, permissions issue, or the target path is invalid.
Fix: Check disk space with `df -h` and directory permissions with `ls -la`. Try writing to an alternate location (e.g., `/tmp/codebase-overview.html`) if the project root isn't writable.

**Error: Generated HTML exceeds 500 lines for large codebases**
Cause: The project has many components, resulting in verbose slide content.
Fix: Prioritize the most important components. Limit Key Files to top 8, collapse less critical directories in the tree, and summarize secondary data flows instead of diagramming all of them.
