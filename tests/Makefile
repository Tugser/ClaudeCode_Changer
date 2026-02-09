.PHONY: help test test-unit test-integration test-macos test-linux test-cross test-verbose test-filter test-watch clean

# Default target
help:
	@echo "Provider Switch Tests"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-unit         - Run unit tests"
	@echo "  make test-integration  - Run integration tests"
	@echo "  make test-macos        - Run macOS-specific tests"
	@echo "  make test-linux        - Run Linux-specific tests"
	@echo "  make test-cross        - Run cross-platform tests"
	@echo "  make test-verbose      - Run tests with verbose output"
	@echo "  make test-filter       - Run tests matching pattern (FILTER=pattern)"
	@echo "  make test-watch        - Run tests in watch mode"
	@echo "  make clean             - Clean test artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-filter FILTER=sanitize_token"

# Check if bats is installed
check-bats:
	@command -v bats >/dev/null 2>&1 || { \
		echo "Error: bats is not installed."; \
		echo "Install with: brew install bats-core"; \
		exit 1; \
	}

# Run all tests
test: test-unit test-integration

# Run unit tests
test-unit:
	@echo "Running unit tests..."
	@cd tests && ./run_all_tests.sh

# Run integration tests
test-integration: check-bats
	@echo "Running integration tests..."
	bats tests/integration/

# Run macOS tests
test-macos: check-bats
	@echo "Running macOS-specific tests..."
	bats tests/integration/macos_provider_switch.bats

# Run Linux tests
test-linux: check-bats
	@echo "Running Linux-specific tests..."
	bats tests/integration/linux_provider_switch.bats

# Run cross-platform tests
test-cross: check-bats
	@echo "Running cross-platform tests..."
	bats tests/integration/cross_platform.bats

# Run with verbose output
test-verbose: check-bats
	@echo "Running tests with verbose output..."
	bats --print-output-on-failure --timing tests/integration/

# Run specific test pattern
test-filter:
	@if [ -z "$(FILTER)" ]; then \
		echo "Usage: make test-filter FILTER=pattern"; \
		exit 1; \
	fi
	bats --filter "$(FILTER)" tests/integration/

# Watch mode (requires entr tool)
test-watch:
	@command -v entr >/dev/null 2>&1 || { \
		echo "Error: entr is not installed. Install with: brew install entr"; \
		exit 1; \
	}
	@echo "Running tests in watch mode..."
	find . -name "*.bats" -o -name "*.sh" | entr -r bats tests/integration/

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	rm -rf /tmp/bats-*
	rm -rf .bats
	rm -rf tests/.claude
	@echo "Clean complete"
