# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aster is a cross-language linting tool for testing best practices. It enforces behavior-driven testing patterns and discourages mocking in both TypeScript and Python codebases. Built on ast-grep for AST-based rule matching.

## Commands

```bash
just lint <target>     # Run all checks on directory (default: ".")
just diff              # Check unstaged changes only
just diff <base>       # Check changes vs base branch
just staged            # Check staged changes only (for pre-commit)
just test              # Test the rules themselves
just help              # Show help
```

## Architecture

```
bin/aster              # Main CLI entry point
scripts/
  scan-diff.sh         # Diff-aware scanning (filters violations to changed lines)
  check-sut-names.sh   # Detects test names referencing implementation symbols
rules/
  typescript/          # TypeScript/JavaScript ast-grep rules
  python/              # Python ast-grep rules
rule-tests/            # ast-grep test cases (valid/invalid examples)
sgconfig.yml           # ast-grep configuration
```

## Rule Categories

The linter enforces these testing patterns:

1. **No mocking** (`no-mocks`) - Detects vi.mock, jest.mock, sinon, patch, etc.
2. **No interaction assertions** (`no-interaction-assertions`) - Detects toHaveBeenCalled assertions
3. **No "should" in test names** (`no-test-name-with-should`) - Tests state facts, not wishes
4. **No method names in test names** (`no-test-name-with-method-names`) - Tests describe behavior, not implementation
5. **No misleading test double names** (`no-misleading-test-double-names`) - "mock" prefix implies mocking
6. **Assert with message** (`assert-with-message`) - Python assertions should have messages

## Writing Rules

**Always use the `/ast-grep` skill when writing or modifying rules.** This skill provides full ast-grep documentation including pattern syntax, rule types, transforms, and language-specific examples.

Rules are YAML files following ast-grep's format:

```yaml
id: rule-name
language: TypeScript  # or Python
severity: error
message: |
  Explanation of why this pattern is problematic.
rule:
  pattern: vi.mock($$$)  # ast-grep pattern
```

Test rules with `just test`. Test files in `rule-tests/` use the format:

```yaml
id: rule-name
valid:
  - "code that should not trigger"
invalid:
  - "code that should trigger"
```

## Dependencies

- `ast-grep` - AST pattern matching
- `jq` - JSON processing in scripts
