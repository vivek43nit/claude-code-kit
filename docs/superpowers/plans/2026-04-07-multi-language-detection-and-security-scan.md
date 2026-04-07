# Multi-Language Detection & Security Scan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix language detection to support monorepos and deep Java structures, run only once per session, and stop false-positiving on env-var references in the security scanner.

**Architecture:** Six targeted edits across six files. No new files. No new dependencies. Each task is a self-contained fix with verification steps.

**Tech Stack:** bash, jq (for settings merges), Claude Code hooks (`SessionStart`, `PreToolUse`)

---

### Task 1: Fix security-scan.sh — env-var interpolation false positives

**Files:**
- Modify: `.claude/hooks/security-scan.sh:33-35`

The Pattern 1 regex `[^"']{6,}` matches any 6+ char value between quotes, including `${MY_KEY}`, `{{ .Values.key }}`, `#{ENV['KEY']}`, `@VAR@`. Fix: tighten the negated character class to exclude common interpolation sigils (`$`, `#`, `{`, `%`, `@`, `<`).

- [ ] **Step 1: Verify the false positive exists**

```bash
printf '{"tool_input":{"content":"api_key = \"${MY_API_KEY}\""}}' | \
  bash .claude/hooks/security-scan.sh
```

Expected output: `SECURITY WARNING` printed (this is the bug — it should NOT warn).

- [ ] **Step 2: Update Pattern 1 in security-scan.sh**

In `.claude/hooks/security-scan.sh`, change line 34 from:

```bash
    '(password|passwd|secret|api_key|apikey|access_token|auth_token|private_key)\s*[=:]\s*["'"'"'][^"'"'"']{6,}'; then
```

to:

```bash
    '(password|passwd|secret|api_key|apikey|access_token|auth_token|private_key)\s*[=:]\s*["'"'"'][^"'"'"'$#{%@<]{6,}'; then
```

The only change is `[^"'"'"']{6,}` → `[^"'"'"'$#{%@<]{6,}` (adding `$#{%@<` to the negated character class). In the actual regex this is `[^"']{6,}` → `[^"'$#{%@<]{6,}`.

- [ ] **Step 3: Verify false positive is gone**

```bash
printf '{"tool_input":{"content":"api_key = \"${MY_API_KEY}\""}}' | \
  bash .claude/hooks/security-scan.sh
```

Expected: no output (no warning).

```bash
printf '{"tool_input":{"content":"api_key = \"{{ .Values.key }}\""}}' | \
  bash .claude/hooks/security-scan.sh
```

Expected: no output (no warning).

```bash
printf '{"tool_input":{"content":"api_key = \"#{ENV['"'"'KEY'"'"']}\""}}' | \
  bash .claude/hooks/security-scan.sh
```

Expected: no output (no warning).

- [ ] **Step 4: Verify true positives still fire**

```bash
printf '{"tool_input":{"content":"api_key = \"sk-proj-abc123xyz789abc123xyz789abc1\""}}' | \
  bash .claude/hooks/security-scan.sh
```

Expected: `SECURITY WARNING` printed.

```bash
printf '{"tool_input":{"content":"password = \"mysupersecretpassword\""}}' | \
  bash .claude/hooks/security-scan.sh
```

Expected: `SECURITY WARNING` printed.

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/security-scan.sh
git commit -m "fix(security-scan): exclude interpolation sigils from secret value match"
```

---

### Task 2: Fix detect-languages.sh — recursive manifests, depth, Java/Kotlin, frontend bug

**Files:**
- Modify: `.claude/hooks/detect-languages.sh:22-28` (has_files depth)
- Modify: `.claude/hooks/detect-languages.sh:30-32` (manifest_exists → recursive)
- Modify: `.claude/hooks/detect-languages.sh:64-72` (Java/Kotlin detection)
- Modify: `.claude/hooks/detect-languages.sh:113-117` (frontend flag bug)

Four independent bugs in the same file, fixed together.

- [ ] **Step 1: Verify monorepo detection gaps (before fix)**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/backend" "$TMPDIR/frontend" "$TMPDIR/guidelines"
echo '[tool.poetry]' > "$TMPDIR/backend/pyproject.toml"
echo '{}' > "$TMPDIR/frontend/package.json"
touch "$TMPDIR/frontend/tsconfig.json"

bash .claude/hooks/detect-languages.sh "$TMPDIR"
cat "$TMPDIR/guidelines/active.md" | head -5
rm -rf "$TMPDIR"
```

Expected (before fix): "No specific language detected" — because `manifest_exists` only checks the project root.

- [ ] **Step 2: Verify frontend bug (before fix)**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/guidelines"
touch "$TMPDIR/tsconfig.json"
touch "$TMPDIR/index.ts"

bash .claude/hooks/detect-languages.sh "$TMPDIR"
grep -c "accessibility" "$TMPDIR/guidelines/active.md" && echo "PASS (unexpected)" || echo "BUG CONFIRMED: accessibility not injected for TypeScript"
rm -rf "$TMPDIR"
```

Expected (before fix): "BUG CONFIRMED" — TypeScript alone doesn't trigger accessibility guidelines.

- [ ] **Step 3: Replace `manifest_exists` with recursive version**

In `.claude/hooks/detect-languages.sh`, replace lines 30-32:

```bash
manifest_exists() {
    [ -f "$PROJECT_ROOT/$1" ]
}
```

with:

```bash
manifest_exists() {
    find "$PROJECT_ROOT" \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/vendor/*" \
        -name "$1" 2>/dev/null | grep -q .
}
```

- [ ] **Step 4: Bump `has_files` maxdepth from 4 to 6**

In `.claude/hooks/detect-languages.sh`, replace lines 22-28:

```bash
has_files() {
    find "$PROJECT_ROOT" -maxdepth 4 \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/vendor/*" \
        -name "$1" 2>/dev/null | grep -q .
}
```

with:

```bash
has_files() {
    find "$PROJECT_ROOT" -maxdepth 6 \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/vendor/*" \
        -name "$1" 2>/dev/null | grep -q .
}
```

- [ ] **Step 5: Remove `has_files` fallback for Java and Kotlin**

In `.claude/hooks/detect-languages.sh`, replace the Java and Kotlin detection blocks:

```bash
# Java
if manifest_exists "pom.xml" || manifest_exists "build.gradle" || has_files "*.java"; then
    DETECTED+=("java")
fi

# Kotlin
if manifest_exists "build.gradle.kts" || has_files "*.kt"; then
    DETECTED+=("kotlin")
fi
```

with:

```bash
# Java
if manifest_exists "pom.xml" || manifest_exists "build.gradle"; then
    DETECTED+=("java")
fi

# Kotlin
if manifest_exists "build.gradle.kts"; then
    DETECTED+=("kotlin")
fi
```

Rationale: Java package structures (`src/main/java/com/company/module/...`) exceed any reasonable `maxdepth`. Manifests (`pom.xml`, `build.gradle`) are always at module root and are reliably detected by the now-recursive `manifest_exists`.

- [ ] **Step 6: Fix the `frontend` flag operator-precedence bug**

In `.claude/hooks/detect-languages.sh`, replace lines 113-117:

```bash
frontend=false
for lang in "${DETECTED[@]+"${DETECTED[@]}"}"; do
    [ "$lang" = "typescript" ] || [ "$lang" = "javascript" ] && frontend=true && break
done
```

with:

```bash
frontend=false
for lang in "${DETECTED[@]+"${DETECTED[@]}"}"; do
    if [ "$lang" = "typescript" ] || [ "$lang" = "javascript" ]; then
        frontend=true
        break
    fi
done
```

The original is parsed as `typescript_check || (javascript_check && frontend=true && break)` due to bash `&&`/`||` precedence — so TypeScript alone never sets `frontend=true`.

- [ ] **Step 7: Verify monorepo detection works**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/backend" "$TMPDIR/frontend" "$TMPDIR/guidelines"
echo '[tool.poetry]' > "$TMPDIR/backend/pyproject.toml"
echo '{}' > "$TMPDIR/frontend/package.json"
touch "$TMPDIR/frontend/tsconfig.json"

bash .claude/hooks/detect-languages.sh "$TMPDIR"
grep "typescript" "$TMPDIR/guidelines/active.md" && echo "PASS: TypeScript detected" || echo "FAIL"
grep "python" "$TMPDIR/guidelines/active.md" && echo "PASS: Python detected" || echo "FAIL"
rm -rf "$TMPDIR"
```

Expected: both PASS.

- [ ] **Step 8: Verify Java monorepo detection**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/api-service" "$TMPDIR/guidelines"
echo '<project/>' > "$TMPDIR/api-service/pom.xml"

bash .claude/hooks/detect-languages.sh "$TMPDIR"
grep "java" "$TMPDIR/guidelines/active.md" && echo "PASS: Java detected via subdir pom.xml" || echo "FAIL"
rm -rf "$TMPDIR"
```

Expected: PASS.

- [ ] **Step 9: Verify TypeScript triggers accessibility guidelines**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/guidelines"
touch "$TMPDIR/tsconfig.json"

bash .claude/hooks/detect-languages.sh "$TMPDIR"
grep -l "accessibility\|Accessibility\|a11y" "$TMPDIR/guidelines/active.md" && echo "PASS: accessibility included" || echo "FAIL"
rm -rf "$TMPDIR"
```

Expected: PASS. (The `accessibility.md` file contains the word "accessibility".)

- [ ] **Step 10: Commit**

```bash
git add .claude/hooks/detect-languages.sh
git commit -m "fix(detect-languages): recursive manifests, depth 6, Java manifest-only, frontend flag"
```

---

### Task 3: Move detect-languages hook from UserPromptSubmit to SessionStart

**Files:**
- Modify: `.claude/settings.json:12-21`

- [ ] **Step 1: Update settings.json**

In `.claude/settings.json`, replace:

```json
"hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/detect-languages.sh"
          }
        ]
      }
    ],
```

with:

```json
"hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/detect-languages.sh"
          }
        ]
      }
    ],
```

- [ ] **Step 2: Verify settings.json is valid JSON**

```bash
jq . .claude/settings.json && echo "PASS: valid JSON"
```

Expected: JSON printed without error.

- [ ] **Step 3: Verify SessionStart is present, UserPromptSubmit for detect-languages is gone**

```bash
jq '[.hooks.SessionStart[]?.hooks[]?] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length' .claude/settings.json
```

Expected: `1`

```bash
jq '[.hooks.UserPromptSubmit[]?.hooks[]? // empty] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length' .claude/settings.json
```

Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -m "fix(settings): move detect-languages hook from UserPromptSubmit to SessionStart"
```

---

### Task 4: Update install.sh — SessionStart references

**Files:**
- Modify: `install.sh:112` (jq existence check)
- Modify: `install.sh:117` (jq merge expression)
- Modify: `install.sh:132` (manual fallback message)

- [ ] **Step 1: Update jq existence check (line 112)**

In `install.sh`, replace:

```bash
    if jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length > 0' "$SETTINGS_DST" &>/dev/null; then
```

with:

```bash
    if jq -e '[.hooks.SessionStart[]?.hooks[]?] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length > 0' "$SETTINGS_DST" &>/dev/null; then
```

- [ ] **Step 2: Update jq merge expression (line 117)**

In `install.sh`, replace:

```bash
          .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]) |
```

with:

```bash
          .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]) |
```

- [ ] **Step 3: Update manual fallback message (line 132)**

In `install.sh`, replace:

```bash
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
```

with:

```bash
    echo '           "SessionStart": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
```

- [ ] **Step 4: Verify no remaining UserPromptSubmit references for detect-languages**

```bash
grep "UserPromptSubmit" install.sh
```

Expected: no output (the `UserPromptSubmit` reference for `detect-languages.sh` is gone; `PreToolUse` for `security-scan.sh` is unaffected).

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "fix(install): update hook registration from UserPromptSubmit to SessionStart"
```

---

### Task 5: Update remote-install.sh — SessionStart references

**Files:**
- Modify: `remote-install.sh:126` (jq existence check)
- Modify: `remote-install.sh:131` (jq merge expression)
- Modify: `remote-install.sh:146` (manual fallback message)

- [ ] **Step 1: Update jq existence check (line 126)**

In `remote-install.sh`, replace:

```bash
    if jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length > 0' "$SETTINGS_DST" &>/dev/null; then
```

with:

```bash
    if jq -e '[.hooks.SessionStart[]?.hooks[]?] | map(select(.command == "bash .claude/hooks/detect-languages.sh")) | length > 0' "$SETTINGS_DST" &>/dev/null; then
```

- [ ] **Step 2: Update jq merge expression (line 131)**

In `remote-install.sh`, replace:

```bash
          .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]) |
```

with:

```bash
          .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]) |
```

- [ ] **Step 3: Update manual fallback message (line 146)**

In `remote-install.sh`, replace:

```bash
    echo '           "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
```

with:

```bash
    echo '           "SessionStart": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/detect-languages.sh"}]}]'
```

- [ ] **Step 4: Verify no remaining UserPromptSubmit references for detect-languages**

```bash
grep "UserPromptSubmit" remote-install.sh
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add remote-install.sh
git commit -m "fix(remote-install): update hook registration from UserPromptSubmit to SessionStart"
```

---

### Task 6: Update audit.md — SessionStart references

**Files:**
- Modify: `.claude/prompts/audit.md:18` (Phase 1 check row)
- Modify: `.claude/prompts/audit.md:120` (Phase 1 report template row)

- [ ] **Step 1: Update Phase 1 check row (line 18)**

In `.claude/prompts/audit.md`, replace:

```markdown
| `.claude/settings.json` | Contains UserPromptSubmit hook running `bash .claude/hooks/detect-languages.sh`? |
```

with:

```markdown
| `.claude/settings.json` | Contains SessionStart hook running `bash .claude/hooks/detect-languages.sh`? |
```

- [ ] **Step 2: Update Phase 1 report template row (line 120)**

In `.claude/prompts/audit.md`, replace:

```markdown
| .claude/settings.json — UserPromptSubmit hook | | |
```

with:

```markdown
| .claude/settings.json — SessionStart hook | | |
```

- [ ] **Step 3: Verify no remaining UserPromptSubmit references**

```bash
grep "UserPromptSubmit" .claude/prompts/audit.md
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add .claude/prompts/audit.md
git commit -m "fix(audit): update settings.json check from UserPromptSubmit to SessionStart"
```
