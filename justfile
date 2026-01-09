# Aster - Cross-language lint rules

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
    shfmt -d bin/aster scripts/*.sh
    shellcheck -e SC2016 bin/aster scripts/*.sh

# Format shell scripts
fmt-scripts:
    shfmt -w bin/aster scripts/*.sh

# Lint GitHub Actions workflows
lint-actions:
    actionlint

# Run CI locally with act
act *args:
    act --container-architecture linux/amd64 {{args}}
