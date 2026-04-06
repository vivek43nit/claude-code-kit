#!/usr/bin/env bash
# Test harness for detect-languages.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$SCRIPT_DIR/detect-languages.sh"
PASS=0
FAIL=0

run_test() {
    local name="$1"
    local setup_cmd="$2"
    local expected="$3"

    # Create temp project dir
    local tmpdir
    tmpdir=$(mktemp -d)

    mkdir -p "$tmpdir/guidelines"

    # Run setup
    eval "$setup_cmd" 2>/dev/null || true

    output=$(bash "$DETECT" "$tmpdir" 2>&1)

    if echo "$output" | grep -q "$expected"; then
        echo "  PASS: $name"
        ((PASS++)) || true
    else
        echo "  FAIL: $name — expected '$expected' in output: $output"
        ((FAIL++)) || true
    fi
    rm -rf "$tmpdir"
}

echo "Running detect-languages tests..."

run_test "detects Python via requirements.txt" \
    "touch \$tmpdir/requirements.txt" \
    "python"

run_test "detects TypeScript via tsconfig.json" \
    "touch \$tmpdir/tsconfig.json" \
    "typescript"

run_test "detects Go via go.mod" \
    "touch \$tmpdir/go.mod" \
    "go"

run_test "detects Java via pom.xml" \
    "touch \$tmpdir/pom.xml" \
    "java"

run_test "detects Kotlin via .kt file" \
    "mkdir -p \$tmpdir/src && touch \$tmpdir/src/Main.kt" \
    "kotlin"

run_test "detects Rust via Cargo.toml" \
    "touch \$tmpdir/Cargo.toml" \
    "rust"

run_test "no detection on empty project" \
    "" \
    "No specific language detected"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
