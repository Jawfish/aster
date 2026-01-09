#!/usr/bin/env bash
#
# Run all custom lint rules.
#
# Usage: ./lint.sh [target_dir]
#   target_dir: Directory to lint (default: current directory)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTER_ROOT="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="${1:-.}"

exit_code=0

echo "=== Running ast-grep rules ==="
if ! ast-grep scan --config "$ASTER_ROOT/sgconfig.yml" "$TARGET_DIR"; then
	exit_code=1
fi

echo ""
echo "=== Checking test naming conventions ==="
if ! "$SCRIPT_DIR/check-sut-names.sh" "$TARGET_DIR" "$TARGET_DIR"; then
	exit_code=1
fi

exit $exit_code
