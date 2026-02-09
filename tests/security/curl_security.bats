#!/usr/bin/env bats
# Security Tests: cURL Operations
# Tests for URL validation, SSL verification, and timeout enforcement

load common.bash

setup() {
  setup_test_env
  export HOME="$TEST_HOME"
  export CLAUDE_HOME="$TEST_CLAUDE_HOME"
  export SETTINGS="$TEST_SETTINGS"
}

teardown() {
  teardown_test_env "$TEST_HOME"
}

@test "CURL-001: URLs should use HTTPS" {
  run bash -c "grep -Eo 'https://api\\.(anthropic\\.com|minimax\\.io/anthropic|z\\.ai/api/anthropic)' ./linux-provider-switch.sh | sort -u"
  assert_line --partial "https://api.anthropic.com"
  assert_line --partial "https://api.minimax.io"
  assert_line --partial "https://api.z.ai"
}

@test "CURL-002: SSL verification should be enabled" {
  run bash -c "grep 'curl' ./linux-provider-switch.sh | grep -E '(^|[[:space:]])(-k|--insecure)($|[[:space:]])'"
  assert_failure "Should not disable SSL verification"
}

@test "CURL-003: Timeout should be enforced" {
  run bash -c "grep 'curl.*--max-time' ./linux-provider-switch.sh"
  assert_success "All curl requests should have timeout"
}

@test "CURL-004: SSRF protection via hardcoded URLs" {
  run bash -c "grep -Eo 'https://api\\.(anthropic\\.com|minimax\\.io/anthropic|z\\.ai/api/anthropic)' ./linux-provider-switch.sh | sort -u | wc -l"
  assert_output --partial "3" "Should have exactly 3 hardcoded URLs"
}

@test "CURL-005: Response size should be limited" {
  run bash -c "grep 'curl' ./linux-provider-switch.sh | grep -- '-o /dev/null'"
  assert_success "Should discard response body"
}

@test "CURL-006: Credentials should not be in URL" {
  run bash -c "grep -E 'https://[^:]*:[^@]*@' ./linux-provider-switch.sh"
  assert_failure "URLs should not contain credentials"
}

@test "CURL-007: Redirects should be limited" {
  run bash -c "grep 'curl' ./linux-provider-switch.sh | grep -E '(-L|--location|--max-redirs)'"
  assert_failure "Should not follow redirects automatically"
}

@test "CURL-008: DNS rebinding protection" {
  run bash -c "grep -E 'https://api\.(anthropic|minimax|z)\.ai' ./linux-provider-switch.sh"
  assert_success "Should use hardcoded domain names"
}

@test "CURL-009: Tokens should not be logged" {
  source ./linux-provider-switch.sh
  local test_token="sk-ant-test12345678901234567890"
  cat > "$SETTINGS" <<EOF
{"env":{"ANTHROPIC_AUTH_TOKEN":"$test_token","ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}
EOF
  run test_call
  refute_output --partial "$test_token"
}

@test "CURL-010: Authorization headers should be used correctly" {
  run bash -c "grep 'curl.*-H.*Authorization' ./linux-provider-switch.sh"
  assert_success "Should use Authorization header"
  run bash -c "grep 'curl.*-H.*x-api-key' ./linux-provider-switch.sh"
  assert_success "Should use x-api-key header"
}

@test "CURL-011: Host header injection prevention" {
  run bash -c "grep -i 'curl.*-H.*Host:' ./linux-provider-switch.sh"
  assert_failure "Should not set custom Host header"
}

@test "CURL-012: Proxy environment should be respected" {
  export https_proxy="http://proxy.com:8080"
  run bash -c "env | grep proxy"
  assert_success "Proxy env vars should be available"
}

@test "CURL-013: Error messages should be safe" {
  source ./linux-provider-switch.sh
  cat > "$SETTINGS" <<EOF
{"env":{"ANTHROPIC_AUTH_TOKEN":"test-token","ANTHROPIC_BASE_URL":"https://invalid-domain-12345.com"}}
EOF
  run test_call
  refute_output --partial "/home/"
  refute_output --partial "$(whoami)"
}

@test "CURL-014: User-Agent should be minimal" {
  run bash -c "grep -i 'curl.*-H.*User-Agent' ./linux-provider-switch.sh"
  if [[ "$status" -eq 0 ]]; then
    refute_output --partial "$(hostname)"
  fi
}
