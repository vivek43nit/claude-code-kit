# claude-code-kit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Languages](https://img.shields.io/badge/languages-7-blue)](#supported-languages)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%7C%20GitLab-green)](#ci-quality-gates)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**The problem:** Every engineer on your team has a different Claude Code setup. Some use
TDD, some don't. Security scanning is manual. Guidelines exist in a doc nobody reads.

**This repo fixes that** — one `curl` command gives any project:
- Auto-detected language guidelines (Python, TypeScript, Go, Java, Kotlin, Rust, JavaScript)
- Security scanning before every file write (hardcoded secrets, AWS keys, private keys)
- Plan mode decision rules so Claude knows when to think before acting
- Production-grade guidelines: TDD, observability, API design, DB migrations, incident response
- CI quality gates for GitHub Actions and GitLab CI out of the box

> Works with [Claude Code](https://claude.ai/code) — Anthropic's official CLI. Tested on
> real production projects.

## What It Does

| Feature | How |
|---------|-----|
| Auto language guidelines | `UserPromptSubmit` hook detects languages on every session start and writes `guidelines/active.md` |
| Security scanning | `PreToolUse` hook scans every file write/edit for hardcoded secrets, private keys, and AWS credentials |
| Production guidelines | Conditional injection: observability, testing, branching, dependencies, ADRs always on; API design, DB, feature flags, incidents, accessibility injected based on project signals |
| Plan mode decisions | CLAUDE.md decision table tells Claude when to plan vs respond directly |
| CI quality gates | GitHub Actions + GitLab CI templates: Gitleaks, Trivy, per-language lint + test |

## Supported Languages

Python · TypeScript · JavaScript · Go · Java · Kotlin · Rust

## Quick Start

### One-liner (no clone needed)

**macOS / Linux / WSL / Git Bash — curl:**

```bash
curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- /path/to/your/project
```

**wget:**

```bash
wget -qO- https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- /path/to/your/project
```

> **Windows (PowerShell / CMD):** Use WSL, Git Bash, or install curl — then run the curl command above.

**Add CI quality gates (optional):**

```bash
# GitHub Actions
mkdir -p your-project/.github/workflows
curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/ci/github/quality-gates.yml \
  -o your-project/.github/workflows/quality-gates.yml

# GitLab CI
curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/ci/gitlab/quality-gates.yml \
  -o your-project/.gitlab-ci.yml
```

Open Claude Code in your project, run `/reload-plugins`, and start a session.
Language detection runs automatically — no further configuration needed.

> **Existing projects:** Safe to run on projects that already have files.
> - **`CLAUDE.md`** — guideline imports are **appended**, your existing content is untouched.
> - **`.claude/settings.json`** — hooks are **merged** automatically if `jq` is installed (`brew install jq` / `apt install jq`). Without `jq`, manual merge instructions are printed.
> - **`guidelines/*.md`** — skipped if they already exist. If any are skipped, the installer prints a ready-to-run `claude` command that fetches the latest versions from GitHub and updates outdated kit files — no local clone needed.
> - **Language detection** runs immediately so `guidelines/active.md` is ready before your first session.

<details>
<summary>Alternative: clone and run locally</summary>

```bash
git clone https://github.com/vivek43nit/claude-code-kit
bash claude-code-kit/install.sh /path/to/your/project

# CI templates (local copy)
cp claude-code-kit/ci/github/quality-gates.yml your-project/.github/workflows/quality-gates.yml
cp claude-code-kit/ci/gitlab/quality-gates.yml  your-project/.gitlab-ci.yml
```

</details>

## Auditing an Existing Project

Run a two-phase audit: first checks your claude-code-kit setup, then checks your code against the active guidelines.

**If you've already run the installer:**
```bash
claude "$(cat .claude/prompts/audit.md)"
```

**Without installing (fetches the prompt directly from GitHub):**
```bash
claude "$(curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/.claude/prompts/audit.md)"
```

**What happens:**
1. **Phase 1 — Setup**: Checks hooks, `settings.json`, `CLAUDE.md`, `.gitignore`, and diffs your `guidelines/` against the latest kit versions on GitHub.
2. **You choose**: Fix setup issues first (recommended), or skip straight to the code audit.
3. **Phase 2 — Code compliance**: Reads your source files and checks against active guidelines — testing pyramid, observability, security, dependencies, branching, API design. Only checks areas relevant to your project's languages.
4. Writes `.claude/audit-report.md` with a full findings table.
5. Prints the **migration command** — run it to get a step-by-step plan with confirmation before any changes are made.

## How Language Detection Works

On every `UserPromptSubmit` event, `.claude/hooks/detect-languages.sh`:

1. Scans for manifest files (`package.json`, `go.mod`, `pyproject.toml`, etc.) and source file extensions
2. Writes `guidelines/active.md` with the matching language guideline files inlined
3. Injects additional guidelines based on project signals:

| Signal | Injected guidelines |
|--------|-------------------|
| `Dockerfile`, `docker-compose.yml`, `pom.xml`, `build.gradle` | `api-design.md` |
| `migrations/`, `prisma/`, `alembic.ini`, `*.sql`, `db/` | `database.md` |
| `Dockerfile`, `docker-compose.yml`, `k8s/`, `kubernetes/` | `feature-flags.md`, `incidents.md` |
| TypeScript or JavaScript detected | `accessibility.md` |
| Always | `observability.md`, `testing.md`, `branching.md`, `dependencies.md`, `adr.md` |

`guidelines/active.md` is git-ignored — it is generated fresh each session.

## How Security Scanning Works

`.claude/hooks/security-scan.sh` runs before every file write or edit. It scans for:

- Hardcoded passwords and secrets (`password = "..."`)
- Private keys (`-----BEGIN RSA PRIVATE KEY-----`)
- AWS credentials (`AKIA...`)

By default it **warns** but does not block. To make it blocking (recommended for teams):

```bash
# In .claude/hooks/security-scan.sh, change the last line:
exit 0   →   exit 2
```

With `exit 2`, Claude cannot write the file until the secret is removed.

## Repository Structure

```
claude-code-kit/
├── .claude/
│   ├── hooks/
│   │   ├── detect-languages.sh       # UserPromptSubmit hook
│   │   ├── security-scan.sh          # PreToolUse hook
│   │   ├── test-detect-languages.sh  # Tests for detection hook
│   │   └── test-security-scan.sh     # Tests for security hook
│   └── settings.json                 # Hook registrations
├── guidelines/
│   ├── base.md                       # TDD, commits, design patterns, security
│   ├── {python,typescript,...}.md    # Per-language Google-style guidelines
│   ├── observability.md              # Structured logging, RED metrics, OpenTelemetry
│   ├── testing.md                    # Testing pyramid (unit/integration/E2E)
│   ├── database.md                   # Zero-downtime migrations, N+1, pooling
│   ├── api-design.md                 # REST standards, versioning, error format
│   ├── branching.md                  # Trunk-based dev, semver, release process
│   ├── dependencies.md               # Renovate, license policy, vuln scanning
│   ├── adr.md                        # Architecture Decision Records
│   ├── feature-flags.md              # Gradual rollout, flag types, cleanup
│   ├── incidents.md                  # P0-P3 severity, response process, post-mortems
│   ├── accessibility.md              # WCAG 2.1 AA, ARIA, keyboard nav, jest-axe
│   └── active.md                     # Auto-generated — do not edit
├── ci/
│   ├── github/quality-gates.yml      # GitHub Actions: security + lint + test
│   └── gitlab/quality-gates.yml      # GitLab CI: same stages
├── docs/
│   ├── adr/                          # Architecture Decision Records for this repo
│   └── templates/
│       ├── postmortem.md             # Blameless post-mortem template
│       └── runbook.md                # Service runbook template
├── CLAUDE.md                         # Claude Code project configuration
├── install.sh                        # Bootstrap script for new projects
├── CONTRIBUTING.md                   # How to contribute
└── LICENSE                           # MIT
```

## Adding a New Language

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full process. The short version:

1. Create `guidelines/<lang>.md`
2. Add detection logic in `.claude/hooks/detect-languages.sh`
3. Add a test in `.claude/hooks/test-detect-languages.sh`
4. Add CI steps in the quality-gates templates

## Plan Mode & Decision Rules

`CLAUDE.md` includes a decision table that tells Claude when to enter plan mode vs
respond directly. Key rules:

- New feature or change touching 3+ files → **Plan mode**
- Same bug fix attempted 2+ times → **Systematic debugging + plan**
- Auth, payments, DB, secrets → **Plan + security-guidance plugin**
- Single config change or typo → **Direct response**

## Plugins Used

| Plugin | Purpose |
|--------|---------|
| superpowers | TDD workflows, plan mode, code review, parallel agents |
| security-guidance | Auto-invoked for auth/payments/DB/config/API areas |
| code-review | `/code-review` skill for PR reviews |
| code-simplifier | `/simplify` skill for refactoring |
| context7 | Live library docs fetched on demand |
| ralph-loop | Recurring task automation |
| claude-code-setup | Recommendations for new project setup |
| claude-md-management | Audit and improve CLAUDE.md files |

Plugins require the [Superpowers plugin system](https://github.com/anthropics/claude-code)
or equivalent. Install them into `~/.claude/plugins/` before use.

## CI Quality Gates

Both CI templates (`ci/github/quality-gates.yml` and `ci/gitlab/quality-gates.yml`) run:

| Stage | What runs | Gate |
|-------|-----------|------|
| Detect | Language detection | Outputs language matrix |
| Security | Gitleaks (secrets) + Trivy (CVEs) | HIGH/CRITICAL CVEs block merge |
| Lint + Test | Per-language linter + test suite | Must pass per detected language |

Copy the template for your platform:

```bash
# GitHub Actions
cp ci/github/quality-gates.yml your-project/.github/workflows/quality-gates.yml

# GitLab CI
cp ci/gitlab/quality-gates.yml your-project/.gitlab-ci.yml
```

## Star History

If claude-code-kit saved you setup time or improved your team's Claude Code experience,
consider giving it a ⭐ — it helps others discover the project.

[![Star History Chart](https://api.star-history.com/svg?repos=vivek43nit/claude-code-kit&type=Date)](https://star-history.com/#vivek43nit/claude-code-kit&Date)

**Share it:** Post in your team Slack, mention it in a blog post, or add it to your
company's internal tooling list. Word of mouth is how open-source projects grow.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — © 2026 Vivek Kumar
