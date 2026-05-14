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

## Security Requirements

| Rule | Description |
|------|-------------|
| **Third-party action pinning** | External actions MUST be pinned to a full commit SHA — never float on `@main`, `@master`, or broad tags |
| **No unsafe PR triggers** | Do NOT use `pull_request_target` for untrusted code execution, build, test, or artifact upload paths |
| **Secrets never exposed to forks** | Fork PR workflows run without repo secrets, write tokens, publish steps, or deployment credentials |
| **Secret scanning is mandatory** | Public repos run automated secret scanning on push/PR; findings are blockers, not warnings |
| **Dependency updates are automated** | Public repos include dependency update automation for every ecosystem in use |

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
