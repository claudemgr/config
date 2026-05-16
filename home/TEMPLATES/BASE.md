# {PROJECT_NAME} Specification

**Name**: {project_name}

**About this file:** `BASE.md` is the generic fallback template. When applied to a project, this file is copied into the project as `AI.md`. Throughout this document, all references to `AI.md` refer to that resulting file in a real project. Replace this with a language-specific template (e.g. `~/.claude/TEMPLATES/go/SERVER.md`) once the project's language and shape are known.

**Note:** `{PROJECT_NAME}` and `{project_name}` in this file are reference tokens, not setup-time text replacements. Their values are resolved from `IDEA.md ## Project variables` while `AI.md` remains read-only.

---

# PROJECT DESCRIPTION

**See `IDEA.md` for project-specific details.**

---

# SOURCE OF TRUTH AND IDEA.md PRECEDENCE

**See `IDEA.md` for features, data models, and business rules.**

IDEA.md is the project PLAN. AI.md (this file) is the SOURCE OF TRUTH.

| File | Role | Update When |
|------|------|-------------|
| **AI.md** | SOURCE OF TRUTH — implementation rules | Optional→required policy changes only |
| **IDEA.md** | PROJECT PLAN — must follow AI.md | Features change, project variables change |

**Rule:** If IDEA.md conflicts with AI.md, AI.md wins. Fix IDEA.md.

## IDEA.md Required Layout

**Every IDEA.md MUST have exactly these three top-level sections, in this order:**

```markdown
## Project description

(Full project description — what the project is, who uses it, what problem it solves.)

## Project variables

(All project variables in `key: value` form. Required keys at minimum: `project_name`,
`project_org`, `internal_name`, `internal_org`. Add more as the project needs — `app_name`,
`official_site`, `maintainer_name`, `maintainer_email`, `module_path`, `language`, etc.)

Example:

    project_name:  mytool
    project_org:   casjay
    internal_name: mytool        # FROZEN — set once at first-time setup, never edit
    internal_org:  casjay        # FROZEN — set once at first-time setup, never edit
    language:      go            # primary implementation language
    official_site: https://mytool.example.com

## Business logic

(Full business spec — the WHAT, not the HOW. Features, data models, user flows,
permission rules, business invariants, platform targets, input modes, accessibility,
security assumptions, and any exceptions.)
```

**Rules for `## Project variables`:**
- One variable per line: `key: value`
- Keys are **lower_snake_case** only
- Never guess values: use commands and existing files
- If a placeholder referenced by AI.md has no entry in `## Project variables`, setup MUST stop and ask instead of inventing a value
- `internal_name` and `internal_org` are frozen forever once set — warn the user loudly when setting them for the first time

**Rules for `## Business logic`:**
- It MUST define the actual product scope for THIS project — not generic boilerplate
- It MUST state which surfaces exist: GUI, TUI, CLI, server, library, or a subset
- It MUST define user flows, stored data, trust boundaries, abuse cases, and platform constraints
- Language-specific exceptions and deviations from AI.md rules MUST be documented here

---

# PART 0: CRITICAL RULES - READ FIRST

## THIS IS A STRICT SPECIFICATION — NOT GUIDELINES

- Every item in this specification MUST be followed exactly unless explicitly marked optional
- This is not a suggestion document
- There are no silent exceptions
- If the spec says X, do X — not "improved X"
- If something seems wrong, follow it and flag it; do not silently rewrite intent

## ⚠️ CRITICAL: File Paths and Project Root

- All paths are relative to the project root unless explicitly noted
- Do not scatter top-level files unnecessarily
- Runtime-generated files are not committed
- AI must not move the project root or invent sibling repositories

## ⚠️ CRITICAL: AI.md is the Source of Truth

- `AI.md` is read-only during routine work
- `IDEA.md` is where project-specific values and product rules live
- Loader files (`CLAUDE.md`, `.claude/CLAUDE.md`) stay short and point back to `AI.md`
- If a loader file and `AI.md` disagree, `AI.md` wins

## ⚠️ CRITICAL: Language is Determined by IDEA.md

This is a generic template. The implementation language, toolchain, and build system are defined by `IDEA.md ## Project variables` (`language:` key). Before writing any code:

1. Read `IDEA.md` to determine the language
2. Check whether a language-specific template exists in `~/.claude/TEMPLATES/{language}/` and recommend upgrading AI.md to it
3. Apply the global `~/.claude/CLAUDE.md` language constraints for the detected language
4. If `language:` is missing from IDEA.md, ask — never assume

## ⚠️ CRITICAL: Single Coherent Product

The deliverable is **one self-contained artifact** (binary, package, library, or service — defined by IDEA.md). The artifact must function correctly on first run with zero external setup beyond documented prerequisites.

## ⚠️ CRITICAL: Docker for All Builds

The language toolchain MUST NOT run on the host machine. All builds, tests, lint, and format checks execute inside a project-provided Docker container using an official language image (`golang:alpine`, `rust:alpine`, `node:alpine`, etc.). Host role: edit files, run version control, orchestrate Docker.

## ⚠️ CRITICAL: Keep Documentation in Sync

Update these when their subject changes:
- `IDEA.md` when features or variables change
- `README.md` when install, usage, or packaging changes
- `LICENSE.md` when dependencies or attribution changes
- CI/CD docs or scripts when release mechanics change

## Licensing & Features

| Rule | Description |
|------|-------------|
| **MIT License** | All project code is MIT licensed unless IDEA.md explicitly states an additional compatible license policy |
| **3rd party attribution** | All third-party licenses are listed in `LICENSE.md` |
| **GPL / AGPL / LGPL denied by default** | Static linking would relicense the binary away from MIT; allowed only via a documented IDEA.md exception |
| **Free & open source** | No paid tiers, enterprise gating, or artificial feature segmentation |
| **No activation gates** | No license keys, phone-home unlocks, or paywalled code paths |

**NEVER implement:**
- upgrade/paywall prompts for core functionality
- telemetry-based licensing enforcement
- artificial limits used for monetization

---

# PART 1: PROJECT FILES & GOVERNANCE

## Project Files

| File | Purpose | Update When |
|------|---------|-------------|
| **AI.md** | Implementation spec (HOW) — SOURCE OF TRUTH | Optional→required rule changes only |
| **IDEA.md** | Project plan (WHAT) | Features or variables change |
| **TODO.AI.md** | Task tracking (AI-owned) | Tasks added/completed |
| **TODO.md** | Task tracking (human-owned) | AI may mark done; never delete/empty |
| **PLAN.AI.md** | Implementation plan (AI-owned) | Planning new work |
| **PLAN.md** | Implementation plan (human-owned) | AI may mark done; never rewrite wholesale |
| **README.md** | User-facing install/usage docs | Usage changes |
| **LICENSE.md** | Project + dependency licenses | Dependency set changes |
| **release.txt** | Canonical release version when present | Release version changes |
| **site.txt** | Optional official site/homepage URL | Official site changes |

## Mandatory Compliance Schedule

| When | Action | Purpose |
|------|--------|---------|
| Before each task | Read only the spec parts relevant to what you are about to implement — do not pre-load speculatively | Prevent token waste |
| Every 3–5 changes | Stop and verify against spec | Catch drift early |
| Before task completion | Full compliance check | Ensure correctness |
| When uncertain | Read that specific section — never guess | Accuracy without waste |

## Self-Validation Loop

**AI MUST verify its own work with real tools before reporting a task as done.**

| Change type | How to verify |
|-------------|---------------|
| Logic / library | Run the test suite inside the container; compare output against expected |
| CLI binary | Run in container; exercise flags including `--help`/`--version`; check stdout, stderr, exit code |
| Build | Build the artifact inside Docker; confirm exit 0 and artifact is produced |
| Bug fix | Reproduce the bug first, then verify the fix makes it disappear |
| Configuration | Start with the new config; verify defaults; verify validation rejects bad input |
| CI/CD | Run the workflow on a branch; verify each job's exit status |
| Documentation | Render locally; verify links and code samples work |

**Iteration rules:**
- A failed check is data, not failure — adjust and re-run until green
- Never report "done" while any verification is still red
- If a check reveals the change is wrong in a way that can't be patched, revert and re-plan

## Loader Files

| Tool | Primary Loader | Alternate Loader |
|------|----------------|------------------|
| Claude Code | `CLAUDE.md` | `.claude/CLAUDE.md` |

**Loader rule:** loader files stay short. Long-form content belongs in `IDEA.md` (product) and `AI.md` (implementation policy).

---

# PART 2: APPLICATION MODEL

## Product Model

The artifact type, surfaces, and architecture are defined in `IDEA.md ## Business logic`. This template does not prescribe a specific model — IDEA.md does. Before implementing anything:

1. Read `IDEA.md ## Business logic` to determine: artifact type (binary, library, service, package), target surfaces (GUI, TUI, CLI, API, web), deployment model (self-hosted, cloud, embedded), and platform targets
2. Apply the single-coherent-product rule: shared core logic with thin surface adapters where multiple surfaces exist
3. If the artifact type is unclear or not stated in IDEA.md, ask — never assume

## Architectural Principles

Regardless of language or artifact type:

- **Single responsibility** — one coherent product; no unrelated subsystems bundled together
- **Shared core** — business logic lives in a shared layer, not duplicated per surface
- **Thin adapters** — UI/API/CLI layers are adapters over shared business rules
- **Self-contained** — the artifact runs on first use with zero config required (sensible defaults); user config is optional and additive
- **No runtime fetch** — all required assets are bundled or embedded at build time; no CDN/network fetch on first run

## Binary / Artifact Naming

Distribution artifacts follow:

```
{project_name}-{platform}-{arch}{.ext}
```

| Token | Values |
|-------|--------|
| `{platform}` | `linux`, `windows`, `macos`, `freebsd` (normalized — not raw OS values) |
| `{arch}` | `x86_64`, `aarch64`, `armv7`, `i686` |
| `{.ext}` | `.exe` on Windows; empty elsewhere |

Local/dev artifact name: `{project_name}` (no platform/arch suffix).
Checksum files: `{artifact}.sha256`.

---

# PART 3: BUILD, TOOLCHAIN, AND PACKAGING

## Docker Rule (Mandatory)

Docker is **REQUIRED**. The language toolchain MUST NOT run on the host.

### Required Docker Assets

```text
docker/
├── Dockerfile          # builds the dev/build/test image using official alpine language image
├── compose.yaml        # services: dev (build/test/run), runtime (optional)
├── entrypoint.sh       # sets non-root UID/GID, prepares cache dirs
└── README.md           # how to build, run tests, run the app
```

### Mandatory Image Properties

- Base image: official language alpine variant (e.g., `golang:alpine`, `rust:alpine`, `node:alpine`) — rolling, never pinned to a version tag
- Non-root user matching host UID/GID by default
- Language toolchain cache mounted as named volumes
- `CGO_ENABLED=0` for Go; static linking for Rust; equivalent for other languages

### Forbidden

- Running the language toolchain directly on the host
- Treating Docker as "CI-only" or "release-only"
- `--privileged` or `--net=host` without documented justification
- `docker run` without `--rm` for build/test containers

## Build Rules

- Release builds strip debug symbols and produce minimal artifacts
- Cross-compilation targets at minimum: `linux/amd64`, `linux/arm64`
- The final artifact MUST be a single statically linked binary (or equivalent self-contained package) per target
- All runtime assets embedded at build time — never fetched at runtime
- A static/self-contained check runs as part of CI

## Makefile

The project MUST have a `Makefile` with at minimum these targets:

| Target | Purpose |
|--------|---------|
| `make build` | Build the artifact inside Docker |
| `make test` | Run the test suite inside Docker |
| `make lint` | Run the linter inside Docker |
| `make clean` | Remove build artifacts |
| `make dev` | Start a development shell or dev server inside Docker |
| `make release` | Build release artifacts for all targets |

---

# PART 4: PRIVILEGE ESCALATION & SYSTEM INTEGRATION

## Core Rule

Privilege escalation is allowed but **optional** and only when the user explicitly requests it.

## NEVER Do

- Never auto-run `sudo`, `pkexec`, UAC elevation, or similar without explicit user request
- Never silently switch from user-scope to system-scope install
- Never require elevation for normal app launch, per-user config, or per-user updates

## Default Scope Rule

Default to **user scope**: user config, user data, user cache, per-user integrations.

## Path Rule

On-disk paths use the frozen pair `{internal_org}` and `{internal_name}` only — never the mutable `{project_org}` / `{project_name}`. This protects user data across project/org renames.

| Purpose | Linux / BSD | macOS | Windows |
|---------|-------------|-------|---------|
| Config | `~/.config/{internal_org}/{internal_name}/` | `~/Library/Application Support/{internal_name}/config/` | `%AppData%\{internal_org}\{internal_name}\config\` |
| Data | `~/.local/share/{internal_org}/{internal_name}/` | `~/Library/Application Support/{internal_name}/data/` | `%LocalAppData%\{internal_org}\{internal_name}\data\` |
| Cache | `~/.cache/{internal_org}/{internal_name}/` | `~/Library/Caches/{internal_name}/` | `%LocalAppData%\{internal_org}\{internal_name}\cache\` |
| Logs | `~/.local/state/{internal_org}/{internal_name}/logs/` | `~/Library/Logs/{internal_name}/` | `%LocalAppData%\{internal_org}\{internal_name}\logs\` |

---

# PART 5: VERSION, SITE, AND BUILD METADATA

## `release.txt` (Canonical Version)

- Single-line file at project root containing the canonical version string
- Use semantic versioning (`MAJOR.MINOR.PATCH`) unless IDEA.md documents another scheme
- CI/CD and release scripts MUST read version from `release.txt`, not invent one
- Keep in sync with the language module/package version declaration (`go.mod`, `Cargo.toml`, `package.json`, etc.)

## `site.txt` (Optional)

- Single-line file containing the official homepage URL when applicable
- Embedded into the binary at build time via `-ldflags` or equivalent

## Build Metadata Injection

Inject at build time (via `-ldflags`, `build.rs`, `build.js`, or equivalent):

| Variable | Default | Source |
|----------|---------|--------|
| `Version` | `dev` | `release.txt` |
| `CommitID` | `unknown` | `git rev-parse --short HEAD` |
| `BuildDate` | `unknown` | `date -u +%Y-%m-%dT%H:%M:%SZ` |
| `OfficialSite` | `` | `site.txt` (if present) |

---

# PART 6: SECURITY & PRIVACY

## Security Defaults

- **Fail closed** — when in doubt, deny and explain; never silently allow
- **Least privilege** — request only permissions actually needed; drop them as soon as no longer needed
- **No security through obscurity** — assume the attacker knows your code; security must hold even so
- **Defense in depth** — layer authentication, authorization, input validation, output encoding, rate limiting independently
- **Parameterized queries** — never interpolate user input into SQL, shell commands, or template strings
- **Constant-time comparison** — for all credential/token comparison operations
- **No hardcoded secrets** — credentials via environment variables or a secrets manager only

## Rate Limiting

All auth endpoints (login, password reset, OTP, token refresh) must have rate limiting with exponential backoff and lockout.

## Audit Logging

Security-relevant events (auth success/failure, permission changes, admin actions, data exports) must be logged. Logs are append-only and never contain raw credentials.

## Dependency Security

Run `govulncheck` (Go) / `cargo audit` (Rust) / `npm audit` (Node) / equivalent before adding any dependency and before committing. Never ship a critical/high CVE in direct dependencies.

## Password Hashing

**Argon2id only** — never bcrypt, never scrypt, never MD5/SHA for passwords.

---

# PART 7: TESTING & QUALITY

## Test Requirements

- Every non-trivial function has at least one test
- Tests cover the happy path, edge cases, and error paths
- New behavior requires a test that fails before and passes after the fix
- Tests run inside Docker — never on the host toolchain

## Quality Gates

All of these must be green before committing:

| Check | Tool |
|-------|------|
| Formatting | Language formatter (`gofmt`, `rustfmt`, `prettier`, etc.) |
| Linting | Language linter (`golangci-lint`, `clippy`, `eslint`, etc.) |
| Tests | Language test runner (`go test`, `cargo test`, `jest`, etc.) |
| Security | Vulnerability scanner (`govulncheck`, `cargo audit`, `npm audit`, etc.) |
| Build | Artifact builds without error |

**Zero tolerance** — lint warnings are treated as errors in CI.

---

# PART 8: CI/CD, RELEASES, AND AUTOMATION

## CI Requirements

The project MUST have CI that runs on every push and pull request:

- Format check
- Lint
- Test suite
- Build (all target platforms)
- Security/vulnerability scan
- Static-binary self-check (confirm artifact has no unexpected dynamic dependencies)

## Release Checklist

Before tagging a release:

- [ ] All CI checks green on main
- [ ] `release.txt` updated to new version
- [ ] `IDEA.md` up to date with any new features
- [ ] `README.md` up to date with any usage changes
- [ ] `LICENSE.md` up to date with any new dependencies
- [ ] Artifacts built for all target platforms
- [ ] SHA-256 checksums generated for all artifacts
- [ ] SBOM generated
- [ ] Release notes written

## GitHub Actions

Third-party Actions must be pinned to a full commit SHA — never a tag (`uses: actions/checkout@v4` is forbidden; `uses: actions/checkout@{sha}` is required).

---

# PART 9: DOCUMENTATION & LICENSE

## README.md

Must contain at minimum:

- Project description (one paragraph)
- Installation instructions
- Basic usage with examples
- Configuration reference (or link to one)
- License statement

## LICENSE.md

Must contain:

- Full text of the project license (MIT by default)
- Attribution for all third-party dependencies with their licenses
- Any GPL/AGPL/LGPL exceptions documented per PART 0

## In-Code Documentation

- All exported/public symbols have documentation comments
- Complex logic has inline explanation comments
- No commented-out code — use git history

---

# PART 10: CHECKLISTS

## New Project Checklist

- [ ] `IDEA.md` created with all required sections and variables
- [ ] `AI.md` in place (this file, or a language-specific upgrade)
- [ ] `CLAUDE.md` is a short loader pointing at `AI.md` and `IDEA.md`
- [ ] `README.md` created
- [ ] `LICENSE.md` created (MIT + dependency attribution)
- [ ] `.gitignore` created
- [ ] `release.txt` created (`0.1.0`)
- [ ] `docker/Dockerfile` created and builds successfully
- [ ] `docker/compose.yaml` created
- [ ] `docker/entrypoint.sh` created
- [ ] `Makefile` created with required targets
- [ ] CI workflow created
- [ ] `TODO.AI.md` generated with PART references on every item

## Pre-Commit Checklist

- [ ] Format check passes
- [ ] Lint passes (zero warnings)
- [ ] Tests pass
- [ ] Build succeeds
- [ ] No secrets, tokens, or credentials in diff
- [ ] No hardcoded machine-specific values
- [ ] No TODO/FIXME/HACK in committed code
- [ ] No commented-out code
- [ ] Documentation updated if behavior changed

## Pre-Release Checklist

- [ ] All CI checks green
- [ ] `release.txt` updated
- [ ] Artifacts built and checksummed for all targets
- [ ] SBOM generated
- [ ] Release notes written

---

# PART 11: IDEA.md REFERENCE

## Minimal IDEA.md

```markdown
## Project description

{project_name} is a … (one sentence elevator pitch).

(Full description: what it does, who uses it, what problem it solves.)

## Project variables

project_name:  {project_name}
project_org:   {project_org}
internal_name: {internal_name}   # FROZEN
internal_org:  {internal_org}    # FROZEN
language:      {language}        # e.g. go, rust, typescript, python
official_site: {official_site}   # optional

## Business logic

### Surfaces

(Which of these exist: GUI / TUI / CLI / REST API / gRPC / library / other)

### Core features

(Bullet list of what the product does)

### Data model

(What data is stored, where, in what format)

### User flows

(Step-by-step descriptions of how users interact with the product)

### Trust boundaries

(What is trusted: authenticated session, signed payload, internal network, etc.)

### Platform targets

(Which OS/arch combinations are supported)

### Security assumptions and exceptions

(Any intentional deviations from default security rules, with justification)
```
