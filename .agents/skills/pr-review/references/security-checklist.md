# Security Checklist — OWASP 2025 + CWE Top 25 (2026)

Used by the **Security** specialist agent in Phase 1. Every Critical/Major security finding MUST cite a CWE.

## OWASP Top 10 (2025)

| # | Category | What to look for |
|---|---|---|
| A01 | Broken Access Control | Missing authz checks, IDOR, privilege escalation, force-browsing |
| A02 | Cryptographic Failures | Hardcoded keys, weak algorithms (MD5, SHA1, DES), missing TLS, ECB mode, predictable IVs |
| A03 | Software Supply Chain Failures | Unpinned dependencies, unsigned packages, transitive vulns, typosquatting |
| A04 | Insecure Design | Missing rate limits, predictable IDs, threat-model gaps |
| A05 | Security Misconfiguration | Default creds, verbose errors, open CORS, debug mode in prod, missing security headers |
| A06 | Vulnerable & Outdated Components | Known CVEs in deps, EOL versions |
| A07 | Authentication Failures | Weak password rules, missing MFA, session fixation, predictable tokens |
| A08 | Software/Data Integrity Failures | Unsigned updates, untrusted deserialization, missing integrity checks |
| A09 | Logging & Alerting Failures | Missing audit logs, secrets in logs, no alerting on auth failures |
| A10 | Mishandling of Exceptional Conditions | Information leak in errors, fail-open instead of fail-closed |

## CWE Top 25 (2026) — high-priority hotlist

For each of these, flag aggressively if you see the pattern. CWE tag is required.

| CWE | Name | Pattern to scan for |
|---|---|---|
| CWE-79 | XSS | Unsanitized user input in HTML output, `innerHTML`, `dangerouslySetInnerHTML`, template injection |
| CWE-89 | SQL Injection | String concat into SQL, `f"SELECT ... {var}"`, query builders with raw user input |
| CWE-352 | CSRF | State-changing GET/POST without CSRF token or SameSite cookie |
| CWE-862 | Missing Authorization | Endpoint that touches sensitive data without auth check; route handler that doesn't verify resource ownership |
| CWE-787 | Out-of-bounds Write | Buffer arith in C/C++/unsafe Rust |
| CWE-22 | Path Traversal | `../` not stripped, user-controlled path joins, archive extraction without sanitization |
| CWE-416 | Use-After-Free | Lifetime issues in unsafe code, double-free, dangling pointers |
| CWE-78 | OS Command Injection | `exec`, `system`, `shell=True`, `child_process.exec` with user input |
| CWE-94 | Code Injection | `eval`, `Function()`, `pickle.loads` on user data, template injection |
| CWE-502 | Deserialization | `pickle.loads`, `yaml.load` (not safe_load), `unserialize`, Java `ObjectInputStream`, .NET `BinaryFormatter` |
| CWE-918 | SSRF | User-controlled URL passed to `fetch`/`curl`/`http.get` without allowlist |
| CWE-20 | Improper Input Validation | Missing validation at trust boundary (HTTP handler, queue consumer, file parser) |
| CWE-77 | Command Injection | Shell metacharacters not escaped before subprocess call |
| CWE-200 | Information Exposure | Stack traces in HTTP response, debug info in production errors, secrets in logs |
| CWE-269 | Improper Privilege Management | Privilege escalation, missing sudo gate, role bypass |
| CWE-287 | Improper Authentication | Auth bypass, missing auth check, token verification skipped |
| CWE-306 | Missing Authentication | Endpoint that should require auth but doesn't |
| CWE-434 | Unrestricted File Upload | Upload without type check, extension check only (not content), no virus scan |
| CWE-476 | Null Pointer Dereference | Dereffing without null check in language without null safety |
| CWE-732 | Incorrect Permission Assignment | World-writable files, overly permissive S3 buckets, IAM `*` actions |
| CWE-798 | Hardcoded Credentials | API keys, passwords, tokens committed to repo or hardcoded in source |
| CWE-863 | Incorrect Authorization | Auth check exists but uses wrong logic (e.g., checks user but not resource owner) |
| CWE-1321 | Prototype Pollution | `Object.assign` / spread of untrusted data into `__proto__` |

## Finding format (required for security)

```
Title: [vuln class] in [component]
Severity: Critical | Major | Minor | Trivial
CWE: CWE-XXX
File: path/to/file.ext:LINE
Description: One paragraph, concrete.
Impact: What an attacker gains. Be specific.
Recommendation: Minimal fix.
Receipts: Concrete repro input OR code-trace from entry → fault site
References: Link to OWASP / CWE / advisory
```

## Verification rules (Verification Gate)

For Critical/Major security findings, ONE of these must be true:

1. **Concrete repro** — literal payload that triggers the vuln (e.g., `curl -d "id=' OR 1=1--"`)
2. **Full code trace** — show entry → fault, naming every intermediate function and citing line numbers. Crucially: confirm NO upstream validator strips the malicious input.
3. **Upstream CVE/advisory** — quote the advisory + show the vulnerable version is actually used

Without one of these → demote to Minor, file under Unverified Suspicions.

## What this checklist is NOT

- Not a comprehensive security audit. Live audits need threat modeling and full data-flow analysis.
- Not a substitute for SAST/DAST tools — it catches patterns those tools miss (logic flaws, design issues), not the reverse.
- Not an excuse to flag every `eval` — context matters. Internal-only eval on hardcoded strings is not a finding.
