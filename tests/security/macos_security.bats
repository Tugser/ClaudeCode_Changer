#!/usr/bin/env bats
# Security Tests: macOS Keychain Integration
# Tests specific to macOS keychain security (macos-provider-switch.sh)

load common.bash

setup() {
  setup_test_env
  export HOME="$TEST_HOME"
  export CLAUDE_HOME="$TEST_CLAUDE_HOME"
  export SETTINGS="$TEST_SETTINGS"
  export BACKUP="$TEST_BACKUP"
  export CONFIG="$TEST_CONFIG"
}

teardown() {
  teardown_test_env "$TEST_HOME"
}

@test "MAC-001: Keychain should use stdin for secrets" {
  run bash -c "grep 'security add-generic-password' ./macos-provider-switch.sh | grep -- '-w'"
  assert_success "Should use -w flag for stdin"
}

@test "MAC-002: Keychain accessibility should be default" {
  run bash -c "grep 'security.*-A\|--access' ./macos-provider-switch.sh"
  assert_failure "Should not set custom accessibility"
}

@test "MAC-003: Password prompts should be silent" {
  run bash -c "grep 'read -rsp' ./macos-provider-switch.sh"
  assert_success "Should use -s flag for silent input"
}

@test "MAC-004: Keychain errors should be handled" {
  skip "Requires macOS keychain"
  source ./macos-provider-switch.sh
  run read_secret "nonexistent-account"
  assert_success "Should handle missing account"
}

@test "MAC-005: Plutil should validate JSON" {
  skip "Requires macOS"
  source ./macos-provider-switch.sh
  echo '{"invalid": json}' > "$SETTINGS"
  run settings_can_merge
  assert_failure "Should reject invalid JSON"
}

@test "MAC-006: Backup permissions on macOS" {
  skip "Requires macOS"
  source ./macos-provider-switch.sh
  echo '{"env":{}}' > "$SETTINGS"
  chmod 600 "$SETTINGS"
  run backup_anthropic
  if [[ -f "$BACKUP" ]]; then
    local perms=$(stat -f "%Lp" "$BACKUP")
    assert_equal "$perms" "600"
  fi
}

@test "MAC-007: xxx decode should be safe" {
  skip "Requires macOS"
  source ./macos-provider-switch.sh
  # Mock security to return hex
  security() { echo "74657374"; }
  export -f security
  run read_secret "test"
  assert_output "test"
}

@test "MAC-008: Keychain labels should not contain secrets" {
  run bash -c "grep 'security.*-s.*-a' ./macos-provider-switch.sh | grep -i 'sk-ant'"
  assert_failure "Labels should not contain API keys"
}

@test "MAC-009: Concurrent keychain access should be safe" {
  skip "Requires macOS"
  source ./macos-provider-switch.sh
  local pids=()
  for i in {1..10}; do
    read_secret "account-$i" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  assert_success
}

@test "MAC-010: Keychain search should be scoped" {
  run bash -c "grep 'SERVICE=\"claude-provider-shell\"' ./macos-provider-switch.sh && grep 'find-generic-password' ./macos-provider-switch.sh | grep -F -- '-s \"\$SERVICE\"'"
  assert_success "Should use specific service name"
}

@test "MAC-011: Plutil operations should be atomic" {
  skip "Requires macOS"
  source ./macos-provider-switch.sh
  echo '{"env":{"TEST":"value"}}' > "$SETTINGS"
  run set_env_string "NEW_KEY" "new_value"
  assert_success
  run get_env_value "TEST"
  assert_output "value"
}

@test "MAC-012: Keychain should not expose secrets in args" {
  run bash -c "grep 'security.*-w.*\$' ./macos-provider-switch.sh | grep -v '-w \"\$'"
  assert_failure "Should not pass secrets as arguments"
}
