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
| **Third-party action pinning** | External actions MUST be pinned to a full commit SHA — never float on `@main`, `@master`, or broad tags |
| **No unsafe PR triggers** | Do NOT use `pull_request_target` for untrusted code execution, build, test, or artifact upload paths |
| **Secrets never exposed to forks** | Fork PR workflows run without repo secrets, write tokens, publish steps, or deployment credentials |
| **Secret scanning is mandatory** | Public repos run automated secret scanning on push/PR; findings are blockers, not warnings |
| **Dependency updates are automated** | Public repos include dependency update automation for every ecosystem in use |
| **Vulnerability scanning is mandatory** | `security.yml` MUST run the appropriate scanner(s) for every language in the repo; critical/high CVEs in direct deps are build blockers |

### Vulnerability scanning in `security.yml`

Run the appropriate scanner for each language present in the repo. All scanners run in `security.yml` on push and pull_request. A critical or high CVE in a direct dependency is a hard build failure — not a warning.

| Language | Scanner | Command |
|----------|---------|---------|
| Go | govulncheck | `govulncheck ./...` |
| Rust | cargo audit | `cargo audit` |
| Node / TypeScript | npm audit | `npm audit --audit-level=high` |
| Container images | Trivy | `trivy image --exit-code 1 --severity CRITICAL,HIGH {image}` |

See `~/.claude/memory/security_conventions.md` for CVE database paths, pre-commit checks, and the full vulnerability scanning policy.

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
