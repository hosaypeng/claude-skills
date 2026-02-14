# Code Quality Checklist

## Test Coverage

### What to Check

- **New code paths**: Does new functionality have tests?
- **Modified logic**: Are existing tests updated?
- **Edge cases**: Null, empty, error paths covered?
- **Integration points**: API boundaries tested?
- **Deleted code**: Orphaned tests cleaned up?

### Coverage Gaps to Flag

| Priority | Gap |
|----------|-----|
| P1 | Critical path (auth, payments, data mutation) untested |
| P1 | Error handling path untested |
| P2 | New public API without tests |
| P2 | Complex conditional logic untested |
| P3 | Utility function without unit test |

### Questions to Ask
- "If this breaks in production, would a test catch it?"
- "What's the simplest test that would verify this works?"
- "Are we testing behavior or implementation?"

---

## Error Handling

### Anti-patterns

```javascript
// Silent failure - P1
try { ... } catch (e) { }

// Log and forget - P2
try { ... } catch (e) { console.log(e) }

// Overly broad catch - P2
try { ... } catch (Exception e) { ... }

// Async errors unhandled - P1
promise.then(x => ...)  // Missing .catch()
```

### Best Practices

- [ ] Errors caught at appropriate boundaries
- [ ] Error messages user-friendly (no internal details)
- [ ] Errors logged with sufficient context
- [ ] Async errors properly propagated
- [ ] Fallback behavior for recoverable errors
- [ ] Critical errors trigger alerts

### Questions to Ask
- "What happens when this fails?"
- "Will the caller know something went wrong?"
- "Is there enough context to debug this?"

---

## Performance

### CPU-Intensive Operations

- Expensive operations in hot paths (regex compile, JSON parse, crypto in loops)
- Blocking main thread with sync I/O
- Unnecessary recomputation
- Missing memoization for pure functions

### Database & I/O

```javascript
// N+1 query - P1
for (const id of ids) {
  const user = await db.query(`SELECT * FROM users WHERE id = ?`, id)
}

// Batch instead - correct
const users = await db.query(`SELECT * FROM users WHERE id IN (?)`, ids)
```

| Issue | Priority |
|-------|----------|
| N+1 queries | P1 |
| Missing indexes on queried columns | P1 |
| SELECT * when few columns needed | P2 |
| No pagination on large datasets | P1 |
| Missing connection pooling | P2 |

### Caching Issues

- Missing cache for expensive operations
- Cache without TTL (stale data forever)
- Cache without invalidation strategy
- Cache key collisions
- Caching user-specific data globally (security!)

### Memory

- Unbounded collections that grow without limit
- Large object retention preventing GC
- String concatenation in loops (use join/StringBuilder)
- Loading large files entirely (use streaming)

### Questions to Ask
- "What's the time complexity?"
- "How does this behave with 10x/100x data?"
- "Is this result cacheable?"
- "Can this be batched?"

---

## Boundary Conditions

### Null/Undefined

```javascript
// DANGEROUS
const name = user.profile.name        // What if profile is null?
const first = items[0]                // What if items is empty?
const avg = total / count             // What if count is 0?
if (value) { ... }                    // Fails for 0, "", false
```

| Issue | Check |
|-------|-------|
| Missing null check | Access on potentially null object |
| Truthy/falsy confusion | `0` or `""` are valid values |
| Optional chaining overuse | `a?.b?.c?.d` hiding structural issues |

### Empty Collections

- Empty array not handled (code assumes items exist)
- First/last element access without length check
- Reduce without initial value on empty array

### Numeric Boundaries

- Division by zero
- Integer overflow (numbers exceeding safe range)
- Floating point comparison with `===`
- Negative values where not allowed
- Off-by-one errors in loops/slicing

### String Boundaries

- Empty string not handled
- Whitespace-only string passes truthy check
- Very long strings (no length limits)
- Unicode edge cases (emoji, RTL, combining chars)

### Questions to Ask
- "What if this is null/undefined?"
- "What if this collection is empty?"
- "What's the valid range for this number?"
- "What happens at 0, -1, MAX_INT?"

---

## Breaking Changes

### Public API

- Function signature changed (parameters added/removed/reordered)
- Return type changed
- Exception/error types changed
- Default values changed
- Removed exports still imported elsewhere

### Data/Schema

- Database column type changed
- Required field added without migration
- Field removed or renamed
- Enum values changed
- Serialization format changed

### Configuration

- Environment variable renamed
- Config key removed
- Default behavior changed

### Questions to Ask
- "Who else calls this?"
- "Is this a public interface?"
- "Does this need a migration?"
- "Should this be versioned?"
