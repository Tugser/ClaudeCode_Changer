#!/usr/bin/env bash
# Common security test utilities and fixtures

# Security test helpers
assert_success() {
  local message="${1:-Expected command to succeed}"
  if [[ "$status" -ne 0 ]]; then
    echo "$message"
    echo "status=$status"
    echo "output=$output"
    return 1
  fi
  return 0
}

assert_failure() {
  local message="${1:-Expected command to fail}"
  if [[ "$status" -eq 0 ]]; then
    echo "$message"
    echo "status=$status"
    echo "output=$output"
    return 1
  fi
  return 0
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="${3:-Expected '$expected', got '$actual'}"
  if [[ "$actual" != "$expected" ]]; then
    echo "$message"
    return 1
  fi
  return 0
}

assert_output() {
  local mode="exact"
  local needle message

  if [[ "${1:-}" == "--partial" ]]; then
    mode="partial"
    shift
  fi

  needle="${1:-}"
  message="${2:-Expected output check to pass}"

  if [[ "$mode" == "partial" ]]; then
    if [[ "$output" != *"$needle"* ]]; then
      echo "$message"
      echo "output=$output"
      return 1
    fi
    return 0
  fi

  if [[ "$output" != "$needle" ]]; then
    echo "$message"
    echo "output=$output"
    return 1
  fi
  return 0
}

refute_output() {
  local mode="exact"
  local needle message

  if [[ "${1:-}" == "--partial" ]]; then
    mode="partial"
    shift
  fi

  needle="${1:-}"
  message="${2:-Expected output check to fail}"

  if [[ "$mode" == "partial" ]]; then
    if [[ "$output" == *"$needle"* ]]; then
      echo "$message"
      echo "output=$output"
      return 1
    fi
    return 0
  fi

  if [[ "$output" == "$needle" ]]; then
    echo "$message"
    echo "output=$output"
    return 1
  fi
  return 0
}

assert_line() {
  local mode="exact"
  local needle message
  local -a search_lines=()

  if [[ "${1:-}" == "--partial" ]]; then
    mode="partial"
    shift
  fi

  needle="${1:-}"
  message="${2:-Expected matching line not found}"

  if [[ "${#lines[@]}" -gt 0 ]]; then
    search_lines=("${lines[@]}")
  else
    mapfile -t search_lines <<<"$output"
  fi

  local line
  for line in "${search_lines[@]}"; do
    if [[ "$mode" == "partial" && "$line" == *"$needle"* ]]; then
      return 0
    fi
    if [[ "$mode" == "exact" && "$line" == "$needle" ]]; then
      return 0
    fi
  done

  echo "$message"
  echo "output=$output"
  return 1
}

check_no_secret_leak() {
  local output="$1"
  local secret_patterns="sk-ant-[a-zA-Z0-9_-]{20,}"

  if grep -qE "$secret_patterns" <<< "$output"; then
    echo "SECRET_LEAK_DETECTED: Potential API key found in output"
    return 1
  fi
  return 0
}

check_file_permissions() {
  local file="$1"
  local expected_perms="${2:-600}"

  if [[ ! -f "$file" ]]; then
    echo "FILE_NOT_FOUND: $file"
    return 1
  fi

  local actual_perms
  actual_perms=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)

  if [[ "$actual_perms" != "$expected_perms" ]]; then
    echo "PERMISSION_MISMATCH: $file has $actual_perms, expected $expected_perms"
    return 1
  fi
  return 0
}

check_no_command_injection() {
  local input="$1"
  local injection_patterns=';|&&|\|\||`\$\(|\$\(.*\)|eval|exec|system'

  if grep -qE "$injection_patterns" <<< "$input"; then
    echo "COMMAND_INJECTION_DETECTED: $input"
    return 1
  fi
  return 0
}

check_path_traversal() {
  local input="$1"
  local traversal_patterns='\.\./|\.\.\\'

  if grep -qE "$traversal_patterns" <<< "$input"; then
    echo "PATH_TRAVERSAL_DETECTED: $input"
    return 1
  fi
  return 0
}

# Fixture management
setup_test_env() {
  export TEST_HOME="/tmp/claude-test-$$"
  export TEST_CLAUDE_HOME="$TEST_HOME/.claude"
  export TEST_SETTINGS="$TEST_CLAUDE_HOME/settings.json"
  export TEST_BACKUP="$TEST_CLAUDE_HOME/anthropic.backup.json"
  export TEST_CONFIG="$TEST_CLAUDE_HOME/provider-config.json"
  export TEST_SECRETS="$TEST_CLAUDE_HOME/provider-secrets.json"

  rm -rf "$TEST_HOME"
  mkdir -p "$TEST_CLAUDE_HOME"

  # Create test settings.json
  cat > "$TEST_SETTINGS" <<'EOF'
{
  "env": {}
}
EOF

  return 0
}

teardown_test_env() {
  local test_home="$1"
  rm -rf "$test_home"
}
