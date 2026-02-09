#!/usr/bin/env bash
# Unit tests for settings.json manipulation functions
# Tests set_env_string(), remove_env_key(), get_env_value(), clear_provider_overrides()

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
TEST_DIR=$(mktemp -d)
TEST_SETTINGS="$TEST_DIR/settings.json"
TEST_BACKUP="$TEST_DIR/anthropic.backup.json"

cleanup() {
  rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# macOS implementation (using plutil)
if [[ "$(uname)" == "Darwin" ]]; then
  set_env_string() {
    /usr/bin/plutil -replace "env.$1" -string "$2" "$TEST_SETTINGS" >/dev/null 2>&1
  }

  remove_env_key() {
    /usr/bin/plutil -remove "env.$1" "$TEST_SETTINGS" >/dev/null 2>&1 || true
  }

  get_env_value() {
    local key="${1:-${KEY-}}"
    if [[ -z "$key" || ! -f "$TEST_SETTINGS" ]]; then
      return
    fi
    /usr/bin/plutil -extract "env.$key" raw -o - "$TEST_SETTINGS" 2>/dev/null || true
  }

  clear_provider_overrides() {
    if [[ ! -f "$TEST_SETTINGS" ]]; then
      return
    fi
    if ! /usr/bin/plutil -convert json -o /dev/null "$TEST_SETTINGS" >/dev/null 2>&1; then
      rm -f "$TEST_SETTINGS"
      return
    fi
    for key in \
      ANTHROPIC_BASE_URL \
      ANTHROPIC_AUTH_TOKEN \
      ANTHROPIC_AUTH_HEADER \
      API_TIMEOUT_MS \
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
      ANTHROPIC_MODEL \
      ANTHROPIC_SMALL_FAST_MODEL \
      ANTHROPIC_DEFAULT_SONNET_MODEL \
      ANTHROPIC_DEFAULT_OPUS_MODEL \
      ANTHROPIC_DEFAULT_HAIKU_MODEL; do
      remove_env_key "$key"
    done
  }

  ensure_settings_json() {
    if [[ ! -f "$TEST_SETTINGS" ]]; then
      printf "{\n  \"env\": {}\n}\n" >"$TEST_SETTINGS"
    fi
  }

  settings_can_merge() {
    command -v /usr/bin/plutil >/dev/null 2>&1 || return 1
    ensure_settings_json
    /usr/bin/plutil -convert json -o /dev/null "$TEST_SETTINGS" >/dev/null 2>&1
  }
else
  # Linux implementation (using Python)
  set_env_string() {
    python3 - "$TEST_SETTINGS" "$1" "$2" <<'PY'
import json
import os
import sys

path = sys.argv[1]
key = sys.argv[2]
value = sys.argv[3]

data = {}
if os.path.exists(path):
  with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

if not isinstance(data, dict):
  data = {}

env = data.get("env")
if not isinstance(env, dict):
  env = {}
data["env"] = env

env[key] = value

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
  json.dump(data, fh, ensure_ascii=False, indent=2)
  fh.write("\n")
os.replace(tmp, path)
PY
  }

  remove_env_key() {
    python3 - "$TEST_SETTINGS" "$1" <<'PY'
import json
import os
import sys

path = sys.argv[1]
key = sys.argv[2]

data = {}
if os.path.exists(path):
  with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

if not isinstance(data, dict):
  data = {}

env = data.get("env")
if not isinstance(env, dict):
  env = {}
data["env"] = env

env.pop(key, None)

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
  json.dump(data, fh, ensure_ascii=False, indent=2)
  fh.write("\n")
os.replace(tmp, path)
PY
  }

  get_env_value() {
    local key="${1:-${KEY-}}"
    if [[ -z "$key" || ! -f "$TEST_SETTINGS" ]]; then
      return
    fi
    python3 - "$TEST_SETTINGS" "$key" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]

try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(0)

if not isinstance(loaded, dict):
  sys.exit(0)

env = loaded.get("env")
if not isinstance(env, dict):
  sys.exit(0)

value = env.get(key, "")
if value is None:
  sys.exit(0)

print(str(value), end="")
PY
  }

  clear_provider_overrides() {
    if [[ ! -f "$TEST_SETTINGS" ]]; then
      return
    fi
    for key in \
      ANTHROPIC_BASE_URL \
      ANTHROPIC_AUTH_TOKEN \
      ANTHROPIC_AUTH_HEADER \
      API_TIMEOUT_MS \
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
      ANTHROPIC_MODEL \
      ANTHROPIC_SMALL_FAST_MODEL \
      ANTHROPIC_DEFAULT_SONNET_MODEL \
      ANTHROPIC_DEFAULT_OPUS_MODEL \
      ANTHROPIC_DEFAULT_HAIKU_MODEL; do
      remove_env_key "$key"
    done
  }

  ensure_settings_json() {
    if [[ ! -f "$TEST_SETTINGS" ]]; then
      printf "{\n  \"env\": {}\n}\n" >"$TEST_SETTINGS"
    fi
  }

  settings_can_merge() {
    ensure_settings_json
    python3 - "$TEST_SETTINGS" <<'PY'
import json
import sys

try:
  with open(sys.argv[1], "r", encoding="utf-8") as fh:
    json.load(fh)
  sys.exit(0)
except Exception:
  sys.exit(1)
PY
  }
fi

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

assert_file_exists() {
  if [ ! -f "$1" ]; then
    echo "    File does not exist: $1"
    return 1
  fi
  return 0
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! echo "$haystack" | grep -q "$needle"; then
    echo "    '$haystack' does not contain '$needle'"
    return 1
  fi
  return 0
}

run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Running: $test_name ... "

  # Reset test environment
  rm -f "$TEST_SETTINGS" "$TEST_BACKUP"
  ensure_settings_json

  if $test_func; then
    echo "✓ PASS"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ FAIL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test cases
test_set_env_string() {
  set_env_string "ANTHROPIC_BASE_URL" "https://api.example.com"
  local result
  result=$(get_env_value "ANTHROPIC_BASE_URL")

  assert_equals "https://api.example.com" "$result"
}

test_set_multiple_keys() {
  set_env_string "ANTHROPIC_AUTH_TOKEN" "sk-test123"
  set_env_string "ANTHROPIC_BASE_URL" "https://api.test.com"
  set_env_string "API_TIMEOUT_MS" "3000000"

  local token
  token=$(get_env_value "ANTHROPIC_AUTH_TOKEN")
  local url
  url=$(get_env_value "ANTHROPIC_BASE_URL")
  local timeout
  timeout=$(get_env_value "API_TIMEOUT_MS")

  assert_equals "sk-test123" "$token" && \
  assert_equals "https://api.test.com" "$url" && \
  assert_equals "3000000" "$timeout"
}

test_remove_env_key() {
  set_env_string "TEST_KEY" "test_value"
  remove_env_key "TEST_KEY"
  local result
  result=$(get_env_value "TEST_KEY")

  # Should return empty string
  assert_equals "" "$result"
}

test_remove_nonexistent_key() {
  # Should not fail when removing non-existent key
  remove_env_key "NONEXISTENT_KEY"
  return 0
}

test_get_env_value_from_nonexistent_file() {
  rm -f "$TEST_SETTINGS"
  local result
  result=$(get_env_value "ANY_KEY" 2>&1)

  assert_equals "" "$result"
}

test_clear_provider_overrides() {
  set_env_string "ANTHROPIC_BASE_URL" "https://api.test.com"
  set_env_string "ANTHROPIC_AUTH_TOKEN" "sk-test123"
  set_env_string "ANTHROPIC_MODEL" "test-model"
  set_env_string "API_TIMEOUT_MS" "3000000"

  clear_provider_overrides

  local base_url
  base_url=$(get_env_value "ANTHROPIC_BASE_URL")
  local token
  token=$(get_env_value "ANTHROPIC_AUTH_TOKEN")
  local model
  model=$(get_env_value "ANTHROPIC_MODEL")
  local timeout
  timeout=$(get_env_value "API_TIMEOUT_MS")

  assert_equals "" "$base_url" && \
  assert_equals "" "$token" && \
  assert_equals "" "$model" && \
  assert_equals "" "$timeout"
}

test_clear_preserves_other_keys() {
  set_env_string "ANTHROPIC_BASE_URL" "https://api.test.com"
  set_env_string "CUSTOM_KEY" "custom_value"

  clear_provider_overrides

  local base_url
  base_url=$(get_env_value "ANTHROPIC_BASE_URL")
  local custom
  custom=$(get_env_value "CUSTOM_KEY")

  assert_equals "" "$base_url" && \
  assert_equals "custom_value" "$custom"
}

test_update_existing_value() {
  set_env_string "TEST_KEY" "value1"
  set_env_string "TEST_KEY" "value2"
  local result
  result=$(get_env_value "TEST_KEY")

  assert_equals "value2" "$result"
}

test_special_characters_in_value() {
  set_env_string "SPECIAL_KEY" "value-with_+=@!符号"
  local result
  result=$(get_env_value "SPECIAL_KEY")

  assert_equals "value-with_+=@!符号" "$result"
}

test_empty_value() {
  set_env_string "EMPTY_KEY" ""
  local result
  result=$(get_env_value "EMPTY_KEY")

  assert_equals "" "$result"
}

test_settings_file_created() {
  rm -f "$TEST_SETTINGS"
  ensure_settings_json

  assert_file_exists "$TEST_SETTINGS"
}

test_json_validity() {
  set_env_string "KEY1" "value1"
  set_env_string "KEY2" "value2"

  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool "$TEST_SETTINGS" >/dev/null 2>&1; then
      return 0
    else
      echo "    JSON is invalid"
      return 1
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    if /usr/bin/plutil -lint "$TEST_SETTINGS" >/dev/null 2>&1; then
      return 0
    else
      echo "    JSON is invalid"
      return 1
    fi
  fi
}

# Run all tests
echo "=========================================="
echo "Unit Tests for settings.json Functions"
echo "=========================================="
echo ""

run_test "set_env_string() sets value" test_set_env_string
run_test "set_env_string() handles multiple keys" test_set_multiple_keys
run_test "remove_env_key() removes key" test_remove_env_key
run_test "remove_env_key() handles non-existent key" test_remove_nonexistent_key
run_test "get_env_value() returns empty for missing file" test_get_env_value_from_nonexistent_file
run_test "clear_provider_overrides() clears all keys" test_clear_provider_overrides
run_test "clear_provider_overrides() preserves other keys" test_clear_preserves_other_keys
run_test "Update existing value" test_update_existing_value
run_test "Special characters in value" test_special_characters_in_value
run_test "Empty value" test_empty_value
run_test "Settings file created" test_settings_file_created
run_test "JSON validity maintained" test_json_validity

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
