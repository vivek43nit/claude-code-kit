# Guideline Skip Reporting & Claude Migration Hint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When installer skips guideline files that already exist, track which ones were skipped and print a summary at the end with a ready-to-run `claude` one-liner that reviews and updates outdated kit guidelines without touching custom files.

**Architecture:** Both scripts get a `SKIPPED_GUIDELINES` array populated during the guidelines loop. At the end (after CI instructions), if the array is non-empty, a help block is printed listing the skipped files and a copy-paste `claude` command. No logic changes — purely additive tracking and output. The `claude` command instructs Claude to fetch the latest versions from GitHub raw URLs and update only files that match known kit filenames.

**Tech Stack:** Bash arrays, `echo`

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `remote-install.sh` | **Modify** | Add `SKIPPED_GUIDELINES` tracking in guidelines loop; add help block at end |
| `install.sh` | **Modify** | Same — identical pattern, local-clone source |

---

### Task 1: Add skip tracking and hint block to `remote-install.sh`

**Files:**
- Modify: `remote-install.sh`

Two edits:
1. Guidelines loop — pre-check each file and append to `SKIPPED_GUIDELINES` if it exists
2. After CI instructions block — print help block when array is non-empty

- [ ] **Step 1: Read current guidelines loop in `remote-install.sh`**

Find the block around lines 66–91:
```bash
for f in "${GUIDELINE_FILES[@]}"; do
    fetch_file "$f"
done
```

- [ ] **Step 2: Replace the guidelines loop to track skipped files**

```bash
SKIPPED_GUIDELINES=()
for f in "${GUIDELINE_FILES[@]}"; do
    [ -f "$TARGET/$f" ] && SKIPPED_GUIDELINES+=("$f")
    fetch_file "$f"
done
```

This pre-checks before `fetch_file` so `fetch_file` still owns the skip/download decision — we just shadow-track it.

- [ ] **Step 3: Append the help block at the very end of the script (after the Done! block)**

Find the last lines of the script:
```bash
echo "Done! Next steps:"
echo "  1. Copy the CI template above (optional)"
echo "  2. Open Claude Code in $TARGET"
echo "  3. Run /reload-plugins"
echo "  4. Start a session — languages will auto-detect and populate guidelines/active.md"
```

Replace with:
```bash
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
    # Build space-separated list for embedding in the claude command
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
```

- [ ] **Step 4: Smoke-test — fresh project (no skips expected, no block printed)**

```bash
rm -rf /tmp/test-fresh2 && mkdir /tmp/test-fresh2
bash remote-install.sh /tmp/test-fresh2 2>&1 | grep -c "guideline file(s) already existed" | xargs -I{} sh -c '[ {} -eq 0 ] && echo "PASS: no hint on fresh install" || echo "FAIL: hint shown incorrectly"'
```

Expected: `PASS: no hint on fresh install`

- [ ] **Step 5: Smoke-test — existing project with pre-existing guidelines (hint must appear)**

```bash
rm -rf /tmp/test-skip && mkdir -p /tmp/test-skip/guidelines
echo "# old base" > /tmp/test-skip/guidelines/base.md
echo "# old python" > /tmp/test-skip/guidelines/python.md

bash remote-install.sh /tmp/test-skip 2>&1 | tee /tmp/test-skip-output.txt

grep -q "2 guideline file(s) already existed" /tmp/test-skip-output.txt && echo "PASS: skip count correct" || echo "FAIL: count wrong"
grep -q "guidelines/base.md" /tmp/test-skip-output.txt && echo "PASS: base.md listed" || echo "FAIL: base.md missing from list"
grep -q "guidelines/python.md" /tmp/test-skip-output.txt && echo "PASS: python.md listed" || echo "FAIL: python.md missing from list"
grep -q "claude \"Fetch the latest versions of:" /tmp/test-skip-output.txt && echo "PASS: claude command present" || echo "FAIL: claude command missing"

# Original content must be untouched
grep -q "old base" /tmp/test-skip/guidelines/base.md && echo "PASS: base.md content preserved" || echo "FAIL: base.md overwritten"
```

Expected: all `PASS`.

- [ ] **Step 6: Commit**

```bash
git add remote-install.sh
git commit -m "feat: report skipped guidelines and print claude migration hint in remote-install.sh"
```

---

### Task 2: Apply same changes to `install.sh`

**Files:**
- Modify: `install.sh`

Identical pattern. The only difference: `install.sh` uses a glob loop over local `.sh` files rather than an explicit array — but the guidelines section uses the same `fetch_file`-style copy loop so the tracking approach is the same.

- [ ] **Step 1: Read the guidelines loop in `install.sh`**

Find the block around lines 53–69:
```bash
for f in "$GUIDE_SRC"/*.md; do
    name=$(basename "$f")
    [ "$name" = "active.md" ] && continue  # Skip generated file
    if [ -f "$GUIDE_DST/$name" ]; then
        echo "  [SKIP] $GUIDE_DST/$name already exists (not overwriting)"
    else
        cp "$f" "$GUIDE_DST/$name"
        echo "  [OK]   Copied guideline: guidelines/$name"
    fi
done
```

- [ ] **Step 2: Replace the loop to track skipped files**

```bash
SKIPPED_GUIDELINES=()
for f in "$GUIDE_SRC"/*.md; do
    name=$(basename "$f")
    [ "$name" = "active.md" ] && continue  # Skip generated file
    if [ -f "$GUIDE_DST/$name" ]; then
        SKIPPED_GUIDELINES+=("guidelines/$name")
        echo "  [SKIP] $GUIDE_DST/$name already exists (not overwriting)"
    else
        cp "$f" "$GUIDE_DST/$name"
        echo "  [OK]   Copied guideline: guidelines/$name"
    fi
done
```

- [ ] **Step 3: Append the same help block at the end of `install.sh`**

Find the last lines:
```bash
echo "Done! Next steps:"
echo "  1. Copy the CI template above"
echo "  2. Open Claude Code in $TARGET"
echo "  3. Run /reload-plugins"
echo "  4. Start a session — languages will auto-detect and populate guidelines/active.md"
```

Replace with:
```bash
echo "Done! Next steps:"
echo "  1. Copy the CI template above"
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
    # Build space-separated list for embedding in the claude command
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
```

- [ ] **Step 4: Smoke-test install.sh**

```bash
rm -rf /tmp/test-skip-local && mkdir -p /tmp/test-skip-local/guidelines
echo "# old base" > /tmp/test-skip-local/guidelines/base.md

bash install.sh /tmp/test-skip-local 2>&1 | tee /tmp/test-skip-local-output.txt

grep -q "guideline file(s) already existed" /tmp/test-skip-local-output.txt && echo "PASS: hint shown" || echo "FAIL: hint missing"
grep -q "guidelines/base.md" /tmp/test-skip-local-output.txt && echo "PASS: base.md listed" || echo "FAIL"
grep -q "claude \"Fetch the latest versions of:" /tmp/test-skip-local-output.txt && echo "PASS: claude command present" || echo "FAIL"
grep -q "old base" /tmp/test-skip-local/guidelines/base.md && echo "PASS: content preserved" || echo "FAIL: content overwritten"

# Fresh install: no hint
rm -rf /tmp/test-fresh-local && mkdir /tmp/test-fresh-local
bash install.sh /tmp/test-fresh-local 2>&1 | grep -c "guideline file(s)" | xargs -I{} sh -c '[ {} -eq 0 ] && echo "PASS: no hint on fresh" || echo "FAIL"'
```

Expected: all `PASS`.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat: report skipped guidelines and print claude migration hint in install.sh"
```

---

### Task 3: Update README existing-project callout

**Files:**
- Modify: `README.md`

The current callout (Quick Start section) says "All other files — skipped if they already exist" but doesn't mention what to do if guidelines are stale or how the migration hint works.

- [ ] **Step 1: Find and update the existing-project callout**

Find in `README.md`:
```markdown
> **Existing projects:** Safe to run on projects that already have files.
> - **`CLAUDE.md`** — guideline imports are **appended**, your existing content is untouched.
> - **`.claude/settings.json`** — hooks are **merged** automatically if `jq` is installed (`brew install jq` / `apt install jq`). Without `jq`, manual merge instructions are printed.
> - **All other files** — skipped if they already exist (re-running is always safe).
> - **Language detection** runs immediately so `guidelines/active.md` is ready before your first session.
```

Replace with:
```markdown
> **Existing projects:** Safe to run on projects that already have files.
> - **`CLAUDE.md`** — guideline imports are **appended**, your existing content is untouched.
> - **`.claude/settings.json`** — hooks are **merged** automatically if `jq` is installed (`brew install jq` / `apt install jq`). Without `jq`, manual merge instructions are printed.
> - **`guidelines/*.md`** — skipped if they already exist. If any are skipped, the installer prints a ready-to-run `claude` command that fetches the latest versions from GitHub and updates outdated kit files — no local clone needed.
> - **Language detection** runs immediately so `guidelines/active.md` is ready before your first session.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: mention guideline migration hint in existing-project callout"
```

---

## Self-Review

**Spec coverage:**
- [x] Track which guideline files were skipped (both scripts)
- [x] Print count + list of skipped files when any exist
- [x] Print copy-paste `claude` command for migration with specific filenames embedded
- [x] Command fetches from `raw.githubusercontent.com` — no local clone needed
- [x] Command instructs Claude to update kit files only, leave custom untouched
- [x] No hint printed on fresh install (array empty)
- [x] Skipped file content is never touched
- [x] Both scripts consistent
- [x] README updated to mention migration hint

**Placeholder scan:** No TBDs. All echo blocks are fully written out.

**Note on emoji:** The `⚠` character in echo works on macOS/Linux terminals. If this causes issues on some environments it can be replaced with `[!]` — but emoji in echo is standard practice in modern shell installers (homebrew, nvm, etc.).
