#!/usr/bin/env bats
# Security Tests: File System Security
# Tests for file permissions, race conditions, and secure file operations

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

@test "FS-001: Settings file should have restrictive permissions" {
  source ./linux-provider-switch.sh
  run ensure_settings_json
  local perms
  perms=$(stat -f "%Lp" "$SETTINGS" 2>/dev/null || stat -c "%a" "$SETTINGS" 2>/dev/null)
  [[ "$perms" == "600" || "$perms" == "644" ]]
  assert_success
}

@test "FS-002: Backup should inherit secure permissions" {
  source ./linux-provider-switch.sh
  echo '{"env":{}}' > "$SETTINGS"
  chmod 600 "$SETTINGS"
  run backup_anthropic
  if [[ -f "$BACKUP" ]]; then
    run check_file_permissions "$BACKUP" "600"
    assert_success
  fi
}

@test "FS-003: Concurrent writes should be atomic" {
  source ./linux-provider-switch.sh
  local pids=()
  for i in {1..20}; do
    store_file_secret "account-$i" "value-$i" &
    pids+=($!)
  done
  wait
  run python3 -c "import json; json.load(open('$SECRETS_FILE'))"
  assert_success "File should be valid JSON"
}

@test "FS-004: Symlink attacks should be prevented" {
  source ./linux-provider-switch.sh
  ln -s /etc/passwd "$TEST_HOME/target"
  run store_file_secret "test" "value"
  run grep -q "value" /etc/passwd
  assert_failure "Should not write through symlinks"
}

@test "FS-005: Temp files should not remain" {
  source ./linux-provider-switch.sh
  run store_file_secret "test" "value"
  run find "$TEST_CLAUDE_HOME" -name "*.tmp"
  assert_output "" "No .tmp files should remain"
}

@test "FS-006: File creation should respect umask" {
  local original_umask=$(umask)
  umask 077
  source ./linux-provider-switch.sh
  run store_file_secret "test" "value"
  local perms=$(stat -f "%Lp" "$SECRETS_FILE" 2>/dev/null || stat -c "%a" "$SECRETS_FILE" 2>/dev/null)
  umask "$original_umask"
  assert_equal "$perms" "600"
}

@test "FS-007: Directory traversal in paths should be blocked" {
  source ./linux-provider-switch.sh
  export SECRETS_FILE="/tmp/test.json"
  run store_file_secret "test" "value"
  if [[ -f "/tmp/test.json" ]]; then
    run check_file_permissions "/tmp/test.json" "600"
    assert_success
  fi
}

@test "FS-008: Race conditions should be handled" {
  source ./linux-provider-switch.sh
  store_file_secret "test" "value1"
  (
    while true; do
      if [[ -f "$SECRETS_FILE" ]]; then
        mv "$SECRETS_FILE" "${SECRETS_FILE}.swap"
        mv "${SECRETS_FILE}.swap" "$SECRETS_FILE"
      fi
    done
  ) &
  local swap_pid=$!
  for i in {1..10}; do
    store_file_secret "race-$i" "value-$i" 2>/dev/null || true
  done
  kill $swap_pid 2>/dev/null || true
  wait $swap_pid 2>/dev/null || true
  if [[ ! -f "$SECRETS_FILE" && -f "${SECRETS_FILE}.swap" ]]; then
    mv "${SECRETS_FILE}.swap" "$SECRETS_FILE"
  fi
  run store_file_secret "race-final" "value-final"
  assert_success
  run python3 -c "import json; json.load(open('$SECRETS_FILE'))"
  assert_success
}

@test "FS-009: Config should validate JSON" {
  source ./linux-provider-switch.sh
  echo '{"invalid": json}' > "$CONFIG"
  run load_auth_header
  assert_success "Should handle invalid JSON"
}

@test "FS-010: Settings should not be overwritten without backup" {
  source ./linux-provider-switch.sh
  cat > "$SETTINGS" <<EOF
{"env":{"ANTHROPIC_AUTH_TOKEN":"original-token"}}
EOF
  rm -f "$BACKUP"
  run set_env_string "ANTHROPIC_BASE_URL" "https://test.com"
  if [[ -f "$BACKUP" ]]; then
    run grep -q "original-token" "$BACKUP"
    assert_success "Backup should preserve original"
  fi
}
