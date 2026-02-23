---
name: analyze-page
description: "Fetch and analyze full webpage content without summarization loss. Use when user says 'analyze this page', 'read this URL fully', 'get the full page content', 'extract details from this site', or needs exact quotes or complete data from a webpage."
user-invocable: true
argument-hint: "<url> [focus area] [--full|--targeted]"
---

# Full Page Analysis

Retrieve and analyze webpage content with full fidelity, bypassing WebFetch's summarization.

## Mode Selection

Choose the most token-efficient approach based on need:

| Flag | Method | Best for |
|------|--------|----------|
| (default) | Smart routing | Auto-selects based on content |
| `--targeted` | JavaScript extraction | Known section/selector needed |
| `--full` | Complete text dump | Legal docs, specs, full context |

## Process

### Default Mode (Smart Routing)

1. **Quick probe first**: Use WebFetch with prompt "List all section headings and estimate word count"
2. **Decide extraction method**:
   - Short page (<2000 words): Use get_page_text directly, no save
   - Long page + specific focus: Use JavaScript to extract relevant section
   - Long page + general analysis: Full extraction with chunking

### Targeted Mode (`--targeted`)

Skip full extraction. Use JavaScript to pull specific content:

```javascript
// Example: Extract just the pricing section
document.querySelector('[data-section="pricing"]')?.innerText ||
document.querySelector('#pricing')?.innerText ||
[...document.querySelectorAll('h2')].find(h => h.textContent.includes('Pricing'))?.parentElement?.innerText
```

Use `mcp__claude-in-chrome__javascript_tool` with a selector based on the focus area.

### Full Mode (`--full`)

1. Get tab context (reuse existing tab if same domain)
2. Navigate + get_page_text in sequence
3. Only save to scratchpad if content >8000 words (for chunked re-reading)
4. Analyze in single pass when possible

## Token Optimization Rules

- **Reuse tabs**: Check tabs_context first, don't create new tabs for same domain
- **Skip scratchpad**: Only write to file if content requires multiple passes
- **Parallel calls**: Combine independent operations
- **Early exit**: If WebFetch probe answers the question, stop there

## Output

Provide a structured analysis:

```markdown
## Source
[URL] | Fetched: [timestamp]

## Summary
[2-3 sentence overview]

## Key Details
- [Specific finding with exact quotes where relevant]
- [Another finding]

## Structure
[How the page is organized - sections, navigation, etc.]

## [Focus Area] (if specified)
[Detailed analysis of the user's area of interest]

## Extraction Method
[Which mode was used and why]
```

## Arguments

- **url** (required): The webpage to analyze
- **focus area** (optional): Specific aspect to emphasize (e.g., "pricing", "technical specs", "author bio")

## Constraints

- If the page requires authentication, inform the user
- Respect robots.txt and rate limits
- Don't reproduce copyrighted content verbatim in the response - use short quotes
- The saved file in scratchpad is for YOUR analysis, not for giving to the user

## When to Use This vs WebFetch

Use `/analyze-page` when you need:
- Exact quotes or specific wording
- Complete table/list data
- Full context before making decisions
- To analyze structure or navigation
- Legal, technical, or specification content

Use WebFetch when you need:
- Quick factual lookups
- General understanding of a topic
- Multiple pages scanned rapidly

## Troubleshooting

- **Page returns empty content or 403**: The page may require authentication or block automated access. Fall back to `mcp__claude-in-chrome__navigate` + `get_page_text`. If auth is required, inform the user.
- **Chrome MCP tools unavailable**: Fall back to WebFetch-only mode. Note in the output that full-fidelity extraction was not possible.
- **Page content exceeds context window**: Use targeted mode to extract specific sections, or process in chunks.
