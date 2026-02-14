# Security and Reliability Checklist

## Input/Output Safety

- **XSS**: Unsafe HTML injection, `dangerouslySetInnerHTML`, unescaped templates, innerHTML
- **Injection**: SQL/NoSQL/command/GraphQL injection via string concatenation
- **SSRF**: User-controlled URLs reaching internal services without allowlist
- **Path traversal**: User input in file paths without sanitization (`../` attacks)
- **Prototype pollution**: Unsafe object merging in JavaScript
- **Template injection**: User input in template engines without escaping

## AuthN/AuthZ

- Missing tenant or ownership checks for read/write operations
- New endpoints without auth guards or RBAC enforcement
- Trusting client-provided roles/flags/IDs
- IDOR (Insecure Direct Object Reference)
- Session fixation or weak session management
- Missing rate limiting on auth endpoints

## JWT & Token Security

- Algorithm confusion (`none` or `HS256` when expecting `RS256`)
- Weak or hardcoded secrets
- Missing expiration (`exp`) or not validating it
- Sensitive data in JWT payload (base64 is not encryption)
- Not validating `iss` (issuer) or `aud` (audience)
- Token stored in localStorage (XSS vulnerable)

## Secrets and PII

- API keys, tokens, or credentials in code/config/logs
- Secrets in git history
- Environment variables exposed to client
- Excessive logging of PII or sensitive payloads
- Missing data masking in error messages
- Secrets passed via URL parameters

## Supply Chain & Dependencies

| Risk | What to Check |
|------|---------------|
| **New dependencies** | Is it maintained? Trusted author? Download count? |
| **Unpinned versions** | Could malicious update be installed? |
| **Dependency confusion** | Private package name collision? |
| **Untrusted CDN** | Integrity hash (SRI) present? |
| **Known CVEs** | Run `npm audit`, `pip-audit`, `cargo audit` |
| **Transitive deps** | Vulnerable indirect dependencies? |

## CORS & Headers

- Overly permissive CORS (`Access-Control-Allow-Origin: *` with credentials)
- Missing security headers (CSP, X-Frame-Options, X-Content-Type-Options)
- Exposed internal headers or stack traces
- Clickjacking vulnerability (missing frame protection)

## Runtime Risks

- Unbounded loops, recursive calls, or large in-memory buffers
- Missing timeouts on external calls
- Missing retries with backoff
- Blocking operations on request path
- Resource exhaustion (file handles, connections, memory)
- ReDoS (Regular Expression Denial of Service)

## Cryptography

- Weak algorithms (MD5, SHA1 for security purposes)
- Hardcoded IVs or salts
- ECB mode or encryption without authentication
- Insufficient key length
- Using Math.random() for security purposes
- Rolling your own crypto

---

## Race Conditions

### Shared State Access
- Multiple threads/goroutines/async tasks accessing shared variables without sync
- Global state or singletons modified concurrently
- Lazy initialization without proper locking
- Non-thread-safe collections in concurrent context

### Check-Then-Act (TOCTOU)
```python
# DANGEROUS: Time-of-check to time-of-use
if not exists(key):
    create(key)           # Another thread may have created it

if user.balance >= amount:
    user.balance -= amount  # Balance may have changed

value = get(key)
value += 1
set(key, value)           # Lost update if concurrent
```

### Database Concurrency
- Missing optimistic locking (`version` column)
- Missing pessimistic locking (`SELECT FOR UPDATE`)
- Read-modify-write without transaction isolation
- Counter increments without atomic ops
- Unique constraint violations in concurrent inserts

### Distributed Systems
- Missing distributed locks for shared resources
- Cache invalidation races
- Event ordering without proper sequencing
- Split-brain scenarios

### Questions to Ask
- "What happens if two requests hit this simultaneously?"
- "Is this operation atomic?"
- "What shared state does this access?"
- "How does this behave under high concurrency?"

---

## Data Integrity

- Missing transactions for multi-step operations
- Partial writes leaving inconsistent state
- Weak validation before persistence
- Missing idempotency for retryable operations
- Lost updates due to concurrent modifications
- No audit trail for sensitive changes
