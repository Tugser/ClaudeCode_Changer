#!/usr/bin/env bats
# Integration tests for linux-provider-switch.sh
#
# Prerequisites: bats-core, python3
# Run: bats tests/integration/linux_provider_switch.bats

load helpers/setup

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "sanitize_token accepts valid ASCII token" {
  run bash -c 'source ./linux-provider-switch.sh && sanitize_token "sk-ant-validkey123"'

  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-validkey123" ]
}

@test "sanitize_token rejects token with whitespace" {
  run bash -c 'source ./linux-provider-switch.sh && sanitize_token "sk ant invalid"'

  [ "$status" -eq 1 ]
}

@test "GLM activation: stores key in file backend" {
  export CLAUDE_PROVIDER_SECRET_BACKEND="file"

  run bash -c "source ./linux-provider-switch.sh && CLAUDE_HOME='$TEST_CLAUDE_HOME' SECRETS_FILE='$TEST_SECRETS' store_secret 'glm-api-key' 'test-glm-key-12345'"

  [ "$status" -eq 0 ]
  [ -f "$TEST_SECRETS" ]
}

@test "Anthropic backup: creates backup file" {
  create_initial_settings

  run bash -c "source ./linux-provider-switch.sh && SETTINGS='$TEST_SETTINGS' BACKUP='$TEST_BACKUP' backup_anthropic"

  [ "$status" -eq 0 ]
  [ -f "$TEST_BACKUP" ]
  assert_valid_json "$TEST_BACKUP"
}

@test "Anthropic restore: restores from backup" {
  cat >"$TEST_BACKUP" <<'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "ANTHROPIC_AUTH_TOKEN": "sk-ant-restored456"
  }
}
EOF

  run bash -c "source ./linux-provider-switch.sh && SETTINGS='$TEST_SETTINGS' BACKUP='$TEST_BACKUP' restore_anthropic"

  [ "$status" -eq 0 ]
  [ -f "$TEST_SETTINGS" ]
}

@test "Language: English to Türkçe persistence" {
  run bash -c "source ./linux-provider-switch.sh && CONFIG='$TEST_CONFIG' save_language 'tr'"

  [ "$status" -eq 0 ]

  run bash -c "source ./linux-provider-switch.sh && CONFIG='$TEST_CONFIG' load_language"
  [ "$output" = "tr" ]
}

@test "Doctor: reports no conflicts when env vars unset" {
  unset ANTHROPIC_AUTH_TOKEN
  unset ANTHROPIC_BASE_URL

  run bash -c "source ./linux-provider-switch.sh && doctor"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "No env conflicts" || "$output" =~ "Env cakismasi yok" ]]
}
