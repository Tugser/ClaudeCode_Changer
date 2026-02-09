# Unit Tests for Provider Switch Scripts

This directory contains comprehensive unit tests for the macOS and Linux provider switch scripts.

## Test Structure

```
tests/
├── unit/
│   ├── test_sanitize_token.sh      # Tests for sanitize_token() function
│   ├── test_settings_json.sh       # Tests for settings.json manipulation
│   └── test_secret_storage.sh      # Tests for secret storage (keychain/file)
├── helpers/                        # Test helper libraries (optional)
└── run_all_tests.sh               # Run all test suites
```

## Running Tests

### Run All Tests
```bash
cd tests
./run_all_tests.sh
```

### Run Individual Test Suites
```bash
# Test sanitize_token function
./unit/test_sanitize_token.sh

# Test settings.json manipulation
./unit/test_settings_json.sh

# Test secret storage
./unit/test_secret_storage.sh
```

## Test Coverage

### 1. sanitize_token() Tests (test_sanitize_token.sh)

Tests token validation and sanitization:
- ✓ Valid ASCII token (10/10 score)
- ✓ Bearer prefix stripping (10/10 score)
- ✓ Whitespace detection and rejection
- ✓ Non-ASCII character rejection
- ✓ Empty token rejection
- ✓ Special characters handling
- ✓ Edge cases (emoji, tabs, newlines, etc.)

**Passing criteria**: 10/10 for valid tokens, fail for invalid tokens

### 2. settings.json Manipulation Tests (test_settings_json.sh)

Tests JSON manipulation functions:
- ✓ `set_env_string()` - Set environment variables in settings.json
- ✓ `remove_env_key()` - Remove keys from settings.json
- ✓ `get_env_value()` - Retrieve values from settings.json
- ✓ `clear_provider_overrides()` - Clear all provider-specific overrides
- ✓ JSON validity maintenance
- ✓ Special character handling
- ✓ Multiple key operations

### 3. Secret Storage Tests (test_secret_storage.sh)

Tests secret management across platforms:
- ✓ File backend storage and retrieval
- ✓ macOS keychain integration (macOS only)
- ✓ Linux secret-tool integration (Linux only)
- ✓ Multiple account support
- ✓ Secret existence checking
- ✓ Special characters in secrets
- ✓ File permissions (600 for files)
- ✓ Fallback mechanisms

## Test Framework

These tests use a lightweight bash testing framework without external dependencies:

### Helper Functions
- `assert_equals expected actual` - Assert string equality
- `assert_success exit_code` - Assert command succeeded
- `assert_failure exit_code` - Assert command failed
- `assert_file_exists path` - Assert file exists
- `run_test name function` - Run a test with reporting

### Test Output
```
Running: Valid ASCII token (10/10) ... ✓ PASS
Running: Bearer prefix stripped (10/10) ... ✓ PASS
Running: Whitespace fails validation ... ✓ PASS
...
==========================================
Test Results:
  Total:   17
  Passed:  17
  Failed:  0
==========================================
```

## Platform-Specific Behavior

### macOS
- Uses `plutil` for JSON manipulation
- Uses macOS keychain (`security` command) for secret storage
- Tests verify keychain integration when available

### Linux
- Uses Python 3 for JSON manipulation
- Uses `secret-tool` for secret storage (GNOME Keyring/KWallet)
- Falls back to file storage when keyring unavailable
- Tests verify both backends

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Unit Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: |
          cd tests
          ./run_all_tests.sh
```

## Adding New Tests

1. Create a new test file in `tests/unit/`
2. Include the test helper functions or source a common helper
3. Implement test functions following the naming convention `test_*()`
4. Use `run_test` to register and execute tests
5. Update `run_all_tests.sh` if needed

## Notes

- Tests are isolated and use temporary directories
- Cleanup is automatic via `trap` handlers
- Platform-specific tests are skipped gracefully on unsupported platforms
- No external dependencies required (uses only bash, sed, grep, python3)
