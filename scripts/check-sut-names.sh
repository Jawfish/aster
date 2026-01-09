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

    # Function declarations without return type: function foo() {}
    ast-grep --pattern 'function $NAME($$$) { $$$BODY }' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Function declarations with return type: function foo(): Type {}
    ast-grep --pattern 'function $NAME($$$): $TYPE { $$$BODY }' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Class declarations: class Foo {}
    ast-grep --pattern 'class $NAME { $$$BODY }' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Arrow functions: const foo = () => {}
    ast-grep --pattern 'const $NAME = ($$$) => $BODY' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Arrow functions with return type: const foo = (): Type => {}
    ast-grep --pattern 'const $NAME = ($$$): $TYPE => $BODY' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Async arrow functions: const foo = async () => {}
    ast-grep --pattern 'const $NAME = async ($$$) => $BODY' --lang typescript --json "$dir" 2>/dev/null | \
        jq -r '.[].metaVariables.single.NAME.text // empty' 2>/dev/null || true

    # Async arrow functions with return type: const foo = async (): Type => {}
    ast-grep --pattern 'const $NAME = async ($$$): $TYPE => $BODY' --lang typescript --json "$dir" 2>/dev/null | \
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

# Normalize symbol: lowercase and remove underscores (UserService -> userservice)
normalize_symbol() {
    tr '[:upper:]' '[:lower:]' | tr -d '_'
}

# Normalize test name: lowercase, keep underscores for word boundary matching
normalize_test() {
    tr '[:upper:]' '[:lower:]'
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

    # Filter to unique symbols above minimum length (exclude test functions)
    symbols=$(echo "$symbols" | grep -v '^test_' | normalize_symbol | awk -v min="$MIN_LENGTH" 'length >= min' | sort -u)

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

        # Normalize test name: lowercase, strip quotes, replace spaces/underscores with single delimiter
        normalized_test=$(echo "$test_name" | tr '[:upper:]' '[:lower:]' | tr -d '"'"'" | tr ' ' '_')

        # Split test name into segments and build all consecutive combinations
        IFS='_' read -ra segments <<< "$normalized_test"

        while IFS= read -r symbol; do
            [ -z "$symbol" ] && continue

            matched=false
            # Check all consecutive segment combinations
            for ((i=0; i<${#segments[@]}; i++)); do
                combo=""
                for ((j=i; j<${#segments[@]}; j++)); do
                    combo+="${segments[j]}"
                    if [[ "$combo" == "$symbol" ]]; then
                        echo "VIOLATION: Test '$test_name' references symbol '$symbol'"
                        violations=$((violations + 1))
                        matched=true
                        break 2
                    fi
                done
            done

            [[ "$matched" == true ]] && break
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
