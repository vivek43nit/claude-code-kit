# Audit & Migration Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-phase audit + migration workflow: a prompt file (`prompts/audit.md`) holds the full Claude instructions; installers copy it to `.claude/prompts/audit.md`; users run a one-liner to invoke it. The audit checks setup correctness then code compliance, asks the user whether to fix setup first, writes a report, and prints the migration command.

**Architecture:** The audit prompt lives in `prompts/audit.md` in the kit repo. Both installers download/copy it to `.claude/prompts/` in the target project. The README shows two one-liners: `claude "$(cat .claude/prompts/audit.md)"` for installed projects, and a `curl`-based variant for non-installed projects. The migration command (embedded in the report) is short enough to be inline.

**Tech Stack:** Bash, Markdown, Claude Code CLI (`claude` command)

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `prompts/audit.md` | **Create** | Full audit prompt — two-phase instructions for Claude |
| `remote-install.sh` | **Modify** | Download `prompts/audit.md` to `.claude/prompts/audit.md` |
| `install.sh` | **Modify** | Copy `prompts/audit.md` to `.claude/prompts/audit.md` |
| `README.md` | **Modify** | New `## Auditing an Existing Project` section with one-liners |

---

### Task 1: Create `prompts/audit.md`

**Files:**
- Create: `prompts/audit.md`

- [ ] **Step 1: Create the prompts directory and audit.md**

```markdown
# claude-code-kit Audit Prompt

You are auditing this project against claude-code-kit standards.
Follow these steps in order without skipping any.

---

## PHASE 1 — SETUP AUDIT

Check each item below and mark ✓ (ok), ✗ (missing), or ~ (outdated/misconfigured).

### Structural checks (read local files only)

| Item | Check |
|------|-------|
| `.claude/hooks/detect-languages.sh` | File exists? |
| `.claude/hooks/security-scan.sh` | File exists? |
| `.claude/settings.json` | Contains UserPromptSubmit hook running `bash .claude/hooks/detect-languages.sh`? |
| `.claude/settings.json` | Contains PreToolUse hook running `bash .claude/hooks/security-scan.sh`? |
| `CLAUDE.md` | Contains `@guidelines/active.md`? |
| `.gitignore` | Contains `guidelines/active.md`? |

### Content checks (fetch latest from GitHub and diff)

For each file below, fetch `https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/<path>`
and compare to the local copy. Mark ~ if local differs from latest, ✗ if file is missing entirely.

Files to check:
- `guidelines/base.md`
- `guidelines/observability.md`
- `guidelines/testing.md`
- `guidelines/branching.md`
- `guidelines/dependencies.md`
- `guidelines/adr.md`
- `guidelines/api-design.md`
- `guidelines/database.md`
- `guidelines/feature-flags.md`
- `guidelines/incidents.md`
- `guidelines/accessibility.md`
- `guidelines/python.md`
- `guidelines/typescript.md`
- `guidelines/javascript.md`
- `guidelines/go.md`
- `guidelines/java.md`
- `guidelines/kotlin.md`
- `guidelines/rust.md`

Print the Phase 1 summary table, then ask the user:

> Phase 1 complete — X setup issue(s) found.
> How would you like to proceed?
>
> **[1]** Fix setup issues first, then run the code audit (recommended)
> **[2]** Skip to code audit now with the current setup
>
> Enter 1 or 2:

Wait for the user's response before continuing.

---

## PHASE 2 — CODE COMPLIANCE AUDIT

Read the project's source files. For each area below, check compliance with the
active guidelines and report findings. Skip areas with no applicable code.

### Testing
- Are there test files?
- Do tests follow the pyramid (≈70% unit, 20% integration, 10% e2e)?
- Are mocks used only at system boundaries (DB, HTTP, filesystem)?
- Are test names descriptive (`test_<what>_<when>_<expected>`)?

### Observability
- Is logging structured (JSON or structured format)?
- Do log lines include required fields: `timestamp`, `level`, `service`, `trace_id`?
- Are secrets, passwords, or PII ever logged?
- Are there health endpoints (`/health/live`, `/health/ready`)?

### Security
- Any hardcoded secrets, API keys, or credentials in source files?
- Any SQL string interpolation (vs parameterised queries)?
- Is input validated at system boundaries (user input, external APIs)?

### Dependencies
- Is there a `renovate.json` for automated dependency updates?
- Are lock files (`package-lock.json`, `poetry.lock`, `go.sum`, etc.) committed?

### Branching & Commits
- Do recent git commits follow conventional commit format (`feat:`, `fix:`, `chore:`, etc.)?

### API Design (if server code detected)
- Are there `/health/live` and `/health/ready` endpoints?
- Do error responses follow a consistent shape?

---

## REPORT

Write the complete report to `.claude/audit-report.md` using this exact format:

```
# claude-code-kit Audit Report
Generated: <today's date>

## Summary
| Phase | ✗ Missing / Failing | ~ Outdated / Issues | ✓ Ok |
|-------|---------------------|---------------------|------|
| Setup | | | |
| Code compliance | | | |

## Phase 1 — Setup Findings
| Item | Status | Notes |
|------|--------|-------|
| .claude/hooks/detect-languages.sh | | |
...

## Phase 2 — Code Compliance Findings
| Area | Status | Findings |
|------|--------|---------|
| Testing | | |
...

## Migration Command

Run this to generate a step-by-step migration plan:

\`\`\`bash
claude "Read .claude/audit-report.md. Write a numbered migration plan in two sections:
1) Setup fixes — for every ✗ or ~ item in Phase 1, the exact change needed.
2) Code compliance fixes — for every ✗ or ~ item in Phase 2, the exact change needed.
Show the full plan and ask me to confirm before making any changes."
\`\`\`
```

After writing the file, print:

> Audit complete — report saved to `.claude/audit-report.md`
>
> Run the migration command at the bottom of the report to generate a step-by-step plan.
```

- [ ] **Step 2: Verify the file was created correctly**

```bash
wc -l prompts/audit.md
```

Expected: > 80 lines.

- [ ] **Step 3: Commit**

```bash
git add prompts/audit.md
git commit -m "feat: add prompts/audit.md with two-phase setup and code compliance audit"
```

---

### Task 2: Update `remote-install.sh` to download the prompt file

**Files:**
- Modify: `remote-install.sh`

- [ ] **Step 1: Add prompt file download after the hooks section**

Find the hooks section in `remote-install.sh`:
```bash
fetch_file ".claude/hooks/detect-languages.sh"
chmod +x "$TARGET/.claude/hooks/detect-languages.sh"

fetch_file ".claude/hooks/security-scan.sh"
chmod +x "$TARGET/.claude/hooks/security-scan.sh"
```

Add immediately after it:
```bash
# ── 1b. Prompts ───────────────────────────────────────────────────────────────

mkdir -p "$TARGET/.claude/prompts"
fetch_file "prompts/audit.md"
```

Note: `fetch_file` already handles skip-if-exists, so re-running is safe.

- [ ] **Step 2: Update the script header comment to mention prompts**

Find:
```bash
# What it does (identical to install.sh, but sources files from GitHub):
#   1. Downloads .claude/hooks/ scripts
```

Replace with:
```bash
# What it does (identical to install.sh, but sources files from GitHub):
#   1. Downloads .claude/hooks/ scripts and .claude/prompts/
```

- [ ] **Step 3: Smoke-test**

```bash
rm -rf /tmp/test-prompt && mkdir /tmp/test-prompt
bash remote-install.sh /tmp/test-prompt 2>&1 | grep -q "prompts/audit.md" && echo "PASS: prompt downloaded" || echo "FAIL: prompt missing"
[ -f /tmp/test-prompt/.claude/prompts/audit.md ] && echo "PASS: file exists" || echo "FAIL"
```

Expected: two `PASS` lines.

- [ ] **Step 4: Commit**

```bash
git add remote-install.sh
git commit -m "feat: download prompts/audit.md to .claude/prompts/ in remote-install.sh"
```

---

### Task 3: Update `install.sh` to copy the prompt file

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Add prompt file copy after the hooks section**

Find in `install.sh`:
```bash
for f in "$HOOKS_SRC"/*.sh; do
    name=$(basename "$f")
    if [ -f "$HOOKS_DST/$name" ]; then
        echo "  [SKIP] $HOOKS_DST/$name already exists (not overwriting)"
    else
        cp "$f" "$HOOKS_DST/$name"
        chmod +x "$HOOKS_DST/$name"
        echo "  [OK]   Copied hook: .claude/hooks/$name"
    fi
done
```

Add immediately after it:
```bash
# ── 1b. Prompts ───────────────────────────────────────────────────────────────

PROMPTS_SRC="$SOURCE_DIR/prompts"
PROMPTS_DST="$TARGET/.claude/prompts"

mkdir -p "$PROMPTS_DST"

for f in "$PROMPTS_SRC"/*.md; do
    name=$(basename "$f")
    if [ -f "$PROMPTS_DST/$name" ]; then
        echo "  [SKIP] $PROMPTS_DST/$name already exists (not overwriting)"
    else
        cp "$f" "$PROMPTS_DST/$name"
        echo "  [OK]   Copied prompt: .claude/prompts/$name"
    fi
done
```

- [ ] **Step 2: Update the script header comment**

Find:
```bash
# What it does:
#   1. Copies .claude/hooks/ to target project
```

Replace with:
```bash
# What it does:
#   1. Copies .claude/hooks/ and .claude/prompts/ to target project
```

- [ ] **Step 3: Smoke-test**

```bash
rm -rf /tmp/test-prompt-local && mkdir /tmp/test-prompt-local
bash install.sh /tmp/test-prompt-local 2>&1 | grep -q "prompts/audit.md" && echo "PASS: prompt copied" || echo "FAIL"
[ -f /tmp/test-prompt-local/.claude/prompts/audit.md ] && echo "PASS: file exists" || echo "FAIL"
```

Expected: two `PASS` lines.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: copy prompts/audit.md to .claude/prompts/ in install.sh"
```

---

### Task 4: Update README with audit section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find the insertion point**

```bash
grep -n "## How Language Detection Works" README.md
```

Note the line number. Insert the new section immediately before it.

- [ ] **Step 2: Insert the section**

Insert immediately before `## How Language Detection Works`:

````markdown
## Auditing an Existing Project

Run a two-phase audit: first checks your claude-code-kit setup, then checks your code against the active guidelines.

**If you've already run the installer:**
```bash
claude "$(cat .claude/prompts/audit.md)"
```

**Without installing (fetches the prompt directly from GitHub):**
```bash
claude "$(curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/prompts/audit.md)"
```

**What happens:**
1. **Phase 1 — Setup**: Checks hooks, `settings.json`, `CLAUDE.md`, `.gitignore`, and diffs your `guidelines/` against the latest kit versions on GitHub.
2. **You choose**: Fix setup issues first (recommended), or skip straight to the code audit.
3. **Phase 2 — Code compliance**: Reads your source files and checks against active guidelines — testing pyramid, observability, security, dependencies, branching, API design. Only checks areas relevant to your project's languages.
4. Writes `.claude/audit-report.md` with a full findings table.
5. Prints the **migration command** — run it to get a step-by-step plan with confirmation before any changes are made.

````

- [ ] **Step 3: Verify**

```bash
grep -A 3 "## Auditing an Existing Project" README.md
```

Expected: shows the section header and the first `claude` command.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add audit and migration section to README"
```

---

## Self-Review

**Spec coverage:**
- [x] Prompt stored in file (`prompts/audit.md`) — not inline in README
- [x] Installers copy/download prompt to `.claude/prompts/audit.md`
- [x] README shows short one-liner for installed projects
- [x] README shows `curl`-based one-liner for non-installed projects
- [x] Phase 1 — structural checks + GitHub content diff for all 18 guideline files
- [x] User choice — fix setup first or go straight to code audit
- [x] Phase 2 — testing, observability, security, deps, branching, API design (language-aware)
- [x] Report written to `.claude/audit-report.md` with structured tables
- [x] Migration command embedded in report — reads report, makes plan, asks confirm
- [x] README updated (README maintenance rule satisfied)
- [x] Both installers updated (remote-install.sh + install.sh)

**Placeholder scan:** No TBDs. All prompt text is fully written. All bash blocks are complete.

**Risk note:** The `curl`-based variant pipes into `claude "$(...)"` — the subshell expands to the full prompt text before passing to claude. This works as long as the prompt contains no unescaped double quotes at the top level (it doesn't — all inner quotes use backticks or single quotes).
