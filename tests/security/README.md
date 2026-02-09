# 🔒 Security Tests for Provider Switch Scripts

Comprehensive security test suite to verify protection against common vulnerabilities.

## Prerequisites

Install Bats test framework:
```bash
brew install bats-core
```

## Test Structure

```
tests/security/
├── api_key_security.bats      # API key storage & leakage (10 tests)
├── input_validation.bats      # Injection prevention (12 tests)
├── file_system_security.bats  # File permissions & race conditions (10 tests)
├── curl_security.bats         # Network security (14 tests)
├── macos_security.bats        # macOS keychain (12 tests)
├── helper_functions.bats      # Utility functions (20 tests)
├── common.bash                # Shared helpers
├── run_all_tests.sh          # Test runner
└── README.md                 # This file
```

## Running Tests

### Run all security tests:
```bash
./run_all_tests.sh
```

### Run specific test file:
```bash
bats api_key_security.bats
bats input_validation.bats
bats file_system_security.bats
```

### Run with verbose output:
```bash
bats --verbose .
bats --print-output-on-failure .
```

### Run specific test by name:
```bash
bats --filter "SEC-001" .
bats --filter "SQL injection" .
```

## Test Categories

### 1. API Key Security (SEC-001 to SEC-010)
Tests secure storage and handling of API keys:
- File permissions (600)
- No leakage to stdout/stderr
- Atomic writes (race condition protection)
- Concurrent access safety

### 2. Input Validation (VAL-001 to VAL-012)
Tests protection against malicious input:
- SQL injection
- Command injection
- XSS payloads
- Path traversal
- Shell metacharacters

### 3. File System Security (FS-001 to FS-010)
Tests file system operations:
- Permission enforcement
- Symlink attack prevention
- Temporary file cleanup
- Race condition handling

### 4. Network Security (NET-001 to NET-014)
Tests network operations:
- HTTPS enforcement
- SSL certificate verification
- SSRF protection
- Timeout enforcement
- URL validation

### 5. macOS Keychain (MAC-001 to MAC-012)
Tests macOS-specific security:
- stdin-based secret passing
- Service-scoped access
- Silent password prompts
- Keychain permissions

### 6. Helper Functions (HELP-001 to HELP-020)
Tests utility function security:
- sanitize_token
- load_config_value
- get_env_value
- Settings manipulation

## Security Coverage

| Threat | Protection | Tests |
|--------|-------------|-------|
| OWASP A01: Broken Access Control | ✓ | SEC-001, SEC-008 |
| OWASP A03: Injection | ✓ | VAL-001 to VAL-012 |
| OWASP A04: Insecure Design | ✓ | FS-001 to FS-010 |
| OWASP A05: Security Misconfiguration | ✓ | SEC-004, SEC-009 |
| OWASP A07: ID & Auth Failures | ✓ | SEC-001 to SEC-010 |
| CWE-20: Input Validation | ✓ | VAL-001 to VAL-012 |
| CWE-261: Race Conditions | ✓ | FS-006, SEC-008 |
| CWE-311: Missing Encryption | ✓ | SEC-001, SEC-009 |
| CWE-327: Broken Crypto | ✓ | NET-001 to NET-014 |

## CI/CD Integration

```yaml
name: Security Tests

on: [push, pull_request]

jobs:
  security:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Bats
        run: brew install bats-core
      - name: Run security tests
        run: cd tests/security && ./run_all_tests.sh
```

## Contributing

When adding new security tests:
1. Follow naming convention: {CATEGORY}-{NUMBER}
2. Document the threat/vulnerability
3. Test both success and failure cases
4. Use fake credentials only

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [Bats Documentation](https://bats-core.readthedocs.io/)
