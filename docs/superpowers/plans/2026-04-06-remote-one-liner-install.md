# Remote One-Liner Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `remote-install.sh` script that users can pipe directly from GitHub raw URLs — no local clone needed — and update README with per-OS one-liners.

**Architecture:** A self-contained shell script downloads all required files from GitHub raw content URLs, replicating exactly what `install.sh` does but sourcing from the internet instead of a local clone. The script detects `curl` vs `wget` and handles macOS + Linux. Windows users are guided to use WSL or Git Bash (which have curl).

**Tech Stack:** Bash, `curl`, `wget`, GitHub raw content CDN (`raw.githubusercontent.com`)

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `remote-install.sh` | **Create** | Self-contained installer — fetches files from GitHub raw |
| `README.md` | **Modify** | Replace Quick Start with per-OS one-liners |

---

### Task 1: Create `remote-install.sh`

**Files:**
- Create: `remote-install.sh`

This script must:
1. Accept a target directory argument (default: `.`)
2. Detect `curl` or `wget` (prefer `curl`; error if neither found)
3. Define the GitHub repo base URL
4. Download and install the same files that `install.sh` copies:
   - `.claude/hooks/detect-languages.sh`
   - `.claude/hooks/security-scan.sh`
   - `guidelines/base.md` and all language/topic `.md` files (not `active.md`)
   - `.claude/settings.json`
5. Seed `guidelines/active.md` if missing
6. Append `guidelines/active.md` to `.gitignore` if not present
7. Print the same CI copy instructions as `install.sh`

- [ ] **Step 1: Create `remote-install.sh`**

```bash
#!/usr/bin/env bash
# remote-install.sh — Bootstrap a project to use claude-code-kit WITHOUT cloning the repo.
#
# Usage (macOS / Linux / WSL / Git Bash):
#   curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- /path/to/project
#   curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- .
#
#   wget -qO- https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- /path/to/project
#
# What it does (identical to install.sh, but sources files from GitHub):
#   1. Downloads .claude/hooks/ scripts
#   2. Downloads guidelines/ markdown files
#   3. Downloads .claude/settings.json
#   4. Seeds guidelines/active.md and updates .gitignore
#   5. Prints CI template instructions

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

REPO="vivek43nit/claude-code-kit"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null || { mkdir -p "$TARGET" && cd "$TARGET"; } && pwd)"

# ── Detect download tool ───────────────────────────────────────────────────────

if command -v curl &>/dev/null; then
    download() { curl -fsSL "$1" -o "$2"; }
elif command -v wget &>/dev/null; then
    download() { wget -qO "$2" "$1"; }
else
    echo "Error: neither curl nor wget found. Install one and retry." >&2
    exit 1
fi

echo "Installing claude-code-kit into: $TARGET"
echo ""

# ── Helper ────────────────────────────────────────────────────────────────────

fetch_file() {
    local remote_path="$1"   # e.g. ".claude/hooks/detect-languages.sh"
    local local_path="$TARGET/$remote_path"

    mkdir -p "$(dirname "$local_path")"

    if [ -f "$local_path" ]; then
        echo "  [SKIP] $remote_path already exists (not overwriting)"
    else
        download "${BASE_URL}/${remote_path}" "$local_path"
        echo "  [OK]   Downloaded $remote_path"
    fi
}

# ── 1. Hooks ──────────────────────────────────────────────────────────────────

fetch_file ".claude/hooks/detect-languages.sh"
chmod +x "$TARGET/.claude/hooks/detect-languages.sh"

fetch_file ".claude/hooks/security-scan.sh"
chmod +x "$TARGET/.claude/hooks/security-scan.sh"

# ── 2. Guidelines ─────────────────────────────────────────────────────────────

GUIDELINE_FILES=(
    "guidelines/base.md"
    "guidelines/observability.md"
    "guidelines/testing.md"
    "guidelines/branching.md"
    "guidelines/dependencies.md"
    "guidelines/adr.md"
    "guidelines/api-design.md"
    "guidelines/database.md"
    "guidelines/feature-flags.md"
    "guidelines/incidents.md"
    "guidelines/accessibility.md"
    "guidelines/python.md"
    "guidelines/typescript.md"
    "guidelines/javascript.md"
    "guidelines/go.md"
    "guidelines/java.md"
    "guidelines/kotlin.md"
    "guidelines/rust.md"
)

for f in "${GUIDELINE_FILES[@]}"; do
    fetch_file "$f"
done

# Seed active.md (generated at runtime — never downloaded)
ACTIVE="$TARGET/guidelines/active.md"
if [ ! -f "$ACTIVE" ]; then
    printf "# Active Language Guidelines\n<!-- Auto-generated — run a Claude Code session to populate -->\n" > "$ACTIVE"
    echo "  [OK]   Created guidelines/active.md (empty — populated on first session)"
fi

# ── 3. settings.json ──────────────────────────────────────────────────────────

SETTINGS_DST="$TARGET/.claude/settings.json"
if [ ! -f "$SETTINGS_DST" ]; then
    fetch_file ".claude/settings.json"
else
    echo "  [WARN] .claude/settings.json already exists."
    echo "         Manually merge hooks from: ${BASE_URL}/.claude/settings.json"
    echo "         Hooks to add:"
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
    echo '           "PreToolUse" (matcher Write|Edit): [{"hooks": [{"type": "command", "command": "bash .claude/hooks/security-scan.sh"}]}]'
fi

# ── 4. .gitignore ─────────────────────────────────────────────────────────────

GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "guidelines/active.md" "$GITIGNORE"; then
        printf "\n# Auto-generated by claude-code-kit\nguidelines/active.md\n" >> "$GITIGNORE"
        echo "  [OK]   Added guidelines/active.md to .gitignore"
    else
        echo "  [SKIP] guidelines/active.md already in .gitignore"
    fi
else
    echo "guidelines/active.md" > "$GITIGNORE"
    echo "  [OK]   Created .gitignore with guidelines/active.md"
fi

# ── 5. CLAUDE.md ──────────────────────────────────────────────────────────────

fetch_file "CLAUDE.md"

# ── 6. CI instructions ───────────────────────────────────────────────────────

CI_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/ci"

echo ""
echo "────────────────────────────────────────────────────────"
echo "CI Templates (run these to add quality gates):"
echo ""
echo "  GitHub Actions:"
echo "    mkdir -p $TARGET/.github/workflows"
echo "    curl -fsSL ${CI_BASE}/github/quality-gates.yml -o $TARGET/.github/workflows/quality-gates.yml"
echo ""
echo "  GitLab CI:"
echo "    curl -fsSL ${CI_BASE}/gitlab/quality-gates.yml -o $TARGET/.gitlab-ci.yml"
echo ""
echo "────────────────────────────────────────────────────────"
echo ""
echo "Done! Next steps:"
echo "  1. Copy the CI template above (optional)"
echo "  2. Open Claude Code in $TARGET"
echo "  3. Run /reload-plugins"
echo "  4. Start a session — languages will auto-detect and populate guidelines/active.md"
```

- [ ] **Step 2: Make executable and smoke-test locally**

```bash
chmod +x /path/to/claude-code-kit/remote-install.sh
# Dry-run into a temp dir to confirm it would work
bash remote-install.sh /tmp/test-kit-install
ls /tmp/test-kit-install/.claude/hooks/
ls /tmp/test-kit-install/guidelines/
```

Expected output: hooks and guidelines directories populated, no errors.

- [ ] **Step 3: Commit**

```bash
git add remote-install.sh
git commit -m "feat: add remote-install.sh for curl/wget one-liner setup"
```

---

### Task 2: Update README Quick Start section

**Files:**
- Modify: `README.md` (Quick Start section, ~lines 38-60)

Replace the current two-step clone-then-install block with a three-panel section: one-liner (macOS/Linux), wget variant, and the existing clone-and-run fallback.

- [ ] **Step 1: Replace the Quick Start section in README.md**

Find the current Quick Start block:

```markdown
## Quick Start

**Bootstrap a new or existing project:**

```bash
git clone https://github.com/vivek43nit/claude-code-kit
bash claude-code-kit/install.sh /path/to/your/project
```

Then copy the CI template for your platform:

```bash
# GitHub Actions
mkdir -p your-project/.github/workflows
cp claude-code-kit/ci/github/quality-gates.yml \
   your-project/.github/workflows/quality-gates.yml

# GitLab CI
cp claude-code-kit/ci/gitlab/quality-gates.yml \
   your-project/.gitlab-ci.yml
```

Open Claude Code in your project, run `/reload-plugins`, and start a session.
Language detection runs automatically — no further configuration needed.
```

Replace with:

```markdown
## Quick Start

### One-liner (no clone needed)

**macOS / Linux / WSL / Git Bash — using curl:**

```bash
curl -fsSL https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- /path/to/your/project
```

**Using wget instead:**

```bash
wget -qO- https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/remote-install.sh | bash -s -- /path/to/your/project
```

> **Windows (PowerShell / CMD):** Use WSL, Git Bash, or install curl — then use the curl command above.

**Then add the CI quality gates (optional):**

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
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update Quick Start with curl/wget one-liner commands"
```

---

## Self-Review

**Spec coverage:**
- [x] One-liner for macOS/Linux with curl
- [x] One-liner variant with wget
- [x] Windows guidance (WSL/Git Bash)
- [x] No-clone required — downloads directly from raw.githubusercontent.com
- [x] Same install behaviour as existing `install.sh` (hooks, guidelines, settings, gitignore)
- [x] CI template instructions adapted for curl (no local clone needed)
- [x] README updated with all variants

**Placeholder scan:** No TBDs, no "add appropriate handling" — all code is complete.

**Type consistency:** Script uses consistent variable names (`TARGET`, `BASE_URL`, `GUIDELINE_FILES`) throughout.

**Risk notes:**
- `raw.githubusercontent.com` has rate limits for unauthenticated requests but is generous enough for this use case (< 30 file fetches).
- The `CLAUDE.md` fetch in step 5 of the script downloads the kit's CLAUDE.md. If the target project already has a CLAUDE.md, `fetch_file` will skip it (uses the same skip-if-exists guard). This is the correct behaviour.
