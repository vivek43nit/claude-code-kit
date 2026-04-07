# Multi-Language Detection & Security Scan Improvements

**Date:** 2026-04-07
**Status:** Accepted

## Context

Two problems identified with the current claude-code-kit setup:

1. **Language detection** runs on every prompt (wasteful), misses manifests in subdirectories (monorepo blind spot), has a bash operator-precedence bug that prevents TypeScript projects from getting accessibility guidelines, and uses `maxdepth 4` which misses deep Java package structures.

2. **Security scan** false-positives on env-var references in config files — e.g. `api_key = "${MY_API_KEY}"` triggers the hardcoded-secret pattern because `${MY_API_KEY}` is >6 non-quote characters.

## Design

### 1. `.claude/settings.json` — Hook timing

Move `detect-languages.sh` from `UserPromptSubmit` to `SessionStart`. Detection only needs to run once per conversation, not on every message.

```json
"SessionStart": [
  { "hooks": [{ "type": "command", "command": "bash .claude/hooks/detect-languages.sh" }] }
]
```

### 2. `.claude/hooks/detect-languages.sh` — Four targeted fixes

**a) Recursive manifest detection**

Replace `manifest_exists()` (root-only `[ -f "$PROJECT_ROOT/$1" ]`) with a recursive `find`:

```bash
manifest_exists() {
    find "$PROJECT_ROOT" \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/vendor/*" \
        -name "$1" 2>/dev/null | grep -q .
}
```

No depth limit — manifests are sparse, so this is fast. Covers monorepo layouts like `backend/pyproject.toml`, `frontend/package.json`, `services/user-service/pom.xml`.

**b) Deeper source file scan**

Bump `has_files` from `maxdepth 4` to `maxdepth 6`. Covers monorepo patterns like `services/user-service/src/*.go`.

**c) Java/Kotlin — manifest-only detection**

Drop `has_files "*.java"` and `has_files "*.kt"` fallbacks. Java package structures (`src/main/java/com/company/...`) go far deeper than any reasonable `maxdepth`. Detection via `pom.xml`, `build.gradle`, `build.gradle.kts` (now recursive) is sufficient and reliable.

**d) Fix `frontend` flag bash precedence bug**

Current (broken — `frontend=true` only fires for JavaScript, not TypeScript):
```bash
[ "$lang" = "typescript" ] || [ "$lang" = "javascript" ] && frontend=true && break
```

Fixed:
```bash
for lang in "${DETECTED[@]+"${DETECTED[@]}"}"; do
    if [ "$lang" = "typescript" ] || [ "$lang" = "javascript" ]; then
        frontend=true
        break
    fi
done
```

### 3. `install.sh` — Three places updated

- jq existence check: `[.hooks.UserPromptSubmit` → `[.hooks.SessionStart`
- jq merge expression: adds hook under `SessionStart` not `UserPromptSubmit`
- Manual fallback message: updated to reference `SessionStart`

### 4. `remote-install.sh` — Same three places as `install.sh`

### 5. `.claude/prompts/audit.md` — Two places updated

- Phase 1 table row: check `.claude/settings.json` contains `SessionStart` hook (not `UserPromptSubmit`)
- Fix logic (line 60): when auto-fixing settings.json, insert under `SessionStart`

### 6. `.claude/hooks/security-scan.sh` — Interpolation-aware value matching

**Problem:** The regex `[^"']{6,}` matches any 6+ char value between quotes, including template references like `${MY_KEY}`, `{{ .Values.key }}`, `#{ENV['KEY']}`, `@MY_KEY@`.

**Fix:** Tighten to `[^"'$#{%@<]{6,}` — excludes common interpolation sigils (`$`, `#`, `{`, `%`, `@`, `<`). A real hardcoded secret (e.g. `sk-proj-abc123...`) contains none of these. A template reference always contains at least one.

This covers all major interpolation styles without enumerating prefixes:

| Style | Sigil caught |
|-------|-------------|
| `$VAR` / `${VAR}` | `$` |
| `{{ VAR }}` | `{` |
| `%{VAR}` / `%(VAR)s` | `%` |
| `#{VAR}` | `#` |
| `@VAR@` | `@` |
| XML/template `<VAR>` | `<` |

Apply to both affected patterns:
- Hardcoded secret pattern: `["'][^"']{6,}` → `["'][^"'$#{%@<]{6,}`
- High-entropy pattern: `[A-Za-z0-9/+]{32,}` → `[A-Za-z0-9/+]{32,}` guarded by the same sigil exclusion — apply `[^"'$#{%@<]{32,}` for the value portion

## Files Changed

| File | Change |
|------|--------|
| `.claude/settings.json` | `UserPromptSubmit` → `SessionStart` for detect-languages hook |
| `.claude/hooks/detect-languages.sh` | Recursive manifests, depth 6, Java/Kotlin manifest-only, frontend bug fix |
| `install.sh` | 3 places: jq check, jq merge, manual fallback — `UserPromptSubmit` → `SessionStart` |
| `remote-install.sh` | Same 3 places as install.sh |
| `.claude/prompts/audit.md` | Phase 1 check row + fix logic — `UserPromptSubmit` → `SessionStart` |
| `.claude/hooks/security-scan.sh` | Value match: `[^"']{6,}` → `[^"'$#{%@<]{6,}` |

## Testing Notes

- Verify detection on a monorepo with `frontend/` (TS) + `backend/` (Python): both languages should appear in `active.md`
- Verify a Java project with only `backend/pom.xml` (no root manifest): Java should be detected
- Verify TypeScript-only project gets `accessibility.md` injected (frontend bug fix)
- Verify `api_key = "${MY_API_KEY}"` does not trigger security warning
- Verify `api_key = "sk-proj-abc123xyz789abc123xyz789abc1"` does trigger security warning
- Verify detection runs once at session start, not on each prompt
