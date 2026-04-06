#!/usr/bin/env bash
# Test harness for security-scan.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="$SCRIPT_DIR/security-scan.sh"
PASS=0
FAIL=0

run_test() {
    local name="$1"
    local json_input="$2"
    local expect_warning="$3"  # "yes" or "no"

    output=$(echo "$json_input" | bash "$SCAN" 2>&1)
    exit_code=$?

    if [ "$expect_warning" = "yes" ]; then
        if echo "$output" | grep -qi "warning\|secret\|key\|credential\|private"; then
            echo "  PASS: $name"
            ((PASS++)) || true
        else
            echo "  FAIL: $name — expected warning, got exit=$exit_code output: $output"
            ((FAIL++)) || true
        fi
    else
        if echo "$output" | grep -qi "warning\|secret\|key\|credential\|private"; then
            echo "  FAIL: $name — unexpected warning: $output"
            ((FAIL++)) || true
        else
            echo "  PASS: $name"
            ((PASS++)) || true
        fi
    fi
}

echo "Running security-scan tests..."

CLEAN='{"tool_name":"Write","tool_input":{"file_path":"app.py","content":"def hello():\n    return \"world\""}}'
HARDCODED_PW='{"tool_name":"Write","tool_input":{"file_path":"config.py","content":"password = \"supersecret123\""}}'
AWS_KEY='{"tool_name":"Write","tool_input":{"file_path":"deploy.sh","content":"export AWS_KEY=AKIAIOSFODNN7EXAMPLE"}}'
PRIVATE_KEY='{"tool_name":"Write","tool_input":{"file_path":"key.pem","content":"-----BEGIN RSA PRIVATE KEY-----\nMIIE..."}}'
ENV_VAR_OK='{"tool_name":"Write","tool_input":{"file_path":"config.py","content":"password = os.getenv(\"PASSWORD\")"}}'

run_test "clean code passes without warning" "$CLEAN" "no"
run_test "hardcoded password triggers warning" "$HARDCODED_PW" "yes"
run_test "AWS access key triggers warning" "$AWS_KEY" "yes"
run_test "private key triggers warning" "$PRIVATE_KEY" "yes"
run_test "env var reference is safe" "$ENV_VAR_OK" "no"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
