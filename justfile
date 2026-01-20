# MoonBit Project Commands

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check
check:
    moon check --deny-warn

# Run tests
test:
    moon test

# Update snapshot tests
test-update:
    moon test --update

# Run main
run:
    moon run src/main

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test
