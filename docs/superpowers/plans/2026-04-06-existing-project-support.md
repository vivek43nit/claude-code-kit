# Existing Project Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make both `remote-install.sh` and `install.sh` work correctly when the target project already has a `CLAUDE.md` or `.claude/settings.json`, run language detection immediately at install time, and ensure no user files are ever deleted or overwritten.

**Architecture:** Two merge helpers replace the current skip/warn behaviour. For `CLAUDE.md`: append the kit's guideline imports if not already present. For `settings.json`: deep-merge hooks with jq (with safe temp-file swap guarded by non-empty check); graceful warning fallback if jq absent. Language detection runs at the end of install so `guidelines/active.md` is populated immediately. All operations are additive — nothing is overwritten or deleted.

**Tech Stack:** Bash, `jq` (optional — graceful fallback), `grep`, here-doc

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `remote-install.sh` | **Modify** | CLAUDE.md append-merge; settings.json jq-merge with safety guard; run language detection at end |
| `install.sh` | **Modify** | Add CLAUDE.md handling (new); settings.json jq-merge with safety guard; run language detection at end |
| `README.md` | **Modify** | Add existing-project callout in Quick Start |

---

### Task 1: Merge helpers + language detection in `remote-install.sh`

**Files:**
- Modify: `remote-install.sh`

Three changes:
1. `settings.json` block — replace warn-on-conflict with jq-merge (safe temp swap)
2. `CLAUDE.md` block — replace skip-if-exists with append-if-missing
3. New section at end — run language detection immediately after install

- [ ] **Step 1: Replace the `# ── 3. settings.json` section**

Find this block in `remote-install.sh`:
```bash
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
```

Replace with:
```bash
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
            echo "         Add hooks manually: ${BASE_URL}/.claude/settings.json"
        fi
    fi
else
    echo "  [WARN] .claude/settings.json already exists and jq is not installed."
    echo "         Install jq (brew install jq / apt install jq) and re-run to auto-merge, or add manually:"
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
    echo '           "PreToolUse" (matcher Write|Edit): [{"hooks": [{"type": "command", "command": "bash .claude/hooks/security-scan.sh"}]}]'
fi
```

- [ ] **Step 2: Replace the `# ── 4. CLAUDE.md` section**

Find:
```bash
# ── 4. CLAUDE.md ──────────────────────────────────────────────────────────────

fetch_file "CLAUDE.md"
```

Replace with:
```bash
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
```

- [ ] **Step 3: Add language detection section before the CI instructions block**

Find:
```bash
# ── 6. CI instructions ────────────────────────────────────────────────────────
```

Insert immediately before it:
```bash
# ── 6. Language detection ─────────────────────────────────────────────────────

echo ""
echo "Running language detection..."
if (cd "$TARGET" && bash .claude/hooks/detect-languages.sh 2>/dev/null); then
    echo "  [OK]   guidelines/active.md populated"
else
    echo "  [WARN] Language detection failed — will run automatically on first Claude Code session"
fi
```

Then renumber the CI section header from `# ── 6.` to `# ── 7.`

- [ ] **Step 4: Smoke-test**

```bash
# Test 1: fresh project — nothing exists yet
rm -rf /tmp/test-fresh && mkdir /tmp/test-fresh
bash remote-install.sh /tmp/test-fresh
[ -f /tmp/test-fresh/.claude/settings.json ] && echo "PASS: settings created" || echo "FAIL"
[ -f /tmp/test-fresh/CLAUDE.md ] && echo "PASS: CLAUDE.md created" || echo "FAIL"
[ -f /tmp/test-fresh/guidelines/active.md ] && echo "PASS: active.md populated" || echo "FAIL"

# Test 2: existing project with CLAUDE.md and settings.json
mkdir -p /tmp/test-existing/.claude
echo '{"hooks": {"UserPromptSubmit": []}}' > /tmp/test-existing/.claude/settings.json
printf "# My Project\n\nSome existing docs." > /tmp/test-existing/CLAUDE.md
bash remote-install.sh /tmp/test-existing
grep -q "detect-languages.sh" /tmp/test-existing/.claude/settings.json && echo "PASS: settings merged" || echo "FAIL: settings not merged"
grep -q "@guidelines/active.md" /tmp/test-existing/CLAUDE.md && echo "PASS: CLAUDE.md merged" || echo "FAIL: CLAUDE.md not merged"
grep -q "My Project" /tmp/test-existing/CLAUDE.md && echo "PASS: existing content preserved" || echo "FAIL: content lost"

# Test 3: idempotency
bash remote-install.sh /tmp/test-existing 2>&1 | grep -c "\[SKIP\]" | xargs -I{} sh -c '[ {} -ge 2 ] && echo "PASS: idempotent" || echo "FAIL: not idempotent"'
```

Expected: all `PASS`, no `FAIL`.

- [ ] **Step 5: Commit**

```bash
git add remote-install.sh
git commit -m "feat: merge CLAUDE.md and settings.json for existing projects in remote-install.sh"
```

---

### Task 2: Apply same changes to `install.sh`

**Files:**
- Modify: `install.sh`

`install.sh` sources from local clone (`$SOURCE_DIR`). Same three changes plus CLAUDE.md handling is currently absent entirely.

- [ ] **Step 1: Replace the settings.json block (lines 79–94)**

Find:
```bash
# ── 3. Merge settings.json ────────────────────────────────────────────────

SETTINGS_DST="$TARGET/.claude/settings.json"
SETTINGS_SRC="$SOURCE_DIR/.claude/settings.json"

mkdir -p "$TARGET/.claude"

if [ ! -f "$SETTINGS_DST" ]; then
    cp "$SETTINGS_SRC" "$SETTINGS_DST"
    echo "  [OK]   Created .claude/settings.json"
else
    echo "  [WARN] .claude/settings.json already exists."
    echo "         Manually merge hooks from: $SETTINGS_SRC"
    echo "         Hooks to add:"
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
    echo '           "PreToolUse" (matcher Write|Edit): [{"hooks": [{"type": "command", "command": "bash .claude/hooks/security-scan.sh"}]}]'
fi
```

Replace with:
```bash
# ── 3. Merge settings.json ────────────────────────────────────────────────

SETTINGS_DST="$TARGET/.claude/settings.json"
SETTINGS_SRC="$SOURCE_DIR/.claude/settings.json"

mkdir -p "$TARGET/.claude"

if [ ! -f "$SETTINGS_DST" ]; then
    cp "$SETTINGS_SRC" "$SETTINGS_DST"
    echo "  [OK]   Created .claude/settings.json"
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
            echo "         Add hooks manually from: $SETTINGS_SRC"
        fi
    fi
else
    echo "  [WARN] .claude/settings.json already exists and jq is not installed."
    echo "         Install jq (brew install jq / apt install jq) and re-run to auto-merge, or add manually:"
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
    echo '           "PreToolUse" (matcher Write|Edit): [{"hooks": [{"type": "command", "command": "bash .claude/hooks/security-scan.sh"}]}]'
fi
```

- [ ] **Step 2: Add CLAUDE.md section and language detection before CI instructions**

Find `# ── 5. CI instructions` and replace with:

```bash
# ── 5. CLAUDE.md ──────────────────────────────────────────────────────────────

CLAUDE_MD_DST="$TARGET/CLAUDE.md"
CLAUDE_MD_SRC="$SOURCE_DIR/CLAUDE.md"

if [ ! -f "$CLAUDE_MD_DST" ]; then
    cp "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST"
    echo "  [OK]   Copied CLAUDE.md"
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

# ── 6. Language detection ─────────────────────────────────────────────────────

echo ""
echo "Running language detection..."
if (cd "$TARGET" && bash .claude/hooks/detect-languages.sh 2>/dev/null); then
    echo "  [OK]   guidelines/active.md populated"
else
    echo "  [WARN] Language detection failed — will run automatically on first Claude Code session"
fi

# ── 7. CI instructions ────────────────────────────────────────────────────────
```

- [ ] **Step 3: Smoke-test install.sh**

```bash
# Test 1: existing project
mkdir -p /tmp/test-existing-local/.claude
echo '{"hooks": {"UserPromptSubmit": []}}' > /tmp/test-existing-local/.claude/settings.json
printf "# My Project" > /tmp/test-existing-local/CLAUDE.md
bash install.sh /tmp/test-existing-local
grep -q "detect-languages.sh" /tmp/test-existing-local/.claude/settings.json && echo "PASS: settings merged" || echo "FAIL"
grep -q "@guidelines/active.md" /tmp/test-existing-local/CLAUDE.md && echo "PASS: CLAUDE.md merged" || echo "FAIL"
grep -q "My Project" /tmp/test-existing-local/CLAUDE.md && echo "PASS: content preserved" || echo "FAIL"
[ -f /tmp/test-existing-local/guidelines/active.md ] && echo "PASS: active.md populated" || echo "FAIL"

# Test 2: idempotency
bash install.sh /tmp/test-existing-local 2>&1 | grep -c "\[SKIP\]" | xargs -I{} sh -c '[ {} -ge 2 ] && echo "PASS: idempotent" || echo "FAIL"'
```

Expected: all `PASS`.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: merge CLAUDE.md and settings.json for existing projects in install.sh"
```

---

### Task 3: Update README with existing-project callout

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add existing-project callout after CI block, before `<details>` fallback**

Find:
```markdown
Open Claude Code in your project, run `/reload-plugins`, and start a session.
Language detection runs automatically — no further configuration needed.

<details>
```

Replace with:
```markdown
Open Claude Code in your project, run `/reload-plugins`, and start a session.
Language detection runs automatically — no further configuration needed.

> **Existing projects:** Safe to run on projects that already have files.
> - **`CLAUDE.md`** — guideline imports are **appended**, your existing content is untouched.
> - **`.claude/settings.json`** — hooks are **merged** automatically if `jq` is installed (`brew install jq` / `apt install jq`). Without `jq`, manual merge instructions are printed.
> - **All other files** — skipped if they already exist (re-running is always safe).
> - **Language detection** runs immediately so `guidelines/active.md` is ready before your first session.

<details>
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document existing-project merge behaviour in README"
```

---

## Self-Review

**Spec coverage:**
- [x] Existing CLAUDE.md → append kit imports, preserve original content (both scripts)
- [x] Existing settings.json → jq merge with safe temp-file swap + non-empty guard (both scripts)
- [x] No jq → warn with manual instructions (both scripts)
- [x] Language detection runs at end of install (both scripts)
- [x] No user file ever deleted or overwritten (all writes are append or guarded temp-swap)
- [x] Idempotency — re-running produces `[SKIP]` not duplicates (both scripts)
- [x] Fresh project behaviour unchanged
- [x] README documents all of the above

**Placeholder scan:** No TBDs. All code is complete.

**Safety audit:**
- `fetch_file` — skips if file exists. No deletion. ✓
- jq merge — writes to `mktemp`, checks `[ -s "$tmp" ]` before `mv`, deletes temp on failure. ✓
- CLAUDE.md — uses `>>` (append only). ✓
- `.gitignore` — uses `>>` (append only). ✓
- `guidelines/active.md` — seeded with `>` only when file does not exist. ✓
- language detection — runs in subshell `(cd "$TARGET" && ...)`, failure is non-fatal. ✓
