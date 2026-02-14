---
name: cost-tips
description: Cost optimization strategies and checklist for Claude Code
invocable: true
---

# Claude Code Cost Optimization

Average cost: **$6/dev/day** (90% under $12/day). Costs scale with context size.

## Quick Actions

### Check Current Usage
- `/cost` - View detailed token usage for this session
- `/stats` - View usage patterns (for Claude Max/Pro subscribers)
- Configure status line to show context usage continuously

### Context Management (Biggest Impact)
- `/clear` - Clear context when switching to unrelated work (saves most tokens)
- `/compact <instructions>` - Summarize conversation with focus (e.g., `/compact Focus on code changes`)
- `/rename` before clearing so you can `/resume` later

### Model Selection
- **Sonnet** (default) - Most coding tasks, cheapest
- **Opus** - Complex architecture decisions only
- **Haiku** - Simple subagent tasks (`model: haiku` in Task tool)
- Switch mid-session: `/model`

## Cost Reduction Checklist

### Context Optimization
- [ ] Monitor context usage with `/cost` or status line
- [ ] Use `/clear` between unrelated tasks (stale context wastes tokens)
- [ ] Add custom compaction: `/compact Focus on test output and code changes`
- [ ] Keep CLAUDE.md under 500 lines (move details to skills)
- [ ] Write specific prompts, not vague ones ("add input validation to auth.ts:45" vs "improve codebase")

### MCP Server Optimization
- [ ] **Prefer CLI tools over MCP servers** (more context-efficient):
  - Use `gh` instead of GitHub MCP server
  - Use `aws`, `gcloud`, `sentry-cli` directly
- [ ] Disable unused MCP servers: `/mcp`
- [ ] Lower tool search threshold: `ENABLE_TOOL_SEARCH=auto:5` (defers tools until needed)
- [ ] Install code intelligence plugins (precise navigation vs text search)

### Workflow Efficiency
- [ ] Use **plan mode** (Shift+Tab) for complex tasks (prevents expensive re-work)
- [ ] Press **Escape** to stop wrong directions early
- [ ] Use `/rewind` or double-tap Escape to restore checkpoints
- [ ] Test incrementally (one file → test → continue)
- [ ] Delegate verbose operations to subagents (tests, logs, docs)

### Extended Thinking
- [ ] Default: 31,999 tokens (billed as output tokens)
- [ ] For simple tasks: Lower budget `MAX_THINKING_TOKENS=8000` or disable in `/config`

### Advanced Optimizations
- [ ] Move specialized workflows from CLAUDE.md to skills (load on-demand)
- [ ] Use hooks to preprocess data (filter logs, grep errors before Claude sees them)
- [ ] Use `.claude/rules/` with glob patterns for file-specific rules
- [ ] For projects with multiple languages, use path-based rule loading

## Team Rate Limits (TPM per user)

| Team Size | TPM per User | RPM per User |
|-----------|-------------|-------------|
| 1-5       | 200k-300k   | 5-7         |
| 5-20      | 100k-150k   | 2.5-3.5     |
| 20-50     | 50k-75k     | 1.25-1.75   |
| 50-100    | 25k-35k     | 0.62-0.87   |
| 100-500   | 15k-20k     | 0.37-0.47   |
| 500+      | 10k-15k     | 0.25-0.35   |

## Background Token Usage

Claude Code uses small amounts of tokens (~$0.04/session) for:
- Conversation summarization (for `/resume` feature)
- Command processing (like `/cost` status checks)

## Quick Reference Commands

```bash
/cost              # View token usage and costs
/clear             # Clear context (biggest savings)
/compact           # Summarize conversation
/model             # Switch models
/mcp               # Manage MCP servers
/config            # Adjust settings (thinking budget, etc.)
/memory            # See loaded CLAUDE.md files
```

## When to Optimize Aggressively

- **Large monorepos** - Use `/clear` frequently, prefer CLI tools
- **Long debugging sessions** - Delegate verbose logs to subagents
- **Team deployments** - Set workspace spend limits, monitor with Console
- **Automated workflows** - Use Haiku for simple tasks, hooks for preprocessing

## When NOT to Over-Optimize

- Small projects with low token usage
- One-off quick tasks (the overhead isn't worth it)
- When learning (exploration is valuable)

---

**Next steps:**
1. Run `/cost` to see current usage
2. Check `/memory` to see what's loaded
3. Try `/clear` between unrelated tasks today
4. Monitor status line to build awareness

For more details: https://code.claude.com/docs/en/costs
