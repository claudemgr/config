# Memory Index

- [Project file conventions](user_project_conventions.md) — AI.md=HOW, IDEA.md=WHAT, CLAUDE.md=loader, TODO.AI.md=tasks; template system in claudemgr
- [Execution hierarchy](user_execution_hierarchy.md) — VM>Incus>Docker>host; applies to everything including scriptmgr install scripts
- [Sensitive data rule](sensitive_data.md) — never add credentials to any repo; all repos public by default; personal dotfiles is the only exception
- [gitcommit path resolution](feedback_gitcommit.md) — never hardcode path; use `gitcommit` from PATH
- [Script conventions](script_conventions.md) — shebang/extension determines interpreter (bash vs sh vs zsh vs fish vs ps1 vs cmd); bash-specific: `__` function prefix, `SCRIPTNAME_` variable prefix, comments above code, no UUOC, builtins over forks, documentation triple sync (help+man+completions)
- [Project forbidden files](project_forbidden_files.md) — files/dirs that must never be created; README always README.md, LICENSE always LICENSE.md with 3rd-party attributions at bottom; allowed root files list
- [NEVER/ALWAYS rules](never_always_rules.md) — Argon2id/no bcrypt, no plaintext tokens, no machine-specific hardcoding, no JSON comments, singular dir names, Docker ENTRYPOINT/CI/cleanup rules, Go/Rust-specific constraints
