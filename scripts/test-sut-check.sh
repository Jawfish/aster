#!/usr/bin/env bash
#
# Test suite for the SUT name check
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check-sut-names.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0

# Test helper
run_test() {
	local name="$1"
	local expected_violations="$2"

	output=$("$CHECK_SCRIPT" "$TEST_DIR" "$TEST_DIR" 2>&1) || true
	actual_violations=$(echo "$output" | grep -c "^VIOLATION:" || true)
	actual_violations=${actual_violations:-0}

	if [[ "$actual_violations" -eq "$expected_violations" ]]; then
		echo "PASS: $name"
		pass=$((pass + 1))
	else
		echo "FAIL: $name"
		echo "  Expected $expected_violations violations, got $actual_violations"
		echo "  Output: $output"
		fail=$((fail + 1))
	fi

	# Clean up test files
	rm -f "$TEST_DIR"/*.py "$TEST_DIR"/*.ts
}

# Test 1: Function name in test should flag
echo "--- Test: Function name in test name flags ---"
cat >"$TEST_DIR/calculator.py" <<'EOF'
def calculate_total(items):
    return sum(items)
EOF
cat >"$TEST_DIR/test_calculator.py" <<'EOF'
def test_calculate_total_returns_sum():
    pass
EOF
run_test "function name in test" 1

# Test 2: Class name in test should flag
echo "--- Test: Class name in test name flags ---"
cat >"$TEST_DIR/service.py" <<'EOF'
class UserService:
    pass
EOF
cat >"$TEST_DIR/test_service.py" <<'EOF'
def test_user_service_creates_user():
    pass
EOF
run_test "class name in test" 1

# Test 3: Behavior-focused test should not flag
echo "--- Test: Behavior-focused test does not flag ---"
cat >"$TEST_DIR/calculator.py" <<'EOF'
def calculate_total(items):
    return sum(items)
EOF
cat >"$TEST_DIR/test_calculator.py" <<'EOF'
def test_sum_of_items_is_correct():
    pass
EOF
run_test "behavior-focused test" 0

# Test 4: CamelCase class matches snake_case test
echo "--- Test: CamelCase class matches snake_case test ---"
cat >"$TEST_DIR/auth.py" <<'EOF'
class AuthenticationService:
    pass
EOF
cat >"$TEST_DIR/test_auth.py" <<'EOF'
def test_authentication_service_validates_token():
    pass
EOF
run_test "CamelCase to snake_case" 1

# Test 5: Short symbol names should not flag (< 4 chars)
echo "--- Test: Short symbols (< 4 chars) do not flag ---"
cat >"$TEST_DIR/app.py" <<'EOF'
def run():
    pass

class App:
    pass
EOF
cat >"$TEST_DIR/test_app.py" <<'EOF'
def test_run_starts_server():
    pass

def test_app_initializes():
    pass
EOF
run_test "short symbols ignored" 0

# Test 6: Multiple functions, only matching one flags
echo "--- Test: Only matching symbol flags ---"
cat >"$TEST_DIR/utils.py" <<'EOF'
def fetch_user(id):
    pass

def send_email(to, body):
    pass
EOF
cat >"$TEST_DIR/test_utils.py" <<'EOF'
def test_fetch_user_returns_none_for_invalid_id():
    pass

def test_email_is_sent_successfully():
    pass
EOF
run_test "only matching symbol" 1

# Test 7: TypeScript function in test name
echo "--- Test: TypeScript function name in test flags ---"
cat >"$TEST_DIR/calculator.ts" <<'EOF'
function calculateTotal(items: number[]): number {
    return items.reduce((a, b) => a + b, 0);
}
EOF
cat >"$TEST_DIR/calculator.test.ts" <<'EOF'
test("calculateTotal returns sum of items", () => {
    expect(calculateTotal([1, 2, 3])).toBe(6);
});
EOF
run_test "TypeScript function in test" 1

# Test 8: TypeScript behavior test should not flag
echo "--- Test: TypeScript behavior test does not flag ---"
cat >"$TEST_DIR/calculator.ts" <<'EOF'
function calculateTotal(items: number[]): number {
    return items.reduce((a, b) => a + b, 0);
}
EOF
cat >"$TEST_DIR/calculator.test.ts" <<'EOF'
test("sum of numbers is computed correctly", () => {
    expect(calculateTotal([1, 2, 3])).toBe(6);
});
EOF
run_test "TypeScript behavior test" 0

# Test 9: Arrow function in test name
echo "--- Test: Arrow function name in test flags ---"
cat >"$TEST_DIR/api.ts" <<'EOF'
const fetchUserData = async (id: string) => {
    return { id, name: "test" };
};
EOF
cat >"$TEST_DIR/api.test.ts" <<'EOF'
test("fetchUserData returns user object", () => {});
EOF
run_test "arrow function in test" 1

# Test 10: Substring should not match (user vs username)
echo "--- Test: Substring does not match ---"
cat >"$TEST_DIR/user.py" <<'EOF'
def user():
    pass
EOF
cat >"$TEST_DIR/test_user.py" <<'EOF'
def test_username_is_valid():
    pass
EOF
run_test "substring no match" 0

# Test 11: Exact segment match with substring present
echo "--- Test: Exact segment matches even with substring elsewhere ---"
cat >"$TEST_DIR/user.py" <<'EOF'
def user():
    pass
EOF
cat >"$TEST_DIR/test_user.py" <<'EOF'
def test_user_and_username_validation():
    pass
EOF
run_test "exact segment with substring" 1

# Test 12: Multi-word symbol matches consecutive segments
echo "--- Test: Multi-word symbol matches consecutive segments ---"
cat >"$TEST_DIR/api.py" <<'EOF'
def fetch_user_data():
    pass
EOF
cat >"$TEST_DIR/test_api.py" <<'EOF'
def test_fetch_user_data_returns_dict():
    pass
EOF
run_test "multi-word symbol match" 1

# Test 13: Partial multi-word symbol should not match
echo "--- Test: Partial multi-word symbol does not match ---"
cat >"$TEST_DIR/api.py" <<'EOF'
def fetch_user_data():
    pass
EOF
cat >"$TEST_DIR/test_api.py" <<'EOF'
def test_fetch_user_returns_none():
    pass
EOF
run_test "partial multi-word no match" 0

# Test 14: TypeScript with camelCase in test string
echo "--- Test: TypeScript camelCase in test string matches ---"
cat >"$TEST_DIR/utils.ts" <<'EOF'
function getUserById(id: string): User {
    return users[id];
}
EOF
cat >"$TEST_DIR/utils.test.ts" <<'EOF'
test("getUserById returns user object", () => {});
EOF
run_test "TypeScript camelCase match" 1

# Test 15: Short symbols (< 4 chars) should be ignored
echo "--- Test: Short symbols ignored ---"
cat >"$TEST_DIR/cls.py" <<'EOF'
class Foo:
    def run(self):
        pass
    def go(self):
        pass
EOF
cat >"$TEST_DIR/test_cls.py" <<'EOF'
def test_run_completes():
    pass
def test_go_returns_value():
    pass
EOF
run_test "short symbols ignored" 0

# Summary
echo ""
echo "================================"
echo "Results: $pass passed, $fail failed"
echo "================================"

if [[ "$fail" -gt 0 ]]; then
	exit 1
fi
