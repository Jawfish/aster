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

report_violation() {
	local rule="$1"
	local message="$2"
	local file="$3"
	local extra="${4:-}"

	echo "error[$rule]: $message"
	if [[ -n "$extra" ]]; then
		echo "  --> $file ($extra)"
	else
		echo "  --> $file"
	fi
	echo ""
	((violations++)) || true
}

# --- Python checks ---

# Wrong prefix: test_*.py (should be *_test.py)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "wrong-test-prefix" "Use {name}_test.py instead of test_{name}.py" "$file"
done < <(find "$target" -type f -name "test_*.py" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In tests/ subdirectory
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "Test file should be next to SUT, not in tests/ directory" "$file"
done < <(find "$target" -type f -name "*_test.py" -path "*/tests/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In test/ subdirectory (singular)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "Test file should be next to SUT, not in test/ directory" "$file"
done < <(find "$target" -type f -name "*_test.py" -path "*/test/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# Orphaned Python test (no matching SUT)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	sut="${file%_test.py}.py"
	if [[ ! -f "$sut" ]]; then
		report_violation "orphaned-test" "No matching SUT found" "$file" "expected: $sut"
	fi
done < <(find "$target" -type f -name "*_test.py" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" | grep -Ev "/tests/|/test/" || true)

# --- TypeScript/TSX checks ---

# Spec files (should be .test.ts)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "wrong-test-suffix" "Use .test.ts instead of .spec.ts" "$file"
done < <(find "$target" -type f \( -name "*.spec.ts" -o -name "*.spec.tsx" \) 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In __tests__/ directory
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "Test file should be next to SUT, not in __tests__/ directory" "$file"
done < <(find "$target" -type f \( -name "*.test.ts" -o -name "*.test.tsx" \) -path "*/__tests__/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# In tests/ directory (TypeScript)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	report_violation "test-not-colocated" "Test file should be next to SUT, not in tests/ directory" "$file"
done < <(find "$target" -type f \( -name "*.test.ts" -o -name "*.test.tsx" \) -path "*/tests/*" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" || true)

# Orphaned .test.ts (no matching SUT)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	sut="${file%.test.ts}.ts"
	if [[ ! -f "$sut" ]]; then
		report_violation "orphaned-test" "No matching SUT found" "$file" "expected: $sut"
	fi
done < <(find "$target" -type f -name "*.test.ts" 2>/dev/null | grep -Ev "$EXCLUDE_PATTERN" | grep -Ev "/__tests__/|/tests/" || true)

# Orphaned .test.tsx (no matching SUT)
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	sut="${file%.test.tsx}.tsx"
	if [[ ! -f "$sut" ]]; then
		report_violation "orphaned-test" "No matching SUT found" "$file" "expected: $sut"
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
