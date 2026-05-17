---
name: Gitea conventions
description: Gitea-specific conventions for CasjaysDev projects — .gitea/workflows/ patterns, act runner, predefined variables, package registry, branch protection, and self-hosted setup. Load only when the project remote resolves to a Gitea instance.
type: user
---

## When to Load

Load this file when `git remote get-url origin` does NOT contain `github.com` or `gitlab.com`, and an API probe to `{host}/api/v1/version` returns a JSON body with a `"version"` field but does NOT return an `X-Forgejo-Version` response header (that header signals Forgejo, not Gitea).

---

## Workflow Location

Gitea uses the same act runner as GitHub Actions. Workflow files live at:

```
.gitea/workflows/ci.yml
.gitea/workflows/security.yml
.gitea/workflows/release.yml
```

Syntax is GitHub Actions-compatible with minor differences noted below. All standard CI/CD gates apply identically.

---

## Predefined Variables

Gitea exposes a GitHub-compatible variable set via the act runner:

| Variable | Value |
|----------|-------|
| `${{ gitea.sha }}` | Full commit SHA |
| `${{ gitea.ref }}` | Full ref (`refs/heads/main`, `refs/tags/v1.0.0`) |
| `${{ gitea.ref_name }}` | Short branch or tag name |
| `${{ gitea.repository }}` | `{owner}/{repo}` |
| `${{ gitea.repository_owner }}` | Owner login |
| `${{ gitea.server_url }}` | Instance URL (e.g. `https://gitea.example.com`) |
| `${{ gitea.token }}` | Short-lived job token (read-only by default) |
| `${{ gitea.actor }}` | Username who triggered the workflow |
| `${{ gitea.event_name }}` | `push`, `pull_request`, `schedule`, `workflow_dispatch` |
| `${{ gitea.workspace }}` | Runner workspace path |

Use `${{ gitea.* }}` instead of `${{ github.* }}` — they are structurally identical but the namespace differs.

---

## Workflow Skeleton

```yaml
name: CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4   # act runner resolves from gitea mirror or local cache
      - name: Build
        run: make build
```

**SHA pinning:** Gitea's act runner resolves actions from Gitea's own mirror of `actions/` repos (or a configured action cache server). Pin to a full commit SHA exactly as you would on GitHub:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

Never use a tag reference (`@v4`) — tags are mutable. Always pin to the commit SHA.

---

## Secret Scanning (truffleHog)

```yaml
secret-scan:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      with:
        fetch-depth: 0
    - name: truffleHog scan
      run: |
        docker run --rm -it \
          --name trufflehog-$RANDOM \
          -v "${{ gitea.workspace }}:/repo" \
          trufflesecurity/trufflehog:latest \
          git file:///repo --since-commit HEAD~1 --fail
```

truffleHog is Apache-2.0 — no license key required. Never substitute gitleaks (commercial license for org repos).

---

## Package Registry

Gitea has a built-in package registry supporting Docker, Go modules, npm, PyPI, Cargo, Helm, and more.

**Docker registry:**

```
{gitea_host}/{owner}/{repo}:{tag}
```

Login:

```bash
docker login {gitea_host} -u {username} -p {token}
```

In CI:

```yaml
- name: Login to Gitea registry
  run: |
    docker login "${{ gitea.server_url }}" \
      -u "${{ gitea.repository_owner }}" \
      -p "${{ secrets.GITEA_TOKEN }}"
- name: Build and push
  run: |
    IMAGE="${{ gitea.server_url }}/${{ gitea.repository }}:${{ gitea.sha }}"
    docker build -t "$IMAGE" .
    docker push "$IMAGE"
```

**Go module proxy:** Gitea acts as a Go module proxy at `{host}/api/packages/{owner}/go`. Configure with:

```bash
GONOSUMCHECK={gitea_host} GOFLAGS="-mod=mod" GOPROXY="https://{gitea_host}/api/packages/{owner}/go,direct"
```

---

## Branch Protection

Via Gitea API (v1):

```bash
# Protect main — require PR + passing status checks
curl -qsSf -X POST \
  -H "Authorization: token $GITEA_TOKEN" \
  -H "Content-Type: application/json" \
  "{host}/api/v1/repos/{owner}/{repo}/branches/main/protection" \
  -d '{
    "branch_name": "main",
    "enable_push": false,
    "enable_push_whitelist": false,
    "enable_status_check": true,
    "status_check_contexts": ["build", "security"],
    "required_approvals": 1,
    "dismiss_stale_approvals": true,
    "block_on_outdated_branch": true
  }'
```

Required status check context names must match the `name:` field of the job in the workflow.

---

## Pull Request Templates

Location: `.gitea/PULL_REQUEST_TEMPLATE.md`

```markdown
## Summary

<!-- What does this PR do? Link the issue it closes: Closes #N -->

## Changes

-

## Testing

<!-- How was this tested? Were tests added or updated? -->

## Checklist

- [ ] Tests added/updated
- [ ] `make test` passes locally
- [ ] No TODO/FIXME left in committed code
- [ ] SECURITY.md updated if this change is security-relevant
```

---

## CODEOWNERS

Location: `CODEOWNERS` (repo root) — same format as GitHub:

```
* @{project_org}
.gitea/workflows/ @{project_org}
SECURITY.md @{project_org}
docker/ @{project_org}
```

Enable in **Settings → Repository → Protected Branches → Require code owner review**.

---

## Release

Gitea has a native Releases API compatible with GitHub's:

```bash
# Create release via API
curl -qsSf -X POST \
  -H "Authorization: token $GITEA_TOKEN" \
  -H "Content-Type: application/json" \
  "{host}/api/v1/repos/{owner}/{repo}/releases" \
  -d "{
    \"tag_name\": \"$TAG\",
    \"name\": \"$TAG\",
    \"body\": \"Release $TAG\",
    \"draft\": false,
    \"prerelease\": false
  }"

# Upload asset
curl -qsSf -X POST \
  -H "Authorization: token $GITEA_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  "{host}/api/v1/repos/{owner}/{repo}/releases/{release_id}/assets?name={filename}" \
  --data-binary @{file}
```

In workflow:

```yaml
release:
  runs-on: ubuntu-latest
  if: startsWith(gitea.ref, 'refs/tags/v')
  steps:
    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
    - name: Validate tag
      run: |
        tag="${{ gitea.ref_name }}"
        if ! printf '%s' "$tag" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+'; then
          echo "::error::Tag '$tag' is not a valid semver tag (expected vX.Y.Z)"
          exit 1
        fi
    - name: Build release binaries
      run: make release
    - name: Create Gitea release
      env:
        GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
      run: |
        tag="${{ gitea.ref_name }}"
        curl -qsSf -X POST \
          -H "Authorization: token $GITEA_TOKEN" \
          -H "Content-Type: application/json" \
          "${{ gitea.server_url }}/api/v1/repos/${{ gitea.repository }}/releases" \
          -d "{\"tag_name\":\"$tag\",\"name\":\"$tag\",\"body\":\"Release $tag\"}"
```

---

## Dependency Updates (Renovate)

Gitea supports Renovate. Run as a scheduled workflow:

```yaml
renovate:
  runs-on: ubuntu-latest
  if: gitea.event_name == 'schedule'
  steps:
    - name: Self-hosted Renovate
      run: |
        docker run --rm -it \
          --name renovate-$RANDOM \
          -e RENOVATE_TOKEN="${{ secrets.RENOVATE_TOKEN }}" \
          -e RENOVATE_PLATFORM=gitea \
          -e RENOVATE_ENDPOINT="${{ gitea.server_url }}" \
          -e RENOVATE_REPOSITORIES="${{ gitea.repository }}" \
          renovate/renovate:latest
```

`renovate.json` at repo root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:base"],
  "platform": "gitea",
  "gitAuthor": "Renovate Bot <renovate@example.com>",
  "prCreation": "immediate",
  "automerge": false
}
```

---

## Self-Hosted Gitea Notes

- **act runner registration:** `act_runner register --instance {url} --token {token} --name {runner-name} --labels ubuntu-latest`
- **Action cache server:** set `[actions] DEFAULT_ACTIONS_URL = https://gitea.com` or self-host `gitea/act_runner` with a local action cache to avoid pulling from github.com
- **Version detection:** `GET /api/v1/version` → `{"version":"1.21.x"}` — no `X-Forgejo-Version` header = Gitea
- **OAuth2 apps:** Settings → Applications → OAuth2 Applications for external auth integrations
- **Webhook secret:** always set `secret` on webhooks; verify `X-Gitea-Signature` header (HMAC-SHA256)
