#!/usr/bin/env bash
#
# Check that test files are co-located with their SUTs.
#
# Rules:
# - Python: {name}_test.py must have {name}.py in same directory
# - TypeScript: {name}.test.ts(x) must have {name}.ts(x) in same directory
# - No test_*.py (wrong prefix)
# - No *.spec.ts(x) (use .test.ts(x))
# - No tests in tests/ or __tests__/ subdirectories

set -euo pipefail

target="${1:-.}"
violations=0

# Excluded directory patterns for grep -E
EXCLUDE_PATTERN="node_modules|\.git|__pycache__|dist|build|\.next|\.venv|venv|\.mypy_cache|\.pytest_cache|\.ruff_cache"

msg_wrong_test_prefix() {
	local file="$1"
	cat <<EOF
error[wrong-test-prefix]: Use suffix pattern {name}_test.py instead of prefix pattern test_{name}.py.

Our testing philosophy:
- Tests live next to their SUT (System Under Test)
- Tests are easy to find when navigating the codebase
- Refactoring a module includes its tests naturally

Why suffix naming matters:
- Alphabetical sorting groups tests with their SUT (service.py, service_test.py)
- Prefix naming separates them (service.py appears far from test_service.py)
- IDE file trees show related files together
- Tab-completion works naturally: type "service" to find both files

Example refactoring:
  # Before: Prefix pattern
  users/
    test_service.py    # Sorts under 't', far from service.py
    service.py

  # After: Suffix pattern
  users/
    service.py
    service_test.py    # Sorts right after service.py

  ┌─ $file
EOF
}

msg_wrong_test_suffix() {
	local file="$1"
	cat <<EOF
error[wrong-test-suffix]: Use .test.ts suffix instead of .spec.ts for consistency.

Our testing philosophy:
- Consistent naming across the codebase reduces cognitive load
- One convention is better than two
- Tests should be immediately recognizable

Why .test.ts over .spec.ts:
- Vitest and Jest both support .test.ts by default
- ".test" clearly indicates a test file
- Avoids mixing conventions (.spec from Angular/Jasmine era)
- Simpler glob patterns: **/*.test.ts

Example refactoring:
  # Before
  Button.spec.ts
  Button.spec.tsx

  # After
  Button.test.ts
  Button.test.tsx

  ┌─ $file
EOF
}

msg_test_not_colocated() {
	local file="$1"
	local dir="$2"
	cat <<EOF
error[test-not-colocated]: Test files should be colocated with their SUT, not in separate directories.

Our testing philosophy:
- Tests are part of the module, not a separate concern
- Related code stays together
- Refactoring moves tests with their SUT naturally

Why colocation matters:
- Separate test directories create distance between tests and code
- Developers must navigate to a different location to find tests
- Refactoring requires changes in multiple directory trees
- Easy to forget updating tests when they're "out of sight"

Example refactoring:
  # Before: Separate test directory
  users/
    service.py
  $dir/
    service_test.py    # Easy to forget, hard to find

  # After: Colocated tests
  users/
    service.py
    service_test.py    # Right next to the code it tests

  ┌─ $file
EOF
}

msg_orphaned_test() {
	local file="$1"
	local expected="$2"
	cat <<EOF
error[orphaned-test]: Test file has no matching SUT (System Under Test).

Our testing philosophy:
- Every test file corresponds to a source file
- Tests verify behavior of specific modules
- Naming conventions link tests to their SUT

Possible causes:
- SUT was renamed or moved without updating the test
- SUT was deleted but the test remains
- Test file naming doesn't follow {name}_test.py / {name}.test.ts convention
- Test covers code that should be extracted to its own module

How to fix:
1. Rename the test to match an existing SUT
2. Create the missing SUT if the test is valid
3. Delete the test if the SUT was intentionally removed
4. Move shared test utilities to a non-test file

  ┌─ $file (expected: $expected)
EOF
}

report_violation() {
	local rule="$1"
	local file="$2"
	local extra="${3:-}"

	case "$rule" in
	wrong-test-prefix)
		msg_wrong_test_prefix "$file"
		;;
	wrong-test-suffix)
		msg_wrong_test_suffix "$file"
		;;
	test-not-colocated)
		msg_test_not_colocated "$file" "$extra"
		;;
	orphaned-test)
		msg_orphaned_test "$file" "$extra"
		;;
	esac
	echo ""
	((violations++)) || true
}

# --- Python checks ---

# Wrong prefix: test_*.py (should be *_test.py)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "wrong-test-prefix" "$file"
done < <(find "$target" -type f -name "test_*.py" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In tests/ subdirectory
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "$file" "tests"
done < <(find "$target" -type f -name "*_test.py" -path "*/tests/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In test/ subdirectory (singular)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "$file" "test"
done < <(find "$target" -type f -name "*_test.py" -path "*/test/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# Orphaned Python test (no matching SUT)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	sut="${file%_test.py}.py"
	if [[ ! -f "$sut" ]]; then
		report_violation "orphaned-test" "$file" "$sut"
	fi
done < <(find "$target" -type f -name "*_test.py" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" | grep -Ev "/tests/|/test/" || true)

# --- TypeScript/TSX checks ---

# Spec files (should be .test.ts)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "wrong-test-suffix" "$file"
done < <(find "$target" -type f \( -name "*.spec.ts" -o -name "*.spec.tsx" \) 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In __tests__/ directory
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "$file" "__tests__"
done < <(find "$target" -type f \( -name "*.test.ts" -o -name "*.test.tsx" \) -path "*/__tests__/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In tests/ directory (TypeScript)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "$file" "tests"
done < <(find "$target" -type f \( -name "*.test.ts" -o -name "*.test.tsx" \) -path "*/tests/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# Orphaned .test.ts (no matching SUT)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	sut="${file%.test.ts}.ts"
	if [[ ! -f "$sut" ]]; then
		report_violation "orphaned-test" "$file" "$sut"
	fi
done < <(find "$target" -type f -name "*.test.ts" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" | grep -Ev "/__tests__/|/tests/" || true)

# Orphaned .test.tsx (no matching SUT)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	sut="${file%.test.tsx}.tsx"
	if [[ ! -f "$sut" ]]; then
		report_violation "orphaned-test" "$file" "$sut"
	fi
done < <(find "$target" -type f -name "*.test.tsx" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" | grep -Ev "/__tests__/|/tests/" || true)

# --- Summary ---

if [[ "$violations" -gt 0 ]]; then
	echo "Found $violations test colocation violation(s)."
	exit 1
else
	echo "No test colocation violations found."
	exit 0
fi
