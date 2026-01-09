#!/usr/bin/env bash
#
# Scan only changed lines in the current branch.
#
# Usage:
#   scan-diff.sh [base_ref]
#
# Arguments:
#   base_ref: The base branch/commit to compare against (default: main)
#
# Examples:
#   scan-diff.sh              # Compare against main
#   scan-diff.sh origin/main  # Compare against origin/main
#   scan-diff.sh HEAD~5       # Compare against 5 commits ago
#   scan-diff.sh --staged     # Check only staged changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTER_ROOT="$(dirname "$SCRIPT_DIR")"
BASE_REF="${1:-main}"

# Handle --staged flag
# Use --no-ext-diff to avoid custom diff tools (delta, difftastic, etc.)
if [[ "$BASE_REF" == "--staged" ]]; then
    DIFF_CMD="git --no-pager diff --no-ext-diff --staged"
    FILES_CMD="git diff --staged --name-only"
else
    DIFF_CMD="git --no-pager diff --no-ext-diff $BASE_REF...HEAD"
    FILES_CMD="git diff --name-only $BASE_REF...HEAD"
fi

# Get changed files (only .ts, .tsx, .py files)
changed_files=$($FILES_CMD | grep -E '\.(ts|tsx|py)$' || true)

if [[ -z "$changed_files" ]]; then
    echo "No TypeScript or Python files changed."
    exit 0
fi

# Create a temporary file to store changed line ranges
line_ranges=$(mktemp)
trap "rm -f $line_ranges" EXIT

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
' > "$line_ranges"

# Run ast-grep on changed files and filter to changed lines
echo "Scanning changes against $BASE_REF..."
echo ""

violations=0

# Run ast-grep and get JSON output
ast_output=$(ast-grep scan --config "$ASTER_ROOT/sgconfig.yml" --json $changed_files 2>/dev/null || true)

if [[ -z "$ast_output" || "$ast_output" == "[]" ]]; then
    echo "No violations found in changed code."
    exit 0
fi

# Filter violations to only those on changed lines
echo "$ast_output" | jq -r --slurpfile ranges <(
    # Convert line ranges to JSON for jq
    cat "$line_ranges" | awk -F: '{print "{\"file\":\"" $1 "\",\"start\":" $2 ",\"end\":" $3 "}"}'
) '
    .[] |
    . as $violation |
    $violation.file as $file |
    $violation.range.start.line as $line |

    # Check if this violation is on a changed line
    if any($ranges[]; .file == $file and .start <= ($line + 1) and ($line + 1) <= .end) then
        $violation
    else
        empty
    end
' | jq -s '.' > /tmp/filtered_violations.json

# Check if we have any violations after filtering
filtered_count=$(jq 'length' /tmp/filtered_violations.json)

if [[ "$filtered_count" == "0" ]]; then
    echo "No violations found in changed lines."
    rm -f /tmp/filtered_violations.json
    exit 0
fi

# Pretty print the filtered violations (full message)
jq -r '.[] |
    "error[\(.ruleId)]: \(.message)\n" +
    "  ┌─ \(.file):\(.range.start.line + 1):\(.range.start.column + 1)\n" +
    "  │\n" +
    "  │ \(.text // .matchedCode // "")\n" +
    "  │\n"
' /tmp/filtered_violations.json

echo ""
echo "Found $filtered_count violation(s) in changed code."

rm -f /tmp/filtered_violations.json
exit 1
