#!/usr/bin/env bats
# Tests for check-test-colocation.sh

setup() {
	TEST_DIR="$(mktemp -d)"
	SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-test-colocation.sh"
}

teardown() {
	rm -rf "$TEST_DIR"
}

# --- Python: Valid cases ---

@test "python: valid test file next to SUT passes" {
	mkdir -p "$TEST_DIR/users"
	echo "" >"$TEST_DIR/users/service.py"
	echo "" >"$TEST_DIR/users/service_test.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 0 ]
	[[ "$output" == *"No test colocation violations"* ]]
}

@test "python: multiple valid test files pass" {
	mkdir -p "$TEST_DIR/users"
	echo "" >"$TEST_DIR/users/service.py"
	echo "" >"$TEST_DIR/users/service_test.py"
	echo "" >"$TEST_DIR/users/models.py"
	echo "" >"$TEST_DIR/users/models_test.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 0 ]
}

# --- Python: Invalid cases ---

@test "python: wrong prefix test_*.py is flagged" {
	mkdir -p "$TEST_DIR/users"
	echo "" >"$TEST_DIR/users/test_service.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[wrong-test-prefix]"* ]]
	[[ "$output" == *"test_service.py"* ]]
}

@test "python: orphaned test without SUT is flagged" {
	mkdir -p "$TEST_DIR/users"
	echo "" >"$TEST_DIR/users/orphan_test.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[orphaned-test]"* ]]
	[[ "$output" == *"expected:"* ]]
}

@test "python: test in tests/ subdirectory is flagged" {
	mkdir -p "$TEST_DIR/users/tests"
	echo "" >"$TEST_DIR/users/tests/service_test.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[test-not-colocated]"* ]]
}

@test "python: test in test/ subdirectory is flagged" {
	mkdir -p "$TEST_DIR/users/test"
	echo "" >"$TEST_DIR/users/test/service_test.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[test-not-colocated]"* ]]
}

# --- TypeScript: Valid cases ---

@test "typescript: valid .test.ts file next to SUT passes" {
	mkdir -p "$TEST_DIR/components"
	echo "" >"$TEST_DIR/components/Button.ts"
	echo "" >"$TEST_DIR/components/Button.test.ts"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 0 ]
}

@test "typescript: valid .test.tsx file next to SUT passes" {
	mkdir -p "$TEST_DIR/components"
	echo "" >"$TEST_DIR/components/Button.tsx"
	echo "" >"$TEST_DIR/components/Button.test.tsx"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 0 ]
}

# --- TypeScript: Invalid cases ---

@test "typescript: .spec.ts file is flagged" {
	mkdir -p "$TEST_DIR/components"
	echo "" >"$TEST_DIR/components/Button.spec.ts"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[wrong-test-suffix]"* ]]
}

@test "typescript: .spec.tsx file is flagged" {
	mkdir -p "$TEST_DIR/components"
	echo "" >"$TEST_DIR/components/Button.spec.tsx"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[wrong-test-suffix]"* ]]
}

@test "typescript: test in __tests__/ directory is flagged" {
	mkdir -p "$TEST_DIR/components/__tests__"
	echo "" >"$TEST_DIR/components/__tests__/Button.test.tsx"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[test-not-colocated]"* ]]
}

@test "typescript: test in tests/ directory is flagged" {
	mkdir -p "$TEST_DIR/components/tests"
	echo "" >"$TEST_DIR/components/tests/Button.test.tsx"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[test-not-colocated]"* ]]
}

@test "typescript: orphaned .test.ts without SUT is flagged" {
	mkdir -p "$TEST_DIR/components"
	echo "" >"$TEST_DIR/components/Orphan.test.ts"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[orphaned-test]"* ]]
}

@test "typescript: orphaned .test.tsx without SUT is flagged" {
	mkdir -p "$TEST_DIR/components"
	echo "" >"$TEST_DIR/components/Orphan.test.tsx"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"error[orphaned-test]"* ]]
}

# --- Edge cases ---

@test "empty directory passes" {
	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 0 ]
}

@test "multiple violations are all reported" {
	mkdir -p "$TEST_DIR/users"
	echo "" >"$TEST_DIR/users/test_one.py"
	echo "" >"$TEST_DIR/users/test_two.py"
	echo "" >"$TEST_DIR/users/orphan_test.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Found 3 test colocation violation"* ]]
}

@test "excluded directories are ignored" {
	mkdir -p "$TEST_DIR/node_modules/pkg"
	mkdir -p "$TEST_DIR/.git/hooks"
	mkdir -p "$TEST_DIR/__pycache__"
	echo "" >"$TEST_DIR/node_modules/pkg/test_bad.py"
	echo "" >"$TEST_DIR/.git/hooks/test_bad.py"
	echo "" >"$TEST_DIR/__pycache__/test_bad.py"

	run "$SCRIPT" "$TEST_DIR"

	[ "$status" -eq 0 ]
}
