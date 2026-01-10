#!/usr/bin/env bash
#
# Scan only changed lines.
#
# Usage:
#   scan-diff.sh              # Check unstaged changes (like git diff)
#   scan-diff.sh --staged     # Check staged changes
#   scan-diff.sh <base>       # Check changes vs base branch/commit
#
# Examples:
#   scan-diff.sh              # Unstaged changes (working tree vs index)
#   scan-diff.sh --staged     # Staged changes (index vs HEAD)
#   scan-diff.sh main         # Changes vs main branch
#   scan-diff.sh origin/main  # Changes vs origin/main
#   scan-diff.sh HEAD~5       # Changes vs 5 commits ago

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTER_ROOT="$(dirname "$SCRIPT_DIR")"
MODE="${1:-}"

# Use --no-ext-diff to avoid custom diff tools (delta, difftastic, etc.)
if [[ -z "$MODE" ]]; then
	# No argument: unstaged changes (working tree vs index)
	DIFF_CMD="git --no-pager diff --no-ext-diff"
	FILES_CMD="git diff --name-only"
	DISPLAY_MODE="unstaged changes"
elif [[ "$MODE" == "--staged" ]]; then
	# Staged changes (index vs HEAD)
	DIFF_CMD="git --no-pager diff --no-ext-diff --staged"
	FILES_CMD="git diff --staged --name-only"
	DISPLAY_MODE="staged changes"
else
	# Compare against a base ref
	DIFF_CMD="git --no-pager diff --no-ext-diff $MODE...HEAD"
	FILES_CMD="git diff --name-only $MODE...HEAD"
	DISPLAY_MODE="changes against $MODE"
fi

# Get changed files (only .ts, .tsx, .py files)
changed_files=$($FILES_CMD | grep -E '\.(ts|tsx|py)$' || true)

if [[ -z "$changed_files" ]]; then
	echo "No TypeScript or Python files changed."
	exit 0
fi

# Create a temporary file to store changed line ranges
line_ranges=$(mktemp)
trap 'rm -f "$line_ranges" /tmp/filtered_violations.json 2>/dev/null' EXIT

# Parse diff to extract changed line numbers per file
# Format: file:start_line:end_line
$DIFF_CMD --unified=0 | awk '
    /^--- a\// { next }
    /^\+\+\+ b\// {
        file = substr($2, 3)  # Remove "b/" prefix
    }
    /^@@ / {
        # Parse @@ -old,count +new,count @@ format
        match($3, /\+([0-9]+)(,([0-9]+))?/, arr)
        start = arr[1]
        count = arr[3] ? arr[3] : 1
        if (count > 0) {
            end = start + count - 1
            print file ":" start ":" end
        }
    }
' >"$line_ranges"

echo "Scanning $DISPLAY_MODE..."
echo ""

exit_code=0

# === AST-GREP RULES ===
echo "=== Running ast-grep rules ==="

# Run ast-grep and get JSON output
# shellcheck disable=SC2086 # Word splitting is intentional - $changed_files is newline-separated
ast_output=$(ast-grep scan --config "$ASTER_ROOT/sgconfig.yml" --json $changed_files 2>/dev/null || true)

if [[ -n "$ast_output" && "$ast_output" != "[]" ]]; then
	# Filter violations to only those on changed lines
	# Use jq to properly escape file paths in JSON
	echo "$ast_output" | jq -r --slurpfile ranges <(
		awk -F: '{print $1 "\t" $2 "\t" $3}' "$line_ranges" | jq -R 'split("\t") | {file: .[0], start: (.[1] | tonumber), end: (.[2] | tonumber)}'
	) '
        .[] |
        . as $violation |
        $violation.file as $file |
        $violation.range.start.line as $line |
        if any($ranges[]; .file == $file and .start <= ($line + 1) and ($line + 1) <= .end) then
            $violation
        else
            empty
        end
    ' | jq -s '.' >/tmp/filtered_violations.json

	filtered_count=$(jq 'length' /tmp/filtered_violations.json)

	if [[ "$filtered_count" != "0" ]]; then
		jq -r '.[] |
            "error[\(.ruleId)]: \(.message)\n" +
            "  ┌─ \(.file):\(.range.start.line + 1):\(.range.start.column + 1)\n" +
            "  │\n" +
            "  │ \(.text // .matchedCode // "")\n" +
            "  │\n"
        ' /tmp/filtered_violations.json
		echo "Found $filtered_count ast-grep violation(s) in changed code."
		exit_code=1
	else
		echo "No ast-grep violations in changed lines."
	fi
else
	echo "No ast-grep violations in changed lines."
fi

# === SUT NAME CHECK ===
echo ""
echo "=== Checking test naming conventions ==="

# Get changed test files only
changed_test_files=$(echo "$changed_files" | grep -E '(test_.*\.py|\.test\.tsx?|\.spec\.tsx?)$' || true)

if [[ -z "$changed_test_files" ]]; then
	echo "No test files changed."
else
	# Run SUT check on changed test files only (symbols from whole codebase)
	# The check-sut-names script needs source dir and test dir
	# We pass "." for source (to get all symbols) but filter test output

	# Create temp file with just changed test file paths
	changed_tests_file=$(mktemp)
	echo "$changed_test_files" >"$changed_tests_file"

	# Run a modified SUT check that only looks at specific test files
	sut_violations=0

	# Collect all symbols from the codebase
	symbols=""
	if command -v ast-grep &>/dev/null; then
		# TypeScript/JavaScript symbols
		symbols+=$(ast-grep --pattern 'function $NAME($$$) { $$$BODY }' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'function $NAME($$$): $TYPE { $$$BODY }' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'class $NAME { $$$BODY }' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'const $NAME = ($$$) => $BODY' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'const $NAME = ($$$): $TYPE => $BODY' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'const $NAME = async ($$$) => $BODY' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'const $NAME = async ($$$): $TYPE => $BODY' --lang typescript --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		# Python symbols
		symbols+=$(ast-grep --pattern 'def $NAME($$$): $$$BODY' --lang python --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
		symbols+=$'\n'
		symbols+=$(ast-grep --pattern 'class $NAME: $$$BODY' --lang python --json . 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
	fi

	# Normalize and filter symbols (min length 4, exclude test functions)
	symbols=$(echo "$symbols" | grep -v '^test_' | tr '[:upper:]' '[:lower:]' | tr -d '_' | awk 'length >= 4' | sort -u)

	if [[ -n "$symbols" ]]; then
		# Check test names in changed test files against symbols
		while IFS= read -r test_file; do
			[[ -z "$test_file" ]] && continue
			[[ ! -f "$test_file" ]] && continue

			# Get test names from this file
			test_names=""
			if [[ "$test_file" =~ \.py$ ]]; then
				test_names=$(ast-grep --pattern 'def $NAME($$$): $$$BODY' --lang python --json "$test_file" 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null | grep '^test_' || true)
			else
				test_names=$(ast-grep --pattern 'test($NAME, $$$)' --lang typescript --json "$test_file" 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
				test_names+=$'\n'
				test_names+=$(ast-grep --pattern 'it($NAME, $$$)' --lang typescript --json "$test_file" 2>/dev/null | jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true)
			fi

			# Check each test name against symbols
			while IFS= read -r test_name; do
				[[ -z "$test_name" ]] && continue

				# Normalize test name: lowercase, strip quotes, replace spaces with underscores
				normalized_test=$(echo "$test_name" | tr '[:upper:]' '[:lower:]' | tr -d '"'"'" | tr ' ' '_')

				# Split test name into segments
				IFS='_' read -ra segments <<<"$normalized_test"

				while IFS= read -r symbol; do
					[[ -z "$symbol" ]] && continue

					matched=false
					# Check all consecutive segment combinations
					for ((i = 0; i < ${#segments[@]}; i++)); do
						combo=""
						for ((j = i; j < ${#segments[@]}; j++)); do
							combo+="${segments[j]}"
							if [[ "$combo" == "$symbol" ]]; then
								echo "VIOLATION: Test '$test_name' in $test_file references symbol '$symbol'"
								sut_violations=$((sut_violations + 1))
								matched=true
								break 2
							fi
						done
					done

					[[ "$matched" == true ]] && break
				done <<<"$symbols"
			done <<<"$test_names"
		done <<<"$changed_test_files"
	fi

	rm -f "$changed_tests_file"

	if [[ "$sut_violations" -gt 0 ]]; then
		echo "Found $sut_violations SUT naming violation(s) in changed test files."
		exit_code=1
	else
		echo "No SUT naming violations in changed test files."
	fi
fi

# === TEST COLOCATION CHECK ===
echo ""
echo "=== Checking test file colocation ==="

colocation_violations=0

# Check changed test files for colocation issues
while IFS= read -r file; do
	[[ -z "$file" ]] && continue

	# Python: test_*.py is wrong prefix
	if [[ "$file" =~ ^.*/test_[^/]+\.py$ ]]; then
		echo "error[wrong-test-prefix]: Use {name}_test.py instead of test_{name}.py"
		echo "  --> $file"
		echo ""
		colocation_violations=$((colocation_violations + 1))
	fi

	# Python: *_test.py in tests/ or test/ directory
	if [[ "$file" =~ _test\.py$ ]] && [[ "$file" =~ /tests?/ ]]; then
		echo "error[test-not-colocated]: Test file should be next to SUT, not in tests/ directory"
		echo "  --> $file"
		echo ""
		colocation_violations=$((colocation_violations + 1))
	fi

	# Python: orphaned test (no matching SUT)
	if [[ "$file" =~ _test\.py$ ]] && [[ ! "$file" =~ /tests?/ ]] && [[ ! "$file" =~ ^test_ ]]; then
		sut="${file%_test.py}.py"
		if [[ ! -f "$sut" ]]; then
			echo "error[orphaned-test]: No matching SUT found"
			echo "  --> $file (expected: $sut)"
			echo ""
			colocation_violations=$((colocation_violations + 1))
		fi
	fi

	# TypeScript: *.spec.ts(x) is wrong suffix
	if [[ "$file" =~ \.spec\.tsx?$ ]]; then
		echo "error[wrong-test-suffix]: Use .test.ts instead of .spec.ts"
		echo "  --> $file"
		echo ""
		colocation_violations=$((colocation_violations + 1))
	fi

	# TypeScript: *.test.ts(x) in __tests__/ or tests/ directory
	if [[ "$file" =~ \.test\.tsx?$ ]] && [[ "$file" =~ /__tests__/|/tests/ ]]; then
		echo "error[test-not-colocated]: Test file should be next to SUT, not in __tests__/ directory"
		echo "  --> $file"
		echo ""
		colocation_violations=$((colocation_violations + 1))
	fi

	# TypeScript: orphaned .test.ts (no matching SUT)
	if [[ "$file" =~ \.test\.ts$ ]] && [[ ! "$file" =~ /__tests__/|/tests/ ]]; then
		sut="${file%.test.ts}.ts"
		if [[ ! -f "$sut" ]]; then
			echo "error[orphaned-test]: No matching SUT found"
			echo "  --> $file (expected: $sut)"
			echo ""
			colocation_violations=$((colocation_violations + 1))
		fi
	fi

	# TypeScript: orphaned .test.tsx (no matching SUT)
	if [[ "$file" =~ \.test\.tsx$ ]] && [[ ! "$file" =~ /__tests__/|/tests/ ]]; then
		sut="${file%.test.tsx}.tsx"
		if [[ ! -f "$sut" ]]; then
			echo "error[orphaned-test]: No matching SUT found"
			echo "  --> $file (expected: $sut)"
			echo ""
			colocation_violations=$((colocation_violations + 1))
		fi
	fi
done <<<"$changed_files"

if [[ "$colocation_violations" -gt 0 ]]; then
	echo "Found $colocation_violations test colocation violation(s) in changed files."
	exit_code=1
else
	echo "No test colocation violations in changed files."
fi

echo ""
if [[ "$exit_code" -eq 0 ]]; then
	echo "All checks passed on changed code."
else
	echo "Violations found in changed code."
fi

exit $exit_code
