# claudemgr/config

Read `AI.md` and `IDEA.md` before acting on this project.

## Source vs Deployed — Project-Dir Rule Override

This project IS the source of `~/.claude/`. The deploy script copies `home/` → `~/.claude/`.

**Never read `~/.claude/` files from within this project. Always use the source:**

| Deployed (never read) | Source (always read) |
|---|---|
| `~/.claude/CLAUDE.md` | `home/CLAUDE.md` |
| `~/.claude/memory/MEMORY.md` | `home/memory/MEMORY.md` |
| `~/.claude/memory/*.md` | `home/memory/*.md` |
| `~/.claude/agents/*.md` | `home/agents/*.md` |
| `~/.claude/hooks/*.sh` | `home/hooks/*.sh` |
| `~/.claude/settings.json` | `home/settings.json` |

The global `home/CLAUDE.md` says "Read `~/.claude/memory/MEMORY.md` at session start" — **in this project that instruction means `home/memory/MEMORY.md`**. Apply the same substitution for any `~/.claude/` reference.
