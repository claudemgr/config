---
name: Security conventions
description: Enumeration mitigation, GeoIP, CVE/dependency scanning, blocklists, and SECURITY.md rules — operational security for server and library projects
type: user
---

## Enumeration Mitigation

**The goal:** an attacker who probes your auth surface learns nothing about which accounts exist, how many exist, or what your ID scheme looks like.

### Identical responses for auth failures

Both "wrong password" and "no such user" states MUST return the same user-visible message and the same HTTP status:

| Error Type | User Sees | Log Contains |
|------------|-----------|--------------|
| Login — wrong password | "Invalid credentials" | `auth_failure: user_id=123, reason=invalid_password` |
| Login — no such user | "Invalid credentials" | `auth_failure: email=[redacted], reason=user_not_found` |
| Password reset — email not registered | "If an account exists, a reset email has been sent" | `password_reset: email=[redacted], reason=user_not_found` |
| Account lookup / profile fetch | 404 only when the caller is the owner or an admin | `authz_failure: user_id=..., resource=profile` |

Rules:
- **Never reveal to users:** whether a username/email exists, database structure, internal IPs/hostnames, stack traces, dependency versions, or the specific reason for auth failure
- **Constant-time comparison** — use `crypto/subtle.ConstantTimeCompare` (Go) or `subtle::ConstantTimeEq` (Rust) for credential checks; timing differences can confirm existence even when messages are identical
- **Opaque IDs** — prefer UUIDs (v4 or v7) over sequential integers for any user-visible entity ID; sequential IDs enumerate record counts and insertion order

### Rate limiting on auth-adjacent endpoints

Apply rate limits to every endpoint that reveals account state or touches credentials. Defaults — all configurable in `IDEA.md` per project:

| Endpoint | Default Limit | Window | Response |
|----------|--------------|--------|----------|
| Login attempts | 5 | 15 min | 429 + lockout |
| Password reset requests | 3 | 1 hour | 429 + silent (no email hint) |
| Registration | 5 | 1 hour | 429 |
| File upload | 10 | 1 hour | 429 |
| API (unauthenticated) | Configurable | 1 min | 429 + Retry-After |
| API (authenticated) | Configurable | 1 min | 429 + Retry-After |

- Always include a `Retry-After` header (seconds) on 429 responses
- Silent mode for password reset: never confirm or deny whether an email was sent; always return the same message
- CAPTCHA: apply only after N consecutive failures, never on first try

---

## GeoIP

GeoIP is a **risk signal** — a hint that helps layer defense. It is never the sole access control.

**Why not sole control:** VPNs and proxies trivially bypass country checks. GeoIP is meaningful when combined with other signals (failed auth, unusual patterns, known bad ASNs), not as a standalone gate.

### Database

| Field | Value |
|-------|-------|
| Source | [ip-location-db](https://github.com/sapics/ip-location-db) (jsDelivr CDN, MIT licensed) |
| Formats | ASN (`.mmdb`), country (`.mmdb`), city (`.mmdb`) |
| Storage path | `{data_dir}/security/geoip/` |
| Update cadence | Daily — use a built-in scheduler, not host cron |
| On first run | Download database before serving any GeoIP-dependent request |

### Middleware order

GeoIP applies **after** the allowlist. Allowlisted IPs bypass blocklist, rate limit, and GeoIP — they do NOT bypass authentication or authorization.

```
Allowlist(4) → RateLimit(6) → GeoIP(7) → Auth(8+)
```

Numbers match a priority-ordered middleware chain; adapt to your framework's conventions.

### Configuration

- `deny_countries`: ISO 3166-1 alpha-2 list — block these countries
- `allow_countries`: whitelist mode — only allow these countries (overrides deny)
- Both default to empty (off); opt-in from admin panel or config file
- Document the active policy in `{project_dir}/IDEA.md` for any production deployment that uses country blocking

### Privacy

IP-derived location is **PII under GDPR** and similar regulations in most jurisdictions:
- Never log a user's resolved country, city, or ASN alongside their user ID or email — treat it as transient signal only
- Do not persist IP-to-location mappings beyond the current request unless explicitly required and documented in `IDEA.md`
- Geo data used for blocking: log the block event (`geoip_block: ip=[redacted], country=XX`) but do not retain a location history per user

---

## CVE / Dependency Scanning

### Pre-flight before adding a dependency

Before adding any new third-party dependency, check its vulnerability status:

| Ecosystem | Command |
|-----------|---------|
| Go | `govulncheck ./...` (run inside Docker per Go conventions) |
| Rust | `cargo audit` (run inside Docker per Rust conventions) |
| Node | `npm audit` |
| Container images | `trivy image {image}:{tag}` |

Do not add a dependency with an unpatched critical or high CVE. If no unaffected version exists, document the decision and the mitigating controls in `{project_dir}/IDEA.md`.

### Pre-commit lint gate

Run the vulnerability scanner as part of the commit pre-flight (alongside the lint gate):
- Go: `govulncheck ./...` must exit 0
- Rust: `cargo audit` must exit 0
- Never commit with a known critical/high CVE in direct dependencies

### Database storage

| Database | Storage path | Source | Cadence |
|----------|-------------|--------|---------|
| NVD/NIST CVE feeds | `{data_dir}/security/cve/` | NIST NVD | Daily |
| Trivy DB | `{data_dir}/security/trivy/` | `ghcr.io/aquasecurity/trivy-db` | Daily |
| IP Blocklists | `{data_dir}/security/blocklists/` | Configurable per project | Daily |

Update all security databases on a built-in scheduler. Never depend on host cron or systemd timers.

---

## IP/Domain Blocklists

Blocklists complement rate limiting and GeoIP — they block known-bad IPs and domains outright:

- Storage: `{data_dir}/security/blocklists/` — separate files for IP and domain lists
- Sources: configurable per project; document chosen feeds in `IDEA.md`
- Update cadence: daily, via built-in scheduler
- Middleware order: Blocklist check runs after Allowlist (allowlisted IPs are not blocked) and before RateLimit and GeoIP
- On hit: return 403 with a generic message; log `blocklist_hit: ip=..., list=...` at INFO level

---

## SECURITY.md for Public Repos

Every public-facing repo MUST have `.github/SECURITY.md` defining:

- Supported versions or the supported release policy
- The security reporting path (email, HackerOne, etc.) — NOT a public issue tracker
- That vulnerabilities MUST NOT be filed as public bug reports
- Expected disclosure/response timeline (e.g. acknowledge within 48h, patch within 90 days)
- Links to `/.well-known/security.txt` and the project's contact page when those features exist

CODEOWNERS MUST list explicit owners for security-sensitive paths: workflows, Dockerfile/release files, auth/crypto/update code.
