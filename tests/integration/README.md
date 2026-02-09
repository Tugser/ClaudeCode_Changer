# Provider Switch Integration Tests

Comprehensive integration tests for the macOS and Linux provider switch scripts.

## Prerequisites

### Install Bats Test Framework

**macOS:**
```bash
brew install bats-core
```

**Linux:**
```bash
# Clone Bats repository
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

**Verify installation:**
```bash
bats --version
# Should output: Bats x.x.x
```

### Required Dependencies

- `bash` (version 4+)
- `python3` (for Linux script tests)
- `jq` (optional, for JSON validation in manual testing)

## Test Structure

```
tests/integration/
├── helpers/
│   └── setup.bash           # Test helper functions
├── macos_provider_switch.bats  # macOS-specific tests
├── linux_provider_switch.bats  # Linux-specific tests
├── cross_platform.bats      # Cross-platform consistency tests
└── README.md               # This file
```

## Running Tests

### Run all tests:
```bash
make test
```

### Run unit tests:
```bash
make test-unit
```

### Run integration tests:
```bash
make test-integration
```

### Run specific test file:
```bash
make test-macos
make test-linux
make test-cross
```

### Run with verbose output on failure:
```bash
make test-verbose
```

### Run specific test pattern:
```bash
make test-filter FILTER=sanitize_token
```

## Test Coverage

### End-to-End Scenarios
- ✅ GLM provider activation (complete flow)
- ✅ MiniMax provider activation (complete flow)
- ✅ Anthropic backup & restore
- ✅ Provider switching between GLM ↔ MiniMax ↔ Anthropic

### Multi-Platform Tests
- ✅ macOS specific: Keychain integration
- ✅ Linux specific: secret-tool + file fallback
- ✅ Cross-platform: settings.json consistency

### Error Handling
- ✅ Invalid API key rejection
- ✅ Corrupted settings.json recovery
- ✅ Missing dependencies (python3, plutil)

### Language Switching
- ✅ English → Türkçe → English
- ✅ Persistent language selection

## CI/CD Integration

### GitHub Actions Example:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]

    steps:
      - uses: actions/checkout@v3

      - name: Install Bats
        run: |
          if [ "$RUNNER_OS" == "macOS" ]; then
            brew install bats-core
          else
            git clone https://github.com/bats-core/bats-core.git
            cd bats-core && ./install.sh /usr/local
          fi

      - name: Run unit tests
        run: make test-unit

      - name: Run integration tests
        run: make test-integration
```

## Mock Strategy

Tests use fake credentials and do NOT call real APIs:

```bash
FAKE_GLM_KEY="glm_fake_key_1234567890abcdefghij"
FAKE_MINIMAX_KEY="minimax_fake_key_0987654321zyxwvutsr"
FAKE_ANTHROPIC_KEY="sk-ant-fake1234567890abcdefghij"
```

## Troubleshooting

### Tests fail with "command not found: bats"
Install Bats using the instructions in the Prerequisites section.

### macOS tests fail with "plutil: command not found"
This is expected on non-macOS systems. The tests will skip plutil-dependent tests.

### Linux tests fail with "python3: command not found"
Install Python 3: `sudo apt-get install python3` (Ubuntu/Debian)

## Resources

- [Bats Documentation](https://bats-core.readthedocs.io/)
- [macOS Provider Switch Script](../../macos-provider-switch.sh)
- [Linux Provider Switch Script](../../linux-provider-switch.sh)
