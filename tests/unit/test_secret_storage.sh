#!/usr/bin/env bash
# Unit tests for secret storage functions
# Tests store_secret(), read_secret(), file backend fallback, keychain/secret-tool mocks

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
TEST_DIR=$(mktemp -d)
TEST_SECRETS_FILE="$TEST_DIR/provider-secrets.json"
TEST_SERVICE="claude-provider-shell-test"

cleanup() {
  rm -rf "$TEST_DIR"
  # Clean up any keychain entries (macOS)
  if command -v security >/dev/null 2>&1; then
    security delete-generic-password -a "test-account" -s "$TEST_SERVICE" >/dev/null 2>&1 || true
  fi
  # Clean up any secret-tool entries (Linux)
  if command -v secret-tool >/dev/null 2>&1; then
    secret-tool clear --all service="$TEST_SERVICE" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

# Mock implementations
store_file_secret() {
  local account="$1" value="$2"
  python3 - "$TEST_SECRETS_FILE" "$account" "$value" <<'PY'
import json
import os
import sys

path = sys.argv[1]
account = sys.argv[2]
value = sys.argv[3]
data = {}

if os.path.exists(path):
  try:
    with open(path, "r", encoding="utf-8") as fh:
      loaded = json.load(fh)
    if isinstance(loaded, dict):
      data = {str(k): str(v) for k, v in loaded.items()}
  except Exception:
    data = {}

data[account] = value
tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
  json.dump(data, fh, ensure_ascii=False, indent=2)
  fh.write("\n")
os.replace(tmp, path)
PY
  chmod 600 "$TEST_SECRETS_FILE"
}

read_file_secret() {
  local account="$1"
  python3 - "$TEST_SECRETS_FILE" "$account" <<'PY'
import json
import os
import sys

path = sys.argv[1]
account = sys.argv[2]
if not os.path.exists(path):
  sys.exit(0)

try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(0)

if isinstance(loaded, dict):
  value = loaded.get(account, "")
  if value:
    print(str(value), end="")
PY
}

file_secret_exists() {
  local account="$1"
  python3 - "$TEST_SECRETS_FILE" "$account" <<'PY'
import json
import os
import sys

path = sys.argv[1]
account = sys.argv[2]
if not os.path.exists(path):
  sys.exit(1)

try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(1)

if isinstance(loaded, dict) and loaded.get(account):
  sys.exit(0)
sys.exit(1)
PY
}

# macOS keychain wrapper
store_secret_macos() {
  local account="$1" value="$2"
  security add-generic-password -a "$account" -s "$TEST_SERVICE" -w "$value" -U >/dev/null 2>&1
}

read_secret_macos() {
  local account="$1"
  local raw
  raw=$(security find-generic-password -a "$account" -s "$TEST_SERVICE" -w 2>/dev/null || true)
  if [[ ${#raw} -gt 100 && "$raw" =~ ^[0-9a-fA-F]+$ ]]; then
    if command -v xxd >/dev/null 2>&1; then
      echo -n "$raw" | xxd -r -p
      return
    fi
  fi
  echo -n "$raw" | tr -d '[:space:]'
}

secret_exists_macos() {
  security find-generic-password -a "$1" -s "$TEST_SERVICE" >/dev/null 2>&1
}

# Linux secret-tool wrapper
store_secret_linux() {
  local account="$1" value="$2"
  printf "%s" "$value" | secret-tool store --label="Test Claude Provider ($account)" service "$TEST_SERVICE" account "$account" >/dev/null 2>&1
}

read_secret_linux() {
  local account="$1"
  local raw
  raw=$(secret-tool lookup service "$TEST_SERVICE" account "$account" 2>/dev/null || true)
  raw=$(printf "%s" "$raw" | tr -d '[:space:]')
  printf "%s" "$raw"
}

secret_exists_linux() {
  local raw
  raw=$(secret-tool lookup service "$TEST_SERVICE" account "$1" 2>/dev/null || true)
  [[ -n "$raw" ]]
}

# Detect platform
detect_platform() {
  if command -v security >/dev/null 2>&1 && [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  elif command -v secret-tool >/dev/null 2>&1; then
    echo "linux"
  else
    echo "file"
  fi
}

PLATFORM=$(detect_platform)

# Test helpers
assert_equals() {
  local expected="$1"
  local actual="$2"
  if [ "$expected" != "$actual" ]; then
    echo "    Expected: '$expected'"
    echo "    Actual:   '$actual'"
    return 1
  fi
  return 0
}

assert_success() {
  local exit_code="$1"
  if [ "$exit_code" -ne 0 ]; then
    echo "    Command failed with exit code $exit_code"
    return 1
  fi
  return 0
}

assert_file_exists() {
  if [ ! -f "$1" ]; then
    echo "    File does not exist: $1"
    return 1
  fi
  return 0
}

run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Running: $test_name ... "

  # Clean test environment
  rm -f "$TEST_SECRETS_FILE"

  if $test_func; then
    echo "✓ PASS"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ FAIL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test cases - File backend (always available)
test_file_store_and_read() {
  store_file_secret "test-account" "test-secret-value-123"
  local result
  result=$(read_file_secret "test-account")

  assert_equals "test-secret-value-123" "$result"
}

test_file_store_multiple_accounts() {
  store_file_secret "account1" "secret1"
  store_file_secret "account2" "secret2"
  store_file_secret "account3" "secret3"

  local result1
  result1=$(read_file_secret "account1")
  local result2
  result2=$(read_file_secret "account2")
  local result3
  result3=$(read_file_secret "account3")

  assert_equals "secret1" "$result1" && \
  assert_equals "secret2" "$result2" && \
  assert_equals "secret3" "$result3"
}

test_file_update_existing() {
  store_file_secret "account1" "secret1"
  store_file_secret "account1" "secret2-updated"
  local result
  result=$(read_file_secret "account1")

  assert_equals "secret2-updated" "$result"
}

test_file_read_nonexistent() {
  store_file_secret "account1" "secret1"
  local result
  result=$(read_file_secret "nonexistent-account")

  assert_equals "" "$result"
}

test_file_secret_exists() {
  store_file_secret "account1" "secret1"
  file_secret_exists "account1"
  local exists=$?
  file_secret_exists "nonexistent"
  local not_exists=$?

  [ $exists -eq 0 ] && [ $not_exists -ne 0 ]
}

test_file_special_characters() {
  store_file_secret "account1" "secret-with_+=@!特殊字符"
  local result
  result=$(read_file_secret "account1")

  assert_equals "secret-with_+=@!特殊字符" "$result"
}

test_file_permissions() {
  store_file_secret "account1" "secret1"
  local perms
  perms=$(stat -c "%a" "$TEST_SECRETS_FILE" 2>/dev/null || stat -f "%OLp" "$TEST_SECRETS_FILE" 2>/dev/null)

  # Should be 600 (rw-------)
  [[ "$perms" == "600" ]] || [[ "$perms" == "0600" ]]
}

test_file_json_validity() {
  store_file_secret "account1" "secret1"
  store_file_secret "account2" "secret2"

  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool "$TEST_SECRETS_FILE" >/dev/null 2>&1; then
      return 0
    else
      echo "    JSON is invalid"
      return 1
    fi
  fi
}

# macOS-specific tests
test_macos_store_and_read() {
  if [ "$PLATFORM" != "macos" ]; then
    return 0  # Skip test
  fi

  store_secret_macos "test-account" "macos-secret-123"
  local result
  result=$(read_secret_macos "test-account")

  assert_equals "macos-secret-123" "$result"
}

test_macos_bearer_token() {
  if [ "$PLATFORM" != "macos" ]; then
    return 0  # Skip test
  fi

  local token="sk-ant-api03-ABCD1234-EFGH5678-IJKL9012"
  store_secret_macos "bearer-token" "$token"
  local result
  result=$(read_secret_macos "bearer-token")

  assert_equals "$token" "$result"
}

test_macos_exists() {
  if [ "$PLATFORM" != "macos" ]; then
    return 0  # Skip test
  fi

  store_secret_macos "exists-test" "secret"
  secret_exists_macos "exists-test"
  local exists=$?
  secret_exists_macos "not-exists"
  local not_exists=$?

  [ $exists -eq 0 ] && [ $not_exists -ne 0 ]
}

# Linux-specific tests
test_linux_store_and_read() {
  if [ "$PLATFORM" != "linux" ]; then
    return 0  # Skip test
  fi

  store_secret_linux "test-account" "linux-secret-123"
  local result
  result=$(read_secret_linux "test-account")

  assert_equals "linux-secret-123" "$result"
}

test_linux_bearer_token() {
  if [ "$PLATFORM" != "linux" ]; then
    return 0  # Skip test
  fi

  local token="sk-ant-api03-ABCD1234-EFGH5678-IJKL9012"
  store_secret_linux "bearer-token" "$token"
  local result
  result=$(read_secret_linux "bearer-token")

  assert_equals "$token" "$result"
}

test_linux_exists() {
  if [ "$PLATFORM" != "linux" ]; then
    return 0  # Skip test
  fi

  store_secret_linux "exists-test" "secret"
  secret_exists_linux "exists-test"
  local exists=$?
  secret_exists_linux "not-exists"
  local not_exists=$?

  [ $exists -eq 0 ] && [ $not_exists -ne 0 ]
}

# Run all tests
echo "=========================================="
echo "Unit Tests for Secret Storage"
echo "Platform: $PLATFORM"
echo "=========================================="
echo ""

# File backend tests (run on all platforms)
run_test "File backend: store and read" test_file_store_and_read
run_test "File backend: multiple accounts" test_file_store_multiple_accounts
run_test "File backend: update existing" test_file_update_existing
run_test "File backend: read non-existent" test_file_read_nonexistent
run_test "File backend: secret exists check" test_file_secret_exists
run_test "File backend: special characters" test_file_special_characters
run_test "File backend: file permissions" test_file_permissions
run_test "File backend: JSON validity" test_file_json_validity

# Platform-specific tests
run_test "macOS: store and read" test_macos_store_and_read
run_test "macOS: bearer token" test_macos_bearer_token
run_test "macOS: exists check" test_macos_exists

run_test "Linux: store and read" test_linux_store_and_read
run_test "Linux: bearer token" test_linux_bearer_token
run_test "Linux: exists check" test_linux_exists

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
