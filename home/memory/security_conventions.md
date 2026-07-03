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
| Source | [ip-location-db](https://github.com/sapics/ip-location-db) — npm `-mmdb` packages (MIT licensed) |
| Formats | ASN (`.mmdb`), country (`.mmdb`), city (`.mmdb`) |
| Storage path | `{data_dir}/security/geoip/` |
| Update cadence | Daily — use a built-in scheduler, not host cron |
| On first run | Download database before serving any GeoIP-dependent request |

MMDB files are distributed via npm scoped packages with a `-mmdb` suffix (e.g. `@ip-location-db/asn-mmdb`). Packages without the suffix are CSV-only. Download via jsDelivr CDN or npm tarball:

```
# jsDelivr CDN (scoped package format)
https://cdn.jsdelivr.net/npm/@ip-location-db/asn-mmdb/asn-ipv4.mmdb
https://cdn.jsdelivr.net/npm/@ip-location-db/asn-mmdb/asn-ipv6.mmdb
# IPv4+IPv6 combined
https://cdn.jsdelivr.net/npm/@ip-location-db/asn-mmdb/asn.mmdb

https://cdn.jsdelivr.net/npm/@ip-location-db/geolite2-country-mmdb/geolite2-country-ipv4.mmdb
https://cdn.jsdelivr.net/npm/@ip-location-db/geolite2-country-mmdb/geolite2-country-ipv6.mmdb
# combined
https://cdn.jsdelivr.net/npm/@ip-location-db/geolite2-country-mmdb/geolite2-country.mmdb

https://cdn.jsdelivr.net/npm/@ip-location-db/geolite2-city-mmdb/geolite2-city-ipv4.mmdb
https://cdn.jsdelivr.net/npm/@ip-location-db/geolite2-city-mmdb/geolite2-city-ipv6.mmdb
```

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

### Go Implementation

**Do NOT use `geoip2-golang`** (`github.com/oschwald/geoip2-golang`) with ip-location-db files. That library enforces an allowlist of MaxMind-branded `database_type` strings (`GeoLite2-ASN`, `GeoIP2-City`, etc.). ip-location-db uses its own type strings — `geoip2.Open()` returns `InvalidDatabaseError`.

**Use `maxminddb-golang`** (`github.com/oschwald/maxminddb-golang`) directly — the underlying low-level library with no type restriction.

#### `database_type` strings (embedded in the MMDB binary)

| File pattern | `database_type` |
|---|---|
| `asn-ipv4.mmdb` | `asn ipv4` |
| `asn-ipv6.mmdb` | `asn ipv6` |
| `asn.mmdb` (combined) | `asn ipvAll` |
| `*-country-ipv4.mmdb` | `country ipv4` |
| `*-country-ipv6.mmdb` | `country ipv6` |
| `*-country.mmdb` (combined) | `country ipvAll` |
| `*-city-ipv4.mmdb` | `city ipv4` |
| `*-city-ipv6.mmdb` | `city ipv6` |

#### Go struct definitions (tag names match actual MMDB field names)

```go
import "github.com/oschwald/maxminddb-golang"

// ASN lookup
type ASNRecord struct {
    ASN uint32 `maxminddb:"autonomous_system_number"`
    Org string `maxminddb:"autonomous_system_organization"`
}

// Country lookup
type CountryRecord struct {
    // ISO 3166-1 alpha-2
    CountryCode string `maxminddb:"country_code"`
}

// City lookup — all fields are present; empty string when not populated
type CityRecord struct {
    City        string  `maxminddb:"city"`
    CountryCode string  `maxminddb:"country_code"`
    Latitude    float64 `maxminddb:"latitude"`
    Longitude   float64 `maxminddb:"longitude"`
    Postcode    string  `maxminddb:"postcode"`
    // region / province
    State1      string  `maxminddb:"state1"`
    // sub-region
    State2      string  `maxminddb:"state2"`
    Timezone    string  `maxminddb:"timezone"`
}
```

#### Usage pattern

```go
db, err := maxminddb.Open(path)
if err != nil {
    return fmt.Errorf("open geoip db: %w", err)
}
defer db.Close()

ip := net.ParseIP("8.8.8.8")

var record ASNRecord
if err := db.Lookup(ip, &record); err != nil {
    return fmt.Errorf("geoip lookup: %w", err)
}
// record.ASN == 15169, record.Org == "Google LLC"
```

Use separate `db` handles for IPv4 and IPv6 files when splitting by protocol, or the combined `asn.mmdb` / `country.mmdb` for both. The combined files accept both address families.

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
- The security reporting path — GitHub private vulnerability reporting (`https://github.com/{project_org}/{project_name}/security/advisories/new`, the repo's Security tab → "Report a vulnerability") is the PRIMARY channel; the security email is a secondary/CC contact only, never the main way. NOT a public issue tracker
- That vulnerabilities MUST NOT be filed as public bug reports
- Expected disclosure/response timeline (e.g. acknowledge within 48h, patch within 90 days)
- Links to `/.well-known/security.txt` and the project's contact page when those features exist

CODEOWNERS MUST list explicit owners for security-sensitive paths: workflows, Dockerfile/release files, auth/crypto/update code.

---

## Security by Design

Security is first-class from day one — never bolted on after. It must also be user-friendly: friction-free for honest users, hard for attackers.

- **Secure default** — the safe path is the easy path. Insecure options require explicit opt-in; never make the user work harder to be secure
- **Fail closed** — when in doubt, deny and explain clearly; never silently allow
- **Least privilege** — request only the permissions actually needed; drop them as soon as they are no longer needed
- **Explicit trust boundaries** — document what is trusted (authenticated session, signed payload, internal network) and what is not; never assume
- **No security through obscurity** — assume the attacker knows your code, your schema, and your algorithm choices; security must hold even so
- **Defense in depth** — no single control is the last line; layer authentication, authorization, input validation, output encoding, and rate limiting independently
- **No security theater** — do not impose friction that punishes honest users without meaningfully stopping attackers (e.g. forced password rotation on a schedule unrelated to breach, CAPTCHA on low-risk flows, MFA on non-sensitive pages)
- **Clear security errors** — when a request is blocked or fails a security check, tell the user what happened and what to do next; never return a bare 403 or "access denied" with no context
- **Password hashing: Argon2id only** — never bcrypt, never scrypt, never MD5/SHA for passwords
- **Audit log security-relevant events** — auth success/failure, permission changes, admin actions, data exports; logs are append-only and never contain raw credentials

---

## Memory Safety

These apply to every line of code in every language:

- `unsafe` (Rust) / `import "unsafe"` (Go) requires a justification comment at the call site and a note in `{project_dir}/IDEA.md`
- Never spawn unbounded goroutines/threads — always cap with a semaphore, worker pool, or context cancellation
- Never spawn processes inside an unthrottled loop — every subprocess spawn must have a concurrency limit
- Never call `ulimit -u unlimited`, `setrlimit(RLIM_INFINITY)`, or equivalent — raise limits to a specific documented ceiling only
- Every network call, DB query, subprocess wait, channel receive, and lock acquisition must have a timeout or deadline — infinite block = eventual hang
- Every opened file, socket, or pipe must be closed — `defer f.Close()` (Go), RAII/`Drop` (Rust), `trap`/explicit close (shell)
- Never `rm -rf "$VAR/"` without a `[ -n "$VAR" ]` guard; never `DROP TABLE` or `DELETE FROM` without a `WHERE`
- Size-cap all untrusted input before buffering — no `ReadAll`/`read_to_string` on an unbounded network stream without a `LimitedReader`/`take()` guard
