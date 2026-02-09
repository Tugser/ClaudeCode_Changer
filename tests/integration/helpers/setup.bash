#!/usr/bin/env bash
# Test helper functions for provider switch integration tests

# Set up test environment
setup_test_env() {
  export TEST_CLAUDE_HOME="${BATS_TEST_TMPDIR}/.claude"
  export TEST_SETTINGS="${TEST_CLAUDE_HOME}/settings.json"
  export TEST_BACKUP="${TEST_CLAUDE_HOME}/anthropic.backup.json"
  export TEST_CONFIG="${TEST_CLAUDE_HOME}/provider-config.json"
  export TEST_SECRETS="${TEST_CLAUDE_HOME}/provider-secrets.json"

  # Clean up any existing test data
  rm -rf "$TEST_CLAUDE_HOME"
  mkdir -p "$TEST_CLAUDE_HOME"

  # Create fake credentials
  export FAKE_GLM_KEY="glm_fake_key_1234567890abcdefghij"
  export FAKE_MINIMAX_KEY="minimax_fake_key_0987654321zyxwvutsr"
  export FAKE_ANTHROPIC_KEY="sk-ant-fake1234567890abcdefghij"

  # For macOS keychain mocking
  export TEST_SERVICE="claude-provider-shell-test"
}

# Clean up test environment
teardown_test_env() {
  rm -rf "$TEST_CLAUDE_HOME"
}

# Create initial settings.json
create_initial_settings() {
  cat >"$TEST_SETTINGS" <<'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "ANTHROPIC_AUTH_TOKEN": "sk-ant-original123"
  }
}
EOF
}

# Assert file exists with valid JSON
assert_valid_json() {
  local file="$1"
  [ -f "$file" ]
  python3 -c "import json; json.load(open('$file'))" || return 1
}

# Assert settings.json contains specific key-value
assert_setting() {
  local key="$1"
  local expected="$2"
  local actual
  actual=$(python3 -c "import json; d=json.load(open('$TEST_SETTINGS')); print(d['env'].get('$key', ''))")
  [ "$actual" = "$expected" ]
}

# Assert settings.json does not contain key
assert_no_setting() {
  local key="$1"
  python3 -c "import json; d=json.load(open('$TEST_SETTINGS')); assert '$key' not in d.get('env', {})" 2>/dev/null
}

# Export functions
export -f setup_test_env teardown_test_env create_initial_settings
export -f assert_valid_json assert_setting assert_no_setting
