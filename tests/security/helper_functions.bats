#!/usr/bin/env bats
# Security Tests: Helper Functions
# Tests for sanitize_token, load_config_value, etc.

load common.bash

setup() {
  setup_test_env
  export HOME="$TEST_HOME"
  export CLAUDE_HOME="$TEST_CLAUDE_HOME"
  export SETTINGS="$TEST_SETTINGS"
  export CONFIG="$TEST_CONFIG"
}

teardown() {
  teardown_test_env "$TEST_HOME"
}

@test "HELP-001: sanitize_token should reject empty strings" {
  source ./linux-provider-switch.sh
  run sanitize_token ""
  assert_failure
}

@test "HELP-002: sanitize_token should reject whitespace" {
  source ./linux-provider-switch.sh
  run sanitize_token "     "
  assert_failure
}

@test "HELP-003: sanitize_token should strip Bearer prefix" {
  source ./linux-provider-switch.sh
  run sanitize_token "Bearer sk-ant-test123"
  assert_output "sk-ant-test123"
}

@test "HELP-004: sanitize_token should reject internal whitespace" {
  source ./linux-provider-switch.sh
  run sanitize_token "sk ant test"
  assert_failure
}

@test "HELP-005: sanitize_token should reject non-ASCII" {
  source ./linux-provider-switch.sh
  run sanitize_token $'sk-\xc3\xa9'
  assert_failure
}

@test "HELP-006: sanitize_token should accept valid tokens" {
  source ./linux-provider-switch.sh
  run sanitize_token "sk-ant-api03-1234567890"
  assert_success
}

@test "HELP-007: load_config_value should handle missing file" {
  source ./linux-provider-switch.sh
  rm -f "$CONFIG"
  run load_config_value "any_key"
  assert_success
  assert_output ""
}

@test "HELP-008: load_config_value should handle invalid JSON" {
  source ./linux-provider-switch.sh
  echo '{"invalid": json}' > "$CONFIG"
  run load_config_value "test_key"
  assert_success
  assert_output ""
}

@test "HELP-009: load_config_value should escape special chars" {
  source ./linux-provider-switch.sh
  python3 <<EOF
import json
with open('$CONFIG', 'w') as f:
    json.dump({"test_key": 'value with "quotes"'}, f)
EOF
  run load_config_value "test_key"
  assert_output --partial "value with"
}

@test "HELP-010: get_env_value should handle missing settings" {
  source ./linux-provider-switch.sh
  rm -f "$SETTINGS"
  run get_env_value "ANY_KEY"
  assert_success
  assert_output ""
}

@test "HELP-011: get_env_value should handle missing keys" {
  source ./linux-provider-switch.sh
  echo '{"env":{"OTHER":"value"}}' > "$SETTINGS"
  run get_env_value "MISSING"
  assert_success
  assert_output ""
}

@test "HELP-012: get_env_value should parse booleans" {
  source ./linux-provider-switch.sh
  echo '{"env":{"BOOL_TRUE":true,"BOOL_FALSE":false}}' > "$SETTINGS"
  run get_env_value "BOOL_TRUE"
  assert_output "1"
  run get_env_value "BOOL_FALSE"
  assert_output "0"
}

@test "HELP-013: get_env_value should parse numbers" {
  source ./linux-provider-switch.sh
  echo '{"env":{"INT":42,"FLOAT":3.14}}' > "$SETTINGS"
  run get_env_value "INT"
  assert_output "42"
}

@test "HELP-014: settings_can_merge should validate JSON" {
  source ./linux-provider-switch.sh
  echo '{invalid json}' > "$SETTINGS"
  run settings_can_merge
  assert_failure
  echo '{"env":{}}' > "$SETTINGS"
  run settings_can_merge
  assert_success
}

@test "HELP-015: set_env_string should escape special chars" {
  source ./linux-provider-switch.sh
  echo '{"env":{}}' > "$SETTINGS"
  run set_env_string "TEST" 'value with "quotes"'
  assert_success
}

@test "HELP-016: remove_env_key should handle missing keys" {
  source ./linux-provider-switch.sh
  echo '{"env":{}}' > "$SETTINGS"
  run remove_env_key "MISSING"
  assert_success
}

@test "HELP-017: clear_provider_overrides should work" {
  source ./linux-provider-switch.sh
  echo '{"env":{"ANTHROPIC_BASE_URL":"test","ANTHROPIC_AUTH_TOKEN":"token"}}' > "$SETTINGS"
  run clear_provider_overrides
  run get_env_value "ANTHROPIC_BASE_URL"
  assert_output ""
}

@test "HELP-018: detect_secret_backend should respect env" {
  source ./linux-provider-switch.sh
  export CLAUDE_PROVIDER_SECRET_BACKEND="file"
  run detect_secret_backend
  assert_output "file"
}

@test "HELP-019: maybe_backup should only backup Anthropic" {
  source ./linux-provider-switch.sh
  echo '{"env":{"ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}' > "$SETTINGS"
  rm -f "$BACKUP"
  run maybe_backup_anthropic
  run test -f "$BACKUP"
  assert_success
  rm -f "$BACKUP"
  echo '{"env":{"ANTHROPIC_BASE_URL":"https://custom.com"}}' > "$SETTINGS"
  run maybe_backup_anthropic
  run test -f "$BACKUP"
  assert_failure
}

@test "HELP-020: save_minimax_config should create valid JSON" {
  source ./linux-provider-switch.sh
  run save_minimax_config "Authorization" "en"
  run python3 -c "import json; json.load(open('$CONFIG'))"
  assert_success
}
