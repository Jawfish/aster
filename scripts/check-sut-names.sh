#!/usr/bin/env bash
#
# Detect test names that reference implementation symbols.
# Tests should describe behavior, not implementation details.
#
# Usage: ./check-sut-names.sh [source_dir] [test_dir]
#   source_dir: Directory containing source code (default: src)
#   test_dir:   Directory containing tests (default: src or tests)

set -euo pipefail

SOURCE_DIR="${1:-src}"
TEST_DIR="${2:-$SOURCE_DIR}"

# Minimum symbol length to check (avoids false positives from short words)
MIN_LENGTH=4

# Collect TypeScript/JavaScript symbols
collect_ts_symbols() {
    local dir="$1"

    # Function declarations: function foo() {}
    ast-grep --pattern 'function $NAME($$$) { $$$BODY }' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Class declarations: class Foo {}
    ast-grep --pattern 'class $NAME { $$$BODY }' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Arrow functions: const foo = () => {}
    ast-grep --pattern 'const $NAME = ($$$) => $BODY' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true
}

# Collect Python symbols
collect_py_symbols() {
    local dir="$1"

    # Function definitions: def foo():
    ast-grep --pattern 'def $NAME($$$): $$$BODY' --lang python --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Class definitions: class Foo:
    ast-grep --pattern 'class $NAME: $$$BODY' --lang python --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true
}

# Collect TypeScript test names
collect_ts_tests() {
    local dir="$1"

    # test("name", ...) or it("name", ...)
    ast-grep --pattern 'test($NAME, $$$)' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    ast-grep --pattern 'it($NAME, $$$)' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true
}

# Collect Python test names
collect_py_tests() {
    local dir="$1"

    # def test_foo():
    ast-grep --pattern 'def $NAME($$$): $$$BODY' --lang python --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null | \
        grep '^test_' || true
}

# Normalize to lowercase for comparison
normalize() {
    tr '[:upper:]' '[:lower:]' | tr '_' '\n' | sort -u
}

# Main logic
main() {
    local symbols=""
    local tests=""
    local violations=0

    echo "Collecting symbols from $SOURCE_DIR..."

    # Collect symbols from source files
    if [ -d "$SOURCE_DIR" ]; then
        symbols+=$(collect_ts_symbols "$SOURCE_DIR")
        symbols+=$'\n'
        symbols+=$(collect_py_symbols "$SOURCE_DIR")
    fi

    # Filter to unique symbols above minimum length
    symbols=$(echo "$symbols" | normalize | awk -v min="$MIN_LENGTH" 'length >= min' | sort -u)

    if [ -z "$symbols" ]; then
        echo "No symbols found in $SOURCE_DIR"
        exit 0
    fi

    echo "Found $(echo "$symbols" | wc -l) unique symbols"
    echo ""
    echo "Checking test names in $TEST_DIR..."

    # Collect test names
    if [ -d "$TEST_DIR" ]; then
        tests+=$(collect_ts_tests "$TEST_DIR")
        tests+=$'\n'
        tests+=$(collect_py_tests "$TEST_DIR")
    fi

    # Check each test name for symbol references
    while IFS= read -r test_name; do
        [ -z "$test_name" ] && continue

        normalized_test=$(echo "$test_name" | normalize)

        while IFS= read -r symbol; do
            [ -z "$symbol" ] && continue

            if echo "$normalized_test" | grep -q "^${symbol}$"; then
                echo "VIOLATION: Test '$test_name' references symbol '$symbol'"
                violations=$((violations + 1))
            fi
        done <<< "$symbols"
    done <<< "$tests"

    echo ""
    if [ "$violations" -gt 0 ]; then
        echo "Found $violations test(s) referencing implementation symbols."
        echo "Tests should describe behavior, not implementation details."
        exit 1
    else
        echo "All tests use behavior-focused names."
        exit 0
    fi
}

main
