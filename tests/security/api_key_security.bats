#!/usr/bin/env bats
# Security Tests: API Key Management
# Tests for API key storage, retrieval, and leakage prevention

load common.bash

setup() {
  setup_test_env
  export HOME="$TEST_HOME"
  export CLAUDE_HOME="$TEST_CLAUDE_HOME"
  export SETTINGS="$TEST_SETTINGS"
  export BACKUP="$TEST_BACKUP"
  export CONFIG="$TEST_CONFIG"
  export SECRETS_FILE="$TEST_SECRETS"
}

teardown() {
  teardown_test_env "$TEST_HOME"
}

@test "SEC-001: API keys should not leak to stdout/stderr" {
  local test_key="sk-ant-test12345678901234567890"
  source ./linux-provider-switch.sh
  run store_secret "test-account" "$test_key"
  refute_output --partial "$test_key"
}

@test "SEC-002: Secrets file should have restrictive permissions (600)" {
  source ./linux-provider-switch.sh
  run store_file_secret "test-account" "test-key-value"
  if [[ -f "$SECRETS_FILE" ]]; then
    run check_file_permissions "$SECRETS_FILE" "600"
    assert_success
  fi
}

@test "SEC-003: Settings file should not leak keys in logs" {
  source ./linux-provider-switch.sh
  cat > "$SETTINGS" <<JSON
{"env":{"ANTHROPIC_AUTH_TOKEN":"sk-ant-test12345678901234567890"}}
JSON
  run current_summary
  refute_output --partial "sk-ant-test12345678901234567890"
}

@test "SEC-004: Temp files should be cleaned up" {
  source ./linux-provider-switch.sh
  run store_file_secret "test-account" "test-key-value"
  run test -f "${SECRETS_FILE}.tmp"
  assert_failure "Temp file should be cleaned up"
}

@test "SEC-005: Backup files should have 600 permissions" {
  source ./linux-provider-switch.sh
  echo '{"env":{}}' > "$SETTINGS"
  chmod 600 "$SETTINGS"
  run backup_anthropic
  if [[ -f "$BACKUP" ]]; then
    run check_file_permissions "$BACKUP" "600"
    assert_success
  fi
}

@test "SEC-006: Keychain access should not leak in process list" {
  skip "Manual verification required"
  run bash -c "grep 'security.*-w' ./macos-provider-switch.sh"
  assert_success "Should use stdin for secrets"
}

@test "SEC-007: Environment variables should not contain secrets in output" {
  source ./linux-provider-switch.sh
  export ANTHROPIC_AUTH_TOKEN="sk-ant-test12345678901234567890"
  run doctor
  refute_output --partial "sk-ant-test12345678901234567890"
}

@test "SEC-008: Token sanitization should work correctly" {
  source ./linux-provider-switch.sh
  run sanitize_token "  sk-ant-test  "
  assert_output "sk-ant-test"
  run sanitize_token "Bearer sk-ant-test"
  assert_output "sk-ant-test"
}

@test "SEC-009: Concurrent secret operations should be safe" {
  source ./linux-provider-switch.sh
  for i in {1..10}; do
    store_file_secret "account-$i" "key-$i" &
  done
  wait
  for i in {1..10}; do
    run file_secret_exists "account-$i"
    assert_success
  done
}

@test "SEC-010: Invalid input should be rejected" {
  source ./linux-provider-switch.sh
  run sanitize_token ""
  assert_failure
  run sanitize_token "   "
  assert_failure
  run sanitize_token $'key-\xc3\xa9'
  assert_failure
}
