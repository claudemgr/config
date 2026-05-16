---
name: CI/CD conventions
description: CI/CD rules for all supported providers — GitHub, GitLab, Gitea, Forgejo, Jenkins — including provider detection, workflow file locations, secret scanning, dependency updates, release integrity, and action pinning in CasjaysDev projects
type: user
---

## Multi-Provider CI/CD

Every project targets all five CI/CD providers. The goal is zero vendor lock-in: the same build, test, security, and release gates run correctly regardless of where the code is hosted.

### Philosophy

| Principle | Description |
|-----------|-------------|
| **Same gates, different syntax** | Build/test/security/release logic is identical across all providers; only the YAML dialect and runner format differ |
| **No lock-in** | A project that only works on GitHub is not portable — all five workflow formats must be present and passing |
| **Jenkinsfile is the escape hatch** | Jenkins runs anywhere, with or without a hosted CI provider; every project ships a `Jenkinsfile` |
| **Renovate over Dependabot** | Renovate works on all five providers; Dependabot is GitHub-only. Use Renovate for new projects. Existing Dependabot configs are acceptable on GitHub-only repos |

### Provider Detection

Detect the provider from the git remote URL. For self-hosted instances, fall back to the API version endpoint:

```bash
remote=$(git remote get-url origin 2>/dev/null || echo "")
case "$remote" in
  *github.com*)  PROVIDER=github ;;
  *gitlab.com* | *gitlab.*) PROVIDER=gitlab ;;
  *forgejo.*)    PROVIDER=forgejo ;;
  *gitea.*)      PROVIDER=gitea ;;
  *)
    # Self-hosted: probe the API version endpoint
    base=$(printf '%s' "$remote" | sed -E 's|git@([^:]+):.*|\1|; s|https?://([^/]+)/.*|\1|')
    if curl -qsSf "https://$base/api/v4/version" 2>/dev/null | grep -q '"version"'; then
      PROVIDER=gitlab
    elif curl -qsSf "https://$base/api/v1/version" 2>/dev/null | grep -qi "forgejo"; then
      PROVIDER=forgejo
    elif curl -qsSf "https://$base/api/v1/version" 2>/dev/null | grep -q '"version"'; then
      PROVIDER=gitea
    else
      PROVIDER=unknown
    fi
    ;;
esac
```

For Forgejo vs Gitea (both expose `/api/v1/version`): Forgejo sets an `X-Forgejo-Version` response header and the version string often contains `+gitea-` (e.g. `7.0.0+gitea-1.21.0`). Check the header first.

### Workflow File Locations

| Provider | Workflow location | Syntax / runner |
|----------|------------------|-----------------|
| GitHub | `.github/workflows/*.yml` | GitHub Actions |
| GitLab | `.gitlab-ci.yml` | GitLab CI |
| Gitea | `.gitea/workflows/*.yml` | GitHub Actions (act runner) |
| Forgejo | `.forgejo/workflows/*.yml` | GitHub Actions (act runner) |
| Jenkins | `Jenkinsfile` | Declarative Pipeline (Groovy) |

Gitea and Forgejo use the act runner — their workflow syntax is GitHub Actions-compatible. The same YAML (modulo registry/secret variable names) usually works on GitHub, Gitea, and Forgejo with no changes.

### Required Workflow Set Per Provider

Every project must provide the equivalent of three gates on every provider:

| Gate | GitHub | GitLab | Gitea | Forgejo | Jenkins |
|------|--------|--------|-------|---------|---------|
| **Build + Test** | `build.yml` | `build` + `test` stages in `.gitlab-ci.yml` | `build.yml` | `build.yml` | `Build` + `Test` stages in `Jenkinsfile` |
| **Security** | `security.yml` | `security` stage | `security.yml` | `security.yml` | `Security` stage (parallel steps) |
| **Release** | `release.yml` | `release` stage (manual/tag-triggered) | `release.yml` | `release.yml` | `Release` stage (tag-triggered) |

### Action / Step Pinning Per Provider

| Provider | Pinning requirement |
|----------|-------------------|
| GitHub | `uses: owner/action@{40-char-sha}` — never a tag or branch |
| GitLab | Docker images pinned by digest: `image: alpine@sha256:{digest}` for production; template `include:` refs pinned to SHA |
| Gitea | Same as GitHub (act runner uses the same `uses:` syntax) |
| Forgejo | Same as GitHub (act runner) |
| Jenkins | Docker images pinned by digest; shared library versions locked in `Jenkinsfile` |

### Secret Scanning Per Provider

truffleHog is the mandatory scanner on all providers (Apache-2.0, no license key, never gitleaks):

| Provider | How to run truffleHog |
|----------|----------------------|
| GitHub / Gitea / Forgejo | `trufflesecurity/trufflehog@{sha}` composite action |
| GitLab | Docker job: `image: trufflesecurity/trufflehog:latest`, `script: trufflehog git file://. --since-commit HEAD~1 --fail` |
| Jenkins | Docker step: `docker.image('trufflesecurity/trufflehog:latest').inside { sh 'trufflehog git file://. --since-commit HEAD~1 --fail' }` |

Always run with `fetch-depth: 0` (GitHub/Gitea/Forgejo) or `GIT_DEPTH: 0` (GitLab) so the full commit history is scanned.

### Dependency Update Automation

**Renovate** is the recommended tool — it works on GitHub, GitLab, Gitea, Forgejo, and can be self-hosted:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "pinDigests": true,
      "automerge": false
    }
  ]
}
```

Place `renovate.json` at the repo root. Renovate updates GitHub Actions SHAs, Docker image digests, Go modules, Cargo deps, npm deps, and more — in a single tool across all providers.

Dependabot (`.github/dependabot.yml`) is acceptable for GitHub-only repos but must not be the sole update mechanism on a multi-provider project.

### Container Registry Per Provider

See `~/.claude/memory/github_conventions.md` → "Container Registry" for the full table. Summary:

| Provider | Registry |
|----------|---------|
| GitHub | `ghcr.io/{org}/{name}` |
| GitLab | `registry.gitlab.com/{group}/{project}` |
| Gitea / Forgejo | `{instance}/{org}/{name}` (OCI registry built in) |
| Self-hosted | Any OCI-compliant registry — configure via `REGISTRY` make variable |

Base/toolchain images always pull from `docker.io` regardless of provider.

### GitLab CI Structure (`.gitlab-ci.yml`)

```yaml
stages:
  - build
  - test
  - security
  - release

variables:
  CGO_ENABLED: "0"

build:
  stage: build
  image: golang:alpine
  script:
    - go build ./...

test:
  stage: test
  image: golang:alpine
  script:
    - go test ./...

secret-scan:
  stage: security
  image: trufflesecurity/trufflehog:latest
  variables:
    GIT_DEPTH: 0
  script:
    - trufflehog git file://. --since-commit HEAD~1 --fail

vuln-scan:
  stage: security
  image: golang:alpine
  script:
    - go install golang.org/x/vuln/cmd/govulncheck@latest
    - govulncheck ./...

release:
  stage: release
  rules:
    - if: $CI_COMMIT_TAG =~ /^v/
  script:
    - # build artifacts, checksums, SBOM, publish
```

Security jobs run in the same stage (parallel by default in GitLab CI).

### Jenkinsfile Structure

Every project ships a `Jenkinsfile` using the declarative pipeline syntax:

```groovy
pipeline {
    agent { docker { image 'golang:alpine' } }

    options {
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Build') {
            steps {
                sh 'CGO_ENABLED=0 go build ./...'
            }
        }
        stage('Test') {
            steps {
                sh 'CGO_ENABLED=0 go test ./...'
            }
        }
        stage('Security') {
            parallel {
                stage('Secret Scan') {
                    steps {
                        sh 'docker run --rm -v $(pwd):/repo trufflesecurity/trufflehog:latest git file:///repo --since-commit HEAD~1 --fail'
                    }
                }
                stage('Vuln Scan') {
                    steps {
                        sh 'go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...'
                    }
                }
            }
        }
        stage('Release') {
            when { tag 'v*' }
            steps {
                sh '# build artifacts, checksums, SBOM, publish'
            }
        }
    }
}
```

Language-specific: swap the `golang:alpine` agent image and the build/test/vuln commands for Rust (`rust:alpine`, `cargo build`, `cargo test`, `cargo audit`) or Node.

---

## General Rules

| Rule | Description |
|------|-------------|
| **NEVER use Makefile in CI** | Workflows have explicit commands with all env vars |
| **Multi-platform parity** | All five providers must match — same platforms, same env vars, same logic |
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

## Workflow Error Messaging

GitHub Actions surfaces failures in three ways — use the right one:

| Technique | When to use | Syntax |
|-----------|-------------|--------|
| `::error::` workflow command | Any pre-flight or validation failure — appears as a red annotation on the Actions summary page, not just in logs | `echo "::error::Tag 'foo' is not a valid tag"` |
| `::error file=...,line=N::` | When the failure is tied to a specific file (e.g., lint, format, policy check) | `echo "::error file=.github/workflows/release.yml,line=12::message"` |
| `echo "ERROR: ..." && exit 1` | Steps where the annotation is less important than a clear log line | Standard shell pattern |

Always write the message so a developer reading only the step name + message can understand what failed and what to do next — never output a bare non-zero exit with no explanation.

### Release pre-flight validation

The GitHub Releases API returns HTTP 422 with `"tag_name is not a valid tag"` when the tag does not exist in the repository at the time of the API call, or when the tag name is malformed. The correct fix is not to *validate* that the tag exists but for the **release job to own the tag** — delete it if it exists, then create it fresh. This ensures the tag always points to the correct commit and makes the workflow idempotent (re-runnable on failure).

The `release` job needs `contents: write` to push the tag — it already has this permission per the workflow permissions pattern.

```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2
  with:
    fetch-depth: 0   # required: full history needed to inspect and push tags

- name: Ensure release tag
  run: |
    ref="${{ github.ref }}"
    # Must be triggered by a tag push or workflow_dispatch with a tag input
    if [[ "$ref" != refs/tags/* ]]; then
      echo "::error::release.yml triggered on non-tag ref '$ref'. Releases require a tag push (refs/tags/v...)."
      exit 1
    fi
    tag="${ref#refs/tags/}"
    # Reject malformed tag names before touching the remote
    if printf '%s' "$tag" | grep -qP '[[:space:][:cntrl:]]'; then
      echo "::error::Tag '$tag' contains whitespace or control characters and is not a valid GitHub tag name."
      exit 1
    fi
    # Delete existing tag (local + remote) then recreate at current HEAD
    git tag -d "$tag" 2>/dev/null || true
    git push origin ":refs/tags/$tag" 2>/dev/null || true
    git tag "$tag"
    git push origin "refs/tags/$tag"
    echo "Tag '$tag' ensured at $(git rev-parse HEAD)"
```

## Release Integrity

- Tagged releases MUST publish a machine-readable checksum file for all release artifacts (SHA-256)
- Tagged releases MUST publish release notes describing the actual change set with breaking changes called out explicitly
- Public releases MUST include a release-level SBOM (`CycloneDX` or `SPDX JSON`)
- Where the platform supports it, releases MUST include build provenance / artifact attestation
- AI MUST NOT fake signatures, fake attestations, or claim a release is signed/verified when the required keys/platform support do not exist
- If signing or attestation is required but the necessary keys/permissions are unavailable: stop and ask, do not bypass
