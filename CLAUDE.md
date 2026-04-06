# Claude Code — Company Base Guidelines

This is the canonical base configuration for all projects. Language-specific guidelines
are auto-selected based on detected languages in the project.

## Active Language Guidelines

@guidelines/active.md

## Universal Guidelines

@guidelines/base.md

---

## Plugins Active in This Project

| Plugin | Purpose |
|--------|---------|
| **superpowers** | TDD workflows, plans, code review, parallel agents |
| **code-review** | PR review skill (`/code-review`) |
| **code-simplifier** | Refactoring and simplification (`/simplify`) |
| **security-guidance** | Security analysis on demand |
| **context7** | Fetch live library docs — use for any library/SDK question |
| **ralph-loop** | Recurring task loops (`/ralph-loop`) |
| **claude-code-setup** | Automation recommendations for new projects |
| **claude-md-management** | Audit and improve CLAUDE.md files |

## How Language Detection Works

When a session starts, `.claude/hooks/detect-languages.sh` scans the project root for
language indicators (file extensions, manifest files) and writes `guidelines/active.md`.
This file is then imported above, so Claude receives the correct language guidelines
without manual configuration.

**Supported languages:** Python, TypeScript, JavaScript, Go, Java, Kotlin, Rust

To add a new language: create `guidelines/<lang>.md` and add detection logic in
`.claude/hooks/detect-languages.sh`.

## Security Hook

`.claude/hooks/security-scan.sh` runs before every Write/Edit operation, scanning
content for hardcoded secrets, private keys, and AWS credentials. It warns but does
not block by default.

> **To make security scanning blocking** (recommended for team enforcement):
> Edit `.claude/hooks/security-scan.sh` and change the last line from `exit 0` to `exit 2`.
> With `exit 2`, Claude will be blocked from writing the file until the issue is resolved.

## For New Projects

Run from this repo:
```bash
bash install.sh /path/to/your/project
```

Then copy the appropriate CI template:
- GitHub Actions: `ci/github/quality-gates.yml` → `.github/workflows/quality-gates.yml`
- GitLab CI: `ci/gitlab/quality-gates.yml` → `.gitlab-ci.yml`
