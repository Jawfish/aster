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
