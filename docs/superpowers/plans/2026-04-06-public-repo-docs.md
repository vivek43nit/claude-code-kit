# Public Repo Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add README.md, LICENSE (MIT), CONTRIBUTING.md, and GitHub discoverability assets so claude-base-setup is ready to publish as a high-visibility open-source repo.

**Architecture:** Four standalone files + README SEO layer — no code changes. Each file is self-contained. Commit each separately.

**Tech Stack:** Markdown, MIT License text, shields.io badges, GitHub topics (set in UI post-push)

---

## File Map

| File | Status | Purpose |
|------|--------|---------|
| `README.md` | Create | SEO-optimised homepage: hook, badges, what it does, quick-start, structure |
| `LICENSE` | Create | MIT license text with current year and author |
| `CONTRIBUTING.md` | Create | How to file issues, submit PRs, add guidelines, add language support |
| `.github/TOPICS.md` | Create | Reference list of GitHub topics to set in the UI after pushing |

---

### Task 1: LICENSE file

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Create the MIT LICENSE file**

```
MIT License

Copyright (c) 2026 Kriti Kumari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license"
```

---

### Task 2: CONTRIBUTING.md

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Create CONTRIBUTING.md**

Content:

```markdown
# Contributing to claude-base-setup

Thank you for contributing! This project is a shared baseline for Claude Code
configuration — quality and clarity matter more than quantity.

## Types of Contributions

| Type | Welcome? | Notes |
|------|----------|-------|
| Bug fixes in hooks or install.sh | Yes | Include a failing test case |
| New language guidelines | Yes | Follow the template below |
| New universal guideline | Discuss first | Open an issue before writing |
| Changes to base.md | Discuss first | Affects every project |
| CI template improvements | Yes | Test in a real repo first |
| Typo / clarity fixes | Yes | No issue needed |

## Before You Start

For anything beyond a typo fix, open a GitHub Issue first:
- Describe the problem or gap you see
- Wait for maintainer acknowledgement before opening a PR
- This prevents duplicate work and wasted effort

## Development Setup

```bash
git clone https://github.com/<your-fork>/claude-base-setup
cd claude-base-setup
# No dependencies — pure bash + markdown
```

Run the test suite:

```bash
bash .claude/hooks/test-detect-languages.sh
bash .claude/hooks/test-security-scan.sh
```

All tests must pass before submitting a PR.

## Adding a New Language

1. Create `guidelines/<lang>.md` following this structure:

```markdown
# <Language> Guidelines

**Style guide:** [link to official style guide]

## Style
[Key style rules — max 10 bullet points]

## Types / Type Safety
[Static typing conventions]

## TDD in <Language>
[Test framework, naming convention, example test]

## Error Handling
[Error handling idiom for this language]

## Tooling
[Linter, formatter, test runner]
```

2. Add detection logic to `.claude/hooks/detect-languages.sh`:

```bash
# <Language>
if manifest_exists "<manifest-file>" || has_files "*.<ext>"; then
    DETECTED+=("<lang>")
fi
```

3. Add a test case to `.claude/hooks/test-detect-languages.sh`:

```bash
run_test "detects <Language> via <manifest>" "$(
    dir=$(mktemp -d)
    touch "$dir/<manifest-file>"
    bash "$SCRIPT" "$dir" >/dev/null 2>&1
    grep -c "<lang>" "$dir/guidelines/active.md"
)" "1"
```

4. Add CI lint/test step in `ci/github/quality-gates.yml` and `ci/gitlab/quality-gates.yml` for the new language.

5. Run all tests — they must pass.

## Pull Request Process

1. Fork the repo and create a branch: `feat/<short-desc>` or `fix/<short-desc>`
2. Make your changes following the conventions above
3. Run both test scripts — all tests must pass
4. Open a PR with:
   - A clear title following [Conventional Commits](https://www.conventionalcommits.org/) format
   - A description explaining *why* (not just what changed)
   - A link to the issue it resolves (e.g. `Closes #42`)
5. A maintainer will review within 5 business days
6. Address review comments — we aim for 1 review round
7. Maintainer merges once approved

## PR Checklist

- [ ] Tests pass (`bash .claude/hooks/test-detect-languages.sh && bash .claude/hooks/test-security-scan.sh`)
- [ ] New language: detection + guideline file + test case + CI step all added together
- [ ] No hardcoded secrets or credentials
- [ ] Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`)
- [ ] PR description explains *why*, links to the issue

## Code of Conduct

Be respectful. Critique ideas, not people. This is a blameless, collaborative project.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
```

- [ ] **Step 2: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: add contributor guide with language addition workflow"
```

---

### Task 3: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

```markdown
# claude-base-setup

A canonical Claude Code configuration baseline for engineering teams — auto-detects
project languages, enforces TDD and security scanning, and ships production-grade
coding guidelines out of the box.

> Use this repo as a shared starting point so every project at your company gets the
> same Claude Code behaviour without manual setup.

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

**Bootstrap a new or existing project:**

```bash
git clone https://github.com/<owner>/claude-base-setup
bash claude-base-setup/install.sh /path/to/your/project
```

Then copy the CI template for your platform:

```bash
# GitHub Actions
mkdir -p your-project/.github/workflows
cp claude-base-setup/ci/github/quality-gates.yml \
   your-project/.github/workflows/quality-gates.yml

# GitLab CI
cp claude-base-setup/ci/gitlab/quality-gates.yml \
   your-project/.gitlab-ci.yml
```

Open Claude Code in your project, run `/reload-plugins`, and start a session.
Language detection runs automatically — no further configuration needed.

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
claude-base-setup/
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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — © 2026 Kriti Kumari
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add comprehensive README for public repo"
```

---

### Task 4: GitHub SEO — topics reference + README enhancements

**Files:**
- Create: `.github/TOPICS.md`
- Modify: `README.md` (add badges row, pain-point hook, star CTA, keyword density)

**Why this works:**
- GitHub topics are the primary discovery mechanism (search + topic browse pages)
- Badges signal credibility and activity at a glance — psychological trust
- A pain-point hook in the first 5 lines converts visitors to stars
- Star CTA at the bottom converts readers who scrolled to the end
- Strategic keyword placement helps GitHub's internal search rank the repo

- [ ] **Step 1: Create `.github/TOPICS.md` (reference for post-push UI setup)**

```markdown
# GitHub Repository Topics

Set these in: **GitHub → repo → Settings (gear icon next to "About") → Topics**

Max 20. Order does not matter. Copy-paste:

```
claude-code
claude
anthropic
ai-assistant
developer-tools
developer-experience
coding-standards
code-quality
tdd
test-driven-development
devops
github-actions
ci-cd
bash
template
boilerplate
best-practices
security
productivity
llm
```

## Repository Description (160 chars max)

Set in: **GitHub → repo → Settings (gear icon) → Description**

```
Canonical Claude Code configuration for teams: auto language guidelines, TDD enforcement, security scanning, and CI quality gates — install in one command.
```

## Social Preview

Set in: **GitHub → Settings → Social preview**

Upload a 1280×640px image. Suggested content:
- Dark background
- Large text: "claude-base-setup"
- Subtitle: "Production-grade Claude Code config for your whole team"
- Small icons for: Python, TypeScript, Go, Java, Kotlin, Rust, Rust
- Small text bottom-right: MIT License
```

- [ ] **Step 2: Add badges row and pain-point hook to README.md**

Replace the current opening of README.md (from `# claude-base-setup` through the first blockquote) with:

```markdown
# claude-base-setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Languages](https://img.shields.io/badge/languages-7-blue)](#supported-languages)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%7C%20GitLab-green)](#ci-quality-gates)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**The problem:** Every engineer on your team has a different Claude Code setup. Some use
TDD, some don't. Security scanning is manual. Guidelines exist in a doc nobody reads.

**This repo fixes that** — one `bash install.sh` command gives any project:
- Auto-detected language guidelines (Python, TypeScript, Go, Java, Kotlin, Rust, JavaScript)
- Security scanning before every file write (hardcoded secrets, AWS keys, private keys)
- Plan mode decision rules so Claude knows when to think before acting
- Production-grade guidelines: TDD, observability, API design, DB migrations, incident response
- CI quality gates for GitHub Actions and GitLab CI out of the box

> Works with [Claude Code](https://claude.ai/code) — Anthropic's official CLI. Tested on
> real production projects.
```

- [ ] **Step 3: Add star CTA section to end of README.md (before License section)**

Add this section immediately before `## License`:

```markdown
## Star History

If claude-base-setup saved you setup time or improved your team's Claude Code experience,
consider giving it a ⭐ — it helps others discover the project.

[![Star History Chart](https://api.star-history.com/svg?repos=<owner>/claude-base-setup&type=Date)](https://star-history.com/#<owner>/claude-base-setup&Date)

**Share it:** Post in your team Slack, mention it in a blog post, or add it to your
company's internal tooling list. Word of mouth is how open-source projects grow.
```

_(Replace `<owner>` with your GitHub username after pushing)_

- [ ] **Step 4: Add `## CI Quality Gates` anchor section to README.md**

The badges link to `#ci-quality-gates`. Add this section after the Plugin table:

```markdown
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
```

- [ ] **Step 5: Commit**

```bash
git add .github/TOPICS.md README.md
git commit -m "docs: add GitHub topics reference and SEO optimisations to README"
```

- [ ] **Step 6: After pushing to GitHub — manual steps (takes 5 minutes)**

1. Go to `github.com/<owner>/claude-base-setup`
2. Click the gear icon next to "About" on the right sidebar
3. Paste the description from `.github/TOPICS.md`
4. Add all 20 topics from `.github/TOPICS.md`
5. Check "Releases", "Packages" visibility as appropriate
6. Upload a social preview image (Settings → Social preview)
7. Enable "Discussions" if you want community Q&A (Settings → Features)

---

## Self-Review

**Spec coverage:**
- README.md describing what the project does ✓
- Pain-point hook in first 5 lines ✓
- Badges row for credibility ✓
- Directory structure so contributors understand the layout ✓
- Quick-start with install.sh ✓
- How language detection works ✓
- How security scanning works ✓
- Plan mode rules ✓
- Plugin list ✓
- CI quality gates section (with badge anchor) ✓
- Star CTA at bottom ✓
- License suggested (MIT) and file created ✓
- CONTRIBUTING.md with issue-first process ✓
- How to add a new language (most common contribution) ✓
- PR checklist ✓
- GitHub topics list (20 topics, strategic mix of niche + broad) ✓
- Repository description (160-char limit) ✓
- Social preview guidance ✓
- Post-push manual steps checklist ✓

**Placeholder scan:** `<owner>` placeholder in star history chart — noted inline with instruction to replace after pushing. All other content is specific.

**Type consistency:** No code signatures across tasks — files are independent.
