---
name: CI/CD conventions
description: Rules for GitHub Actions workflows, branch protection, release integrity, and dependency automation in CasjaysDev projects
type: user
---

## General Rules

| Rule | Description |
|------|-------------|
| **NEVER use Makefile in CI** | Workflows have explicit commands with all env vars |
| **Multi-platform parity** | GitHub/Gitea/Jenkins must match — same platforms, same env vars, same logic |
| **VERSION precedence** | `release.txt` wins when present; otherwise use the workflow/build-specific fallback (tag, beta timestamp, etc.) |
| **LDFLAGS** | `-s -w -X 'main.Version=...' -X 'main.CommitID=...' -X 'main.BuildDate=...' -X 'main.OfficialSite=...'` |
| **Docker builds on every push** | Any branch push triggers Docker image build |
| **Docker tags** | Any push → `devel`, `{commit}`; beta → adds `beta`; tag → `{version}`, `latest`, `YYMM`, `{commit}` |
| **Workflow permissions** | Default to read-only / least privilege; grant write only to the specific release/publish job that needs it |

## Workflow Permissions

Set `contents: read` at the workflow level as the read-only baseline. Grant write permissions only on the specific job that performs the release or publish step — never workflow-wide.

| Permission | Scope | Why |
|------------|-------|-----|
| `contents: read` | All jobs (baseline) | Checkout |
| `contents: write` | Release job only | Create GitHub release, upload assets |
| `packages: write` | Release job only | Push images to `ghcr.io` |
| `id-token: write` | Release job only | OIDC token for Sigstore/cosign artifact signing |
| `attestations: write` | Release job only | GitHub artifact attestation (SBOM, provenance) |

```yaml
# Workflow-level: read-only baseline
permissions:
  contents: read

jobs:
  build:
    # Inherits read-only — no overrides needed
    runs-on: ubuntu-latest
    ...

  release:
    needs: build
    permissions:
      contents: write      # create GitHub release + upload assets
      packages: write      # push to ghcr.io
      id-token: write      # OIDC token for cosign signing
      attestations: write  # GitHub artifact attestations (SBOM, provenance)
    ...
```

Third-party registry publishing uses repository secrets, not GitHub token permissions:
- npm → `NODE_AUTH_TOKEN` secret
- crates.io → `CARGO_REGISTRY_TOKEN` secret

---

## Workflow Job Ordering

GitHub Actions runs all jobs in parallel by default. Use `needs:` to enforce ordering when a job depends on another's output or must not run if a prior job failed.

### `build.yml` job order

```
lint ──────────────┐
                   ├──→ build (needs: test) ──→ upload-artifacts (needs: build)
test ──────────────┘
  └──→ coverage (needs: test)
```

- `lint` and `test` run in parallel — neither depends on the other
- `build` `needs: [test]` — never produce artifacts from untested code
- `coverage` `needs: [test]` — parses test output
- `upload-artifacts` `needs: [build]` — only upload if build succeeded

### `release.yml` job order

```
build ──→ release (needs: build)
```

- `release` `needs: build` — never publish without a successful build + test
- `build` job uses read-only permissions; `release` job has elevated permissions scoped to it only
- `release.yml` always re-runs its own build inline — never relies on artifacts from a prior workflow run

### `security.yml` job order

```
secret-scan ──┐
vuln-scan    ──┤  (all parallel — no deps between them)
policy-check ──┘
```

Security jobs are independent — run in parallel. No `needs:` required within `security.yml`.

### Docker image ordering

Standard multi-stage Dockerfiles (single `docker/build-push-action` step) need no special job ordering — BuildKit handles stage sequencing internally.

When a custom builder or base image is published separately and referenced by a downstream image:

```yaml
jobs:
  build-base:
    # Builds and pushes ghcr.io/{org}/{name}-builder:latest
    ...
  build-app:
    needs: build-base   # app Dockerfile FROM references the builder image
    ...
```

### Cross-workflow ordering

GitHub Actions has no native cross-workflow `needs:`. Use branch protection instead:

- `build.yml` and `security.yml` run on push/PR — branch protection requires both to pass before merge
- `release.yml` triggers on tag — by the time a tag is cut, main has already passed build + security gates
- Never use `workflow_run` to chain `release.yml` after `build.yml` — it is complex, fragile, and bypasses branch protection intent

---

## Workflow Best Practices

### Concurrency groups

Every workflow that runs on push or pull_request must define a concurrency group to cancel stale runs:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Exception: release workflows (`release.yml`) must NOT cancel in progress — use `cancel-in-progress: false` to prevent a partial publish.

### Caching

Cache language dependencies between runs. Add to every build job:

**Go:**
```yaml
- uses: actions/cache@{sha}
  with:
    path: |
      ~/.cache/go-build
      ~/go/pkg/mod
    key: go-${{ runner.os }}-${{ hashFiles('**/go.sum') }}
    restore-keys: go-${{ runner.os }}-
```

**Rust:**
```yaml
- uses: actions/cache@{sha}
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      target/
    key: rust-${{ runner.os }}-${{ hashFiles('**/Cargo.lock') }}
    restore-keys: rust-${{ runner.os }}-
```

Always pin `actions/cache` to a full commit SHA per the third-party pinning rule.

### Artifact retention

Always set an explicit retention period on `actions/upload-artifact` — never rely on the 90-day default:

```yaml
- uses: actions/upload-artifact@{sha}
  with:
    name: binaries
    path: binaries/
    retention-days: 7   # build artifacts; use 30 for release staging
```

Use 7 days for transient build artifacts; 30 days for release staging artifacts that may need re-download before a release is finalized.

### Coverage gates

`build.yml` must enforce a minimum coverage threshold. The threshold is defined in `{project_dir}/IDEA.md` under `## Business logic`. If not specified, default is 60%. CI must fail when coverage drops below the threshold — a passing build with uncovered code is a silent regression.

**Go:** use `go test -cover ./... | tee coverage.out` and parse the total; fail if below threshold.
**Rust:** use `cargo tarpaulin` or `cargo llvm-cov`; fail if below threshold.

## Security Requirements

| Rule | Description |
|------|-------------|
| **Third-party action pinning** | External actions MUST be pinned to a full commit SHA — never float on `@main`, `@master`, or broad tags; verify runtime and maintenance status on every SHA update |
| **No unsafe PR triggers** | Do NOT use `pull_request_target` for untrusted code execution, build, test, or artifact upload paths |
| **Secrets never exposed to forks** | Fork PR workflows run without repo secrets, write tokens, publish steps, or deployment credentials |
| **Secret scanning is mandatory** | Public repos run `truffleHog` on push/PR via `security.yml`; findings are blockers, not warnings. Use `trufflesecurity/trufflehog` (Apache-2.0, no license key). Never use `gitleaks` — requires a commercial license for org repos |
| **Dependency updates are automated** | Public repos include dependency update automation for every ecosystem in use |
| **Vulnerability scanning is mandatory** | `security.yml` MUST run the appropriate scanner(s) for every language in the repo; critical/high CVEs in direct deps are build blockers |

### Third-party Action Pinning

Every external action (`uses: owner/action@...`) MUST be pinned to a full commit SHA — never a mutable tag or branch:

```yaml
# Wrong — tag can silently change or be deleted
- uses: actions/checkout@v4

# Correct — SHA is immutable
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2
```

**When updating a pinned SHA**, verify three things:

1. **Action is still maintained** — check the upstream repo is not archived, deprecated, or abandoned
2. **Runtime is still supported** — open the action's `action.yml` at the new SHA and check `runs.using`; if it names a runtime that GitHub has deprecated or scheduled for removal, the action will silently fail after that date. Example: `node20` is removed from GitHub-hosted runners on **2026-09-16** — any action still on `node20` must be updated to a SHA where it has migrated to `node24` (all common `actions/*` and `docker/*` actions have already done so; see the Common Action Reference SHAs table below)
3. **No supply-chain change** — skim the diff between the old and new SHA; unexpected new dependencies, changed entrypoints, or network calls added to setup steps are red flags

Dependabot covers `github-actions` ecosystem updates automatically when `.github/dependabot.yml` is configured — but it only updates the SHA, not the runtime verification. The runtime check is always manual.

### Vulnerability scanning in `security.yml`

`security.yml` always runs on push and pull_request. Jobs are split into two tiers:

**Always-required jobs (every public repo, no conditions):**

| Job | Scanner | Notes |
|-----|---------|-------|
| `secret-scan` | truffleHog | `trufflesecurity/trufflehog@{sha}` — Apache-2.0, no license key; `fetch-depth: 0` required |
| `workflow-policy` | inline shell | Verifies all `uses:` lines are pinned to a 40-char SHA; blocks `pull_request_target` |

**Conditional jobs (only when the manifest file exists in the repo):**

| Job | Scanner | Condition | Command |
|-----|---------|-----------|---------|
| `vuln-scan` (Go) | govulncheck | `go.sum` present | `govulncheck ./...` |
| `vuln-scan` (Rust) | cargo audit | `Cargo.lock` present | `cargo audit` |
| `vuln-scan` (Node) | npm audit | `package-lock.json` present | `npm audit --audit-level=high` |
| `image-scan` | Trivy | Dockerfile present | `trivy image --exit-code 1 --severity CRITICAL,HIGH {image}` |

A critical or high CVE in a direct dependency is a hard build failure — not a warning. The `image-scan` job requires the image to be built first; run it after `docker/build-push-action` in the same job or declare `needs: build`.

See `~/.claude/memory/security_conventions.md` for CVE database paths, pre-commit checks, and the full vulnerability scanning policy.

## Common Action Reference SHAs

Verified node24 SHAs as of 2025-05-15. All common `actions/*` and `docker/*` actions have migrated directly to node24 (skipping node22). Update these when Dependabot opens a PR — always re-verify the runtime after updating.

| Action | Tag | SHA |
|--------|-----|-----|
| `trufflesecurity/trufflehog` | v3.95.3 | `37b77001d0174ebec2fcca2bd83ff83a6d45a3ab` |
| `actions/checkout` | v6.0.2 | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` |
| `actions/upload-artifact` | v7.0.1 | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `actions/download-artifact` | v8.0.1 | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` |
| `actions/cache` | v5.0.5 | `27d5ce7f107fe9357f9df03efb73ab90386fccae` |
| `actions/setup-go` | v6.4.0 | `4a3601121dd01d1626a1e23e37211e3254c1c06c` |
| `actions/setup-node` | v6.4.0 | `48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e` |
| `docker/login-action` | v4.1.0 | `4907a6ddec9925e35a0a9e82d7399ccc52663121` |
| `docker/build-push-action` | v7.1.0 | `bcafcacb16a39f128d818304e6c9c0c18556b85f` |
| `docker/metadata-action` | v6.0.0 | `030e881283bb7a6894de51c315a6bfe6a94e05cf` |
| `docker/setup-buildx-action` | v4.0.0 | `4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd` |
| `docker/setup-qemu-action` | v4.0.0 | `ce360397dd3f832beb865e1373c09c0e9f86d70a` |
| `softprops/action-gh-release` | v3.0.0 | `b4309332981a82ec1c5618f44dd2e27cc8bfbfda` |

## Branch Protection (Public Repos)

The default branch MUST be protected. Required rules:

- Pull requests required for normal changes
- Passing build/test/security checks before merge
- CODEOWNERS review for owned paths
- Force-push and branch-deletion protection disabled

Direct pushes to the default branch are forbidden except explicit maintainer emergency action. Emergency bypasses MUST be followed by an audit/fix pass.

## Required Workflows (Public Repos)

| Workflow | Purpose |
|----------|---------|
| `.github/workflows/build.yml` | Build, test, coverage, and repo validation |
| `.github/workflows/release.yml` | Tagged/manual release build and publish |
| `.github/workflows/security.yml` | Secret scanning, dependency/security checks, workflow policy checks |

All three workflows are required on every public repo regardless of language. `security.yml` always contains at minimum `secret-scan` (truffleHog) and `workflow-policy` (action pinning check); dependency vulnerability jobs are added only when the corresponding manifest files exist.

If the project also supports Gitea/Forgejo or Jenkins, the equivalent workflows/pipelines MUST enforce the same gates — not a weaker subset. CI MUST fail when required tests, coverage gates, secret scans, dependency checks, or release validation fail.

## Dependabot (Public Repos)

Public repos MUST define `.github/dependabot.yml`. Dependabot MUST cover, when used:

- Go modules
- GitHub Actions
- Docker / container base images

Security updates are high priority and MUST go through the same test/security gates as manual changes. AI MUST NOT silently change dependency strategy, ignore failing update PRs, or disable update automation to "get green."

## Release Integrity

- Tagged releases MUST publish a machine-readable checksum file for all release artifacts (SHA-256)
- Tagged releases MUST publish release notes describing the actual change set with breaking changes called out explicitly
- Public releases MUST include a release-level SBOM (`CycloneDX` or `SPDX JSON`)
- Where the platform supports it, releases MUST include build provenance / artifact attestation
- AI MUST NOT fake signatures, fake attestations, or claim a release is signed/verified when the required keys/platform support do not exist
- If signing or attestation is required but the necessary keys/permissions are unavailable: stop and ask, do not bypass
