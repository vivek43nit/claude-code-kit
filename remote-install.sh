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
#   3. Merges .claude/settings.json hooks (creates if absent; merges with jq if present)
#   4. Merges CLAUDE.md guideline imports (creates if absent; appends if present)
#   5. Seeds guidelines/active.md and updates .gitignore
#   6. Runs language detection immediately (populates guidelines/active.md)
#   7. Prints CI template instructions
#
# Safe on existing projects — never overwrites or deletes user files.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

REPO="vivek43nit/claude-code-kit"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

TARGET="${1:-.}"
TARGET="$(mkdir -p "$TARGET" && cd "$TARGET" && pwd)"

# ── Detect download tool ──────────────────────────────────────────────────────

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

SKIPPED_GUIDELINES=()
for f in "${GUIDELINE_FILES[@]}"; do
    [ -f "$TARGET/$f" ] && SKIPPED_GUIDELINES+=("$f")
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
elif command -v jq &>/dev/null; then
    if jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length > 0' "$SETTINGS_DST" &>/dev/null; then
        echo "  [SKIP] .claude/settings.json already contains claude-code-kit hooks"
    else
        tmp="$(mktemp)"
        jq '
          .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]) |
          .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "bash .claude/hooks/security-scan.sh"}]}])
        ' "$SETTINGS_DST" > "$tmp"
        if [ -s "$tmp" ]; then
            mv "$tmp" "$SETTINGS_DST"
            echo "  [OK]   Merged claude-code-kit hooks into existing .claude/settings.json"
        else
            rm -f "$tmp"
            echo "  [WARN] jq merge produced empty output — .claude/settings.json unchanged"
            echo "         Add hooks manually from: ${BASE_URL}/.claude/settings.json"
        fi
    fi
else
    echo "  [WARN] .claude/settings.json already exists and jq is not installed."
    echo "         Install jq (brew install jq / apt install jq) and re-run to auto-merge, or add manually:"
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
    echo '           "PreToolUse" (matcher Write|Edit): [{"hooks": [{"type": "command", "command": "bash .claude/hooks/security-scan.sh"}]}]'
fi

# ── 4. CLAUDE.md ──────────────────────────────────────────────────────────────

CLAUDE_MD_DST="$TARGET/CLAUDE.md"

if [ ! -f "$CLAUDE_MD_DST" ]; then
    fetch_file "CLAUDE.md"
elif grep -q "@guidelines/active.md" "$CLAUDE_MD_DST"; then
    echo "  [SKIP] CLAUDE.md already references @guidelines/active.md"
else
    cat >> "$CLAUDE_MD_DST" <<'KITEOF'

---

<!-- Added by claude-code-kit — https://github.com/vivek43nit/claude-code-kit -->

## Active Language Guidelines

@guidelines/active.md

## Universal Guidelines

@guidelines/base.md
KITEOF
    echo "  [OK]   Merged claude-code-kit guideline imports into existing CLAUDE.md"
fi

# ── 5. .gitignore ─────────────────────────────────────────────────────────────

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

# ── 6. Language detection ─────────────────────────────────────────────────────

echo ""
echo "Running language detection..."
if (cd "$TARGET" && bash .claude/hooks/detect-languages.sh 2>/dev/null); then
    echo "  [OK]   guidelines/active.md populated"
else
    echo "  [WARN] Language detection failed — will run automatically on first Claude Code session"
fi

# ── 7. CI instructions ────────────────────────────────────────────────────────

CI_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/ci"

echo ""
echo "────────────────────────────────────────────────────────"
echo "CI Templates (optional — run to add quality gates):"
echo ""
echo "  GitHub Actions:"
echo "    mkdir -p $TARGET/.github/workflows"
echo "    curl -fsSL ${CI_BASE}/github/quality-gates.yml \\"
echo "      -o $TARGET/.github/workflows/quality-gates.yml"
echo ""
echo "  GitLab CI:"
echo "    curl -fsSL ${CI_BASE}/gitlab/quality-gates.yml \\"
echo "      -o $TARGET/.gitlab-ci.yml"
echo ""
echo "────────────────────────────────────────────────────────"
echo ""
echo "Done! Next steps:"
echo "  1. Copy the CI template above (optional)"
echo "  2. Open Claude Code in $TARGET"
echo "  3. Run /reload-plugins"
echo "  4. Start a session — languages will auto-detect and populate guidelines/active.md"

if [ ${#SKIPPED_GUIDELINES[@]} -gt 0 ]; then
    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "⚠  ${#SKIPPED_GUIDELINES[@]} guideline file(s) already existed and were not overwritten:"
    for f in "${SKIPPED_GUIDELINES[@]}"; do
        echo "     · $f"
    done
    echo ""
    echo "  These may be outdated if this project used an older version of claude-code-kit."
    echo "  To review and update them, open Claude Code in $TARGET and run:"
    echo ""
    FILE_LIST=""
    for f in "${SKIPPED_GUIDELINES[@]}"; do
        FILE_LIST="${FILE_LIST:+$FILE_LIST }$f"
    done
    echo "    claude \"Fetch the latest versions of: $FILE_LIST"
    echo "    from https://raw.githubusercontent.com/vivek43nit/claude-code-kit/main/"
    echo "    and compare each to my local copy. Update any that are outdated."
    echo "    Do not modify files that are not in that list.\""
    echo ""
    echo "  Claude fetches directly from GitHub — no local clone needed."
    echo "────────────────────────────────────────────────────────"
fi
