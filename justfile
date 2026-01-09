# Aster - Cross-language lint rules

# Run all checks on a target directory
lint target=".":
    ./bin/aster lint {{target}}

# Run checks on changed lines only (vs main or specified base)
diff base="main":
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
