#!/usr/bin/env bats
# Security Tests: Input Validation
# Tests for SQL injection, command injection, path traversal, and XSS prevention

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

@test "VAL-001: SQL injection patterns should be rejected" {
  source ./linux-provider-switch.sh
  run sanitize_token "'; DROP TABLE users; --"
  assert_failure "SQL injection with spaces should be rejected"
}

@test "VAL-002: Command injection patterns should be detected" {
  run check_no_command_injection "key; rm -rf /"
  assert_failure
  run check_no_command_injection "key && whoami"
  assert_failure
  run check_no_command_injection "key\$(id)"
  assert_failure
}

@test "VAL-003: Path traversal attacks should be blocked" {
  run check_path_traversal "../../../etc/passwd"
  assert_failure
  run check_path_traversal "..\\..\\..\\windows\\system32"
  assert_failure
}

@test "VAL-004: XSS payloads should be handled" {
  source ./linux-provider-switch.sh
  run sanitize_token "<script>alert('XSS')</script>"
  assert_failure "Special characters should be rejected"
}

@test "VAL-005: Null byte injection should be prevented" {
  source ./linux-provider-switch.sh
  run sanitize_token $'key\x00injection'
  assert_failure
}

@test "VAL-006: Unicode attacks should be handled" {
  source ./linux-provider-switch.sh
  run sanitize_token $'key\u200b'
  assert_failure "Non-ASCII should be rejected"
}

@test "VAL-007: Long input should be handled gracefully" {
  source ./linux-provider-switch.sh
  local long_token=$(python3 -c "print('a' * 1000)")
  run sanitize_token "$long_token"
  assert_success "Long tokens should be accepted if valid ASCII"
}

@test "VAL-008: Newline injection should be prevented" {
  source ./linux-provider-switch.sh
  run sanitize_token "key\nADMIN=true"
  assert_failure
}

@test "VAL-009: Format string attacks should be safe" {
  source ./linux-provider-switch.sh
  run sanitize_token "key%s%s%s"
  assert_success "Format strings are valid ASCII"
}

@test "VAL-010: Shell metacharacters should be rejected" {
  source ./linux-provider-switch.sh
  run sanitize_token "key;whoami"
  assert_failure
  run sanitize_token "key|cat /etc/passwd"
  assert_failure
}

@test "VAL-011: JSON injection should be prevented" {
  source ./linux-provider-switch.sh
  run save_minimax_config '"malicious":"true"' "en"
  run python3 -c "import json; json.load(open('$CONFIG'))"
  assert_success "JSON should be properly escaped"
}

@test "VAL-012: File path injection should be prevented" {
  source ./linux-provider-switch.sh
  export SETTINGS="../../../etc/passwd"
  run settings_can_merge
  assert_failure "Should not access path-traversed files"
}
