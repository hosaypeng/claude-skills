---
user-invocable: true
name: define-task
description: "Create well-defined autonomous task specifications with outcomes and acceptance criteria. Use when user says 'define a task', 'write a task spec', 'create acceptance criteria', 'scope this work', or needs to structure a task for autonomous agent execution."
---

# Autonomous Task Definition

## Objectives

Help the user articulate a task in the format that enables autonomous execution:
1. **Desired Outcome** - What success looks like
2. **Acceptance Criteria** - How to verify success
3. **Constraints** - Boundaries and limits

## Interactive Process

Guide the user through these questions:

### 1. Desired Outcome
Ask: "What is the specific outcome you want to achieve?"

Help them focus on WHAT, not HOW:
- Good: "Authentication system that supports OAuth and email/password login"
- Bad: "Install passport.js, create auth middleware, set up routes..."

### 2. Acceptance Criteria
Ask: "How will you know when this is successfully completed?"

Help them define measurable criteria:
- Good: "Users can log in with Google OAuth, tests pass, session persists across page reloads"
- Bad: "It should work well"

Push for specificity:
- What should happen when the task is done?
- What tests should pass?
- What behavior should be observable?
- What artifacts should exist?

### 3. Constraints
Ask: "What boundaries or limitations should be respected?"

Common constraints:
- "Don't modify files in /legacy directory"
- "Use existing database schema, don't add new tables"
- "Must work with Node.js v18+"
- "Keep bundle size under 50KB"
- "No external API dependencies"

### 4. Context (Optional)
Ask: "Is there existing code or patterns that should be followed?"

This is supplementary, not procedural:
- Relevant file paths
- Existing patterns to match
- Dependencies already in use
- API contracts to honor

## Output Format

Create a task file in the scratchpad with this structure:

```markdown
# Task: [Clear, concise task name]

## Desired Outcome
[Single paragraph describing what success looks like]

## Acceptance Criteria
- [ ] [Specific, measurable criterion 1]
- [ ] [Specific, measurable criterion 2]
- [ ] [Specific, measurable criterion 3]
[Add as many as needed]

## Constraints
- [Boundary or limitation 1]
- [Boundary or limitation 2]
[Add as many as needed]

## Context (if relevant)
- Relevant files: [paths]
- Existing patterns: [description]
- Dependencies: [list]

---
Task created: [timestamp]
Ready for autonomous execution
```

Save to the current project directory or a user-specified location as `task-[taskname].md`.

## After Task Creation

Once the task is defined:
1. Save it to scratchpad
2. Show the user the formatted task
3. Ask: "Is this task definition ready for execution, or would you like to refine it?"
4. If ready, offer to begin execution immediately

## Acceptance Criteria for This Skill

- User has clearly articulated the desired outcome
- Acceptance criteria are specific and measurable
- Constraints are explicit
- The task can be understood without procedural steps
- Task file is saved to scratchpad

## Constraints for This Skill

- If the user describes implementation steps instead of outcomes, redirect: ask what the end result should be, not how to get there.
- Keep the task definition concise
- Avoid ambiguity in acceptance criteria

## Troubleshooting

**Error: Scratchpad directory creation fails**
Cause: Parent directory doesn't exist or path contains invalid characters.
Fix: Verify the scratchpad path exists with `ls`. Create parent directories with `mkdir -p`. Ensure task name uses only alphanumeric characters, hyphens, and underscores.

**Error: Disk full when saving task file**
Cause: No remaining disk space on the volume.
Fix: Check available space with `df -h`. Free up space or save to an alternate location. The task definition can also be output directly to the terminal for the user to save manually.

Execute the task definition process now.
