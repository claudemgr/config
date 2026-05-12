# 🤖 claudemgr/config

Claude Code configuration bootstrap — settings, agents, hooks, memory, and a one-line installer that gets any machine up to speed fast.

## 📦 What's Included

| Path | Purpose |
|------|---------|
| `install.sh` | Bootstraps a new machine: clones config, installs plugins and MCP servers |
| `home/CLAUDE.md` | Global Claude rules — communication, safety, code standards, commit workflow |
| `home/settings.json` | Claude Code user settings |
| `home/agents/` | Custom agent definitions (architect, debugger, code-reviewer, etc.) |
| `home/hooks/` | Hooks — `protect-host.sh` guards destructive operations |
| `home/memory/` | Persistent memory files loaded at session start |

## 🚀 Install

> The installer clones this repo to `~/.local/dotfiles/claude`, copies all config to `~/.claude/`, and installs the LSP plugins and MCP servers listed below.
>
> 📄 [View the raw install script](https://raw.githubusercontent.com/claudemgr/config/main/install.sh) before running.

```sh
curl -fsSL https://raw.githubusercontent.com/claudemgr/config/main/install.sh | sh
```

Re-running is safe — the installer updates the local clone and re-registers plugins and MCP servers idempotently.

### Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| `claude` | ✅ Yes | [Claude Code CLI](https://claude.ai/code) |
| `git` | ✅ Yes | For cloning/updating the config repo |
| `npx` | ⚠️ Optional | Required for the fetch MCP server; skipped if absent |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | GitHub personal access token for the GitHub MCP server. Set via your private dotfiles. |

## 🔌 Plugins Installed

| Plugin | Language Server |
|--------|----------------|
| `gopls-lsp` | Go |
| `rust-analyzer-lsp` | Rust |
| `typescript-lsp` | TypeScript / JavaScript |

## 🔗 MCP Servers Configured

| Server | Transport | Purpose |
|--------|-----------|---------|
| `github` | HTTP | GitHub API — PRs, issues, repo search, code review |
| `fetch` | stdio (`npx`) | Fetch web content and documentation |

## 🧠 Memory System

Files in `home/memory/` are loaded by Claude at session start via `MEMORY.md`. They provide persistent context across sessions without bloating `CLAUDE.md`.

| File | Contents |
|------|---------|
| `MEMORY.md` | Index — lists all memory files and their purpose |
| `user_project_conventions.md` | AI.md/IDEA.md/TODO.AI.md file roles and template system |
| `user_execution_hierarchy.md` | VM > Incus > Docker > host run order |
| `sensitive_data.md` | Credential handling — never commit secrets |
| `feedback_gitcommit.md` | `gitcommit` path resolution and usage |
| `script_conventions.md` | Bash/sh/zsh/fish/ps1 interpreter detection, UUOC rules, doc triple sync |

## 📁 Directory Layout

```
config/
├── install.sh          # Bootstrap installer
├── home/
│   ├── CLAUDE.md       # Global Claude rules
│   ├── settings.json   # Claude Code settings
│   ├── agents/         # Custom agent definitions
│   ├── hooks/          # Hook scripts
│   └── memory/         # Persistent memory files
├── README.md
└── LICENSE.md
```

## 🔄 Updating

The installer is idempotent — run it again on any machine to pull the latest config, plugins, and MCP server registrations:

```sh
curl -fsSL https://raw.githubusercontent.com/claudemgr/config/main/install.sh | sh
```

## 👤 Author

**Jason Hempstead** · [GitHub](https://github.com/casjay) · [Casjays Developments](https://casjaysdev.pro)

## 📄 License

MIT — see [LICENSE.md](LICENSE.md)
