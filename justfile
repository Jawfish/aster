# Aster - Cross-language lint rules

# Install git hooks
init:
    ln -sf ../../.hooks/pre-commit .git/hooks/pre-commit
    ln -sf ../../.hooks/pre-push .git/hooks/pre-push
    @echo "Git hooks installed."

# Run all checks on a target directory
lint target=".":
    ./bin/aster lint {{target}}

# Run checks on unstaged changes (like git diff)
diff:
    ./bin/aster diff

# Run checks on changes vs a base branch
diff-base base:
    ./bin/aster diff {{base}}

# Run checks on staged changes only
staged:
    ./bin/aster staged

# Test the rules themselves
test:
    ./bin/aster test
    @echo ""
    @echo "=== Running bats tests ==="
    bats tests/

# Show help
help:
    ./bin/aster help

# === CI Linting ===

# Run all CI linters
ci: lint-yaml lint-scripts lint-actions

# Lint YAML files
lint-yaml:
    yamlfmt -lint .

# Format YAML files
fmt-yaml:
    yamlfmt .

# Lint shell scripts
lint-scripts:
    shfmt -d bin/aster scripts/*.sh .hooks/*
    shellcheck -e SC2016 bin/aster scripts/*.sh .hooks/*

# Format shell scripts
fmt-scripts:
    shfmt -w bin/aster scripts/*.sh .hooks/*

# Lint GitHub Actions workflows
lint-actions:
    actionlint

# Run CI locally with act
act *args:
    act --container-architecture linux/amd64 {{args}}
