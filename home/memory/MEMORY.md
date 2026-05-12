# Memory Index

- [Project file conventions](user_project_conventions.md) — AI.md=HOW, IDEA.md=WHAT, CLAUDE.md=loader, TODO.AI.md=tasks; template system in claudemgr
- [Execution hierarchy](user_execution_hierarchy.md) — VM>Incus>Docker>host; applies to everything including scriptmgr install scripts
- [Sensitive data rule](sensitive_data.md) — never add credentials to any repo; all repos public by default; personal dotfiles is the only exception
- [gitcommit path resolution](feedback_gitcommit.md) — never hardcode path; use `gitcommit` from PATH
- [Script conventions](script_conventions.md) — shebang/extension determines interpreter (bash vs sh vs zsh vs fish vs ps1 vs cmd); bash-specific: `__` function prefix, `SCRIPTNAME_` variable prefix, comments above code, no UUOC, builtins over forks, documentation triple sync (help+man+completions)
