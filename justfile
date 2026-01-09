# Aster - Cross-language lint rules

# Run all checks on a target directory
lint target=".":
    ./bin/aster lint {{target}}

# Run only ast-grep rules
scan target=".":
    ./bin/aster scan {{target}}

# Run only test naming check
check-names target=".":
    ./bin/aster check-names {{target}}

# Test the rules themselves
test:
    ./bin/aster test

# Show help
help:
    ./bin/aster help
