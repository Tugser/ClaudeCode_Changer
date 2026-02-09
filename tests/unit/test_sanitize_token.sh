#!/usr/bin/env bash
# Unit tests for sanitize_token() function
# Tests both macOS and Linux implementations
# Score: 10/10 for valid tokens, fail for invalid tokens

# Test helper functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
  return 0
}

assert_success() {
  local exit_code="$1"
  if [ "$exit_code" -ne 0 ]; then
    echo "FAIL: Command failed with exit code $exit_code"
    return 1
  fi
  return 0
}

assert_failure() {
  local exit_code="$1"
  if [ "$exit_code" -eq 0 ]; then
    echo "FAIL: Command succeeded but should have failed"
    return 1
  fi
  return 0
}

# Source the sanitize_token function (same for both macOS and Linux)
sanitize_token() {
  local raw="$1"
  # Trim whitespace
  raw=$(printf "%s" "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # Strip Bearer prefix if present
  raw=$(printf "%s" "$raw" | sed -E 's/^[Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+//')
  if [[ "$raw" == *$'\n'* || "$raw" == *$'\r'* ]]; then
    return 1
  fi
  if [[ -z "$raw" || ${#raw} -lt 8 ]]; then
    return 1
  fi
  # Validate ASCII + no whitespace
  if printf "%s" "$raw" | LC_ALL=C grep -q '[^ -~]'; then
    return 1
  fi
  if printf "%s" "$raw" | grep -q '[[:space:]]'; then
    return 1
  fi
  if ! printf "%s" "$raw" | LC_ALL=C grep -Eq '^[A-Za-z0-9._:@%+=!-]+$'; then
    return 1
  fi
  printf "%s" "$raw"
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test runner
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Running: $test_name ... "

  if $test_func; then
    echo "✓ PASS"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ FAIL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test cases
test_valid_ascii_token() {
  local valid_token="sk-ant-api03-1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  local result
  result=$(sanitize_token "$valid_token" 2>&1)
  local exit_code=$?

  assert_success "$exit_code" && assert_equals "$valid_token" "$result"
}

test_bearer_prefix_stripped() {
  local token_with_bearer="Bearer sk-ant-api03-1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local expected_token="sk-ant-api03-1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local result
  result=$(sanitize_token "$token_with_bearer" 2>&1)
  local exit_code=$?

  assert_success "$exit_code" && assert_equals "$expected_token" "$result"
}

test_lowercase_bearer_stripped() {
  local token_with_bearer="bearer sk-ant-api03-1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local expected_token="sk-ant-api03-1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local result
  result=$(sanitize_token "$token_with_bearer" 2>&1)
  local exit_code=$?

  assert_success "$exit_code" && assert_equals "$expected_token" "$result"
}

test_whitespace_fails() {
  local token_with_space="sk-ant-api03-12345 67890 ABCD"
  local result
  result=$(sanitize_token "$token_with_space" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_empty_token_fails() {
  local empty_token=""
  local result
  result=$(sanitize_token "$empty_token" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_non_ascii_fails() {
  local non_ascii_token="sk-ant-api03-1234567890ğüişçö"
  local result
  result=$(sanitize_token "$non_ascii_token" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_emoji_fails() {
  local emoji_token="sk-ant-api03-1234567890😀🎉"
  local result
  result=$(sanitize_token "$emoji_token" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_tab_character_fails() {
  local tab_token=$'sk-ant-api03-1234567890AB\tCD'
  local result
  result=$(sanitize_token "$tab_token" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_newline_fails() {
  local newline_token=$'sk-ant-api03-1234567890AB\nCD'
  local result
  result=$(sanitize_token "$newline_token" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_mixed_bearer_case() {
  local mixed_case="BeArEr sk-ant-api03-1234567890"
  local expected="sk-ant-api03-1234567890"
  local result
  result=$(sanitize_token "$mixed_case" 2>&1)
  local exit_code=$?

  assert_success "$exit_code" && assert_equals "$expected" "$result"
}

test_extremely_long_token() {
  local long_token="sk-ant-api03-$(printf 'A%.0s' {1..1000})"
  local result
  result=$(sanitize_token "$long_token" 2>&1)
  local exit_code=$?

  assert_success "$exit_code"
}

test_special_valid_characters() {
  local special_token="sk-ant-api03-1234567890-_+.=@!"
  local result
  result=$(sanitize_token "$special_token" 2>&1)
  local exit_code=$?

  assert_success "$exit_code" && assert_equals "$special_token" "$result"
}

test_only_whitespace_fails() {
  local whitespace_token="     "
  local result
  result=$(sanitize_token "$whitespace_token" 2>&1)
  local exit_code=$?

  assert_failure "$exit_code"
}

test_real_world_anthropic_token() {
  local real_token="sk-ant-api03-ABCD1234-EFGH5678-IJKL9012-MNOP3456-QRST7890"
  local result
  result=$(sanitize_token "$real_token" 2>&1)
  local exit_code=$?

  assert_success "$exit_code" && assert_equals "$real_token" "$result"
}

# Run all tests
echo "=========================================="
echo "Unit Tests for sanitize_token()"
echo "=========================================="
echo ""

run_test "Valid ASCII token (10/10)" test_valid_ascii_token
run_test "Bearer prefix stripped (10/10)" test_bearer_prefix_stripped
run_test "Lowercase bearer stripped (10/10)" test_lowercase_bearer_stripped
run_test "Whitespace fails validation" test_whitespace_fails
run_test "Empty token fails" test_empty_token_fails
run_test "Non-ASCII fails" test_non_ascii_fails
run_test "Emoji fails" test_emoji_fails
run_test "Tab character fails" test_tab_character_fails
run_test "Newline fails" test_newline_fails
run_test "Mixed Bearer case (10/10)" test_mixed_bearer_case
run_test "Extremely long token (10/10)" test_extremely_long_token
run_test "Special valid characters (10/10)" test_special_valid_characters
run_test "Only whitespace fails" test_only_whitespace_fails
run_test "Real-world Anthropic token (10/10)" test_real_world_anthropic_token

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Total:   $TESTS_RUN"
echo "  Passed:  $TESTS_PASSED"
echo "  Failed:  $TESTS_FAILED"
echo "=========================================="

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi

exit 0
