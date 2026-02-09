#!/usr/bin/env bats
# Cross-platform integration tests
#
# Verifies behavior consistency between macOS and Linux versions
# Run: bats tests/integration/cross_platform.bats

load helpers/setup

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "Both platforms: sanitize_token behaves identically" {
  local test_token="sk-ant-test12345"

  # macOS version
  run bash -c "source ./macos-provider-switch.sh && sanitize_token '$test_token'"
  local macos_result="$output"
  local macos_status="$status"

  # Linux version
  run bash -c "source ./linux-provider-switch.sh && sanitize_token '$test_token'"
  local linux_result="$output"
  local linux_status="$status"

  [ "$macos_status" -eq "$linux_status" ]
  [ "$macos_result" = "$linux_result" ]
}

@test "Both platforms: GLM base URL is identical" {
  grep -q "https://api.z.ai/api/anthropic" ./macos-provider-switch.sh
  local macos_has_url=$?

  grep -q "https://api.z.ai/api/anthropic" ./linux-provider-switch.sh
  local linux_has_url=$?

  [ "$macos_has_url" -eq 0 ]
  [ "$linux_has_url" -eq 0 ]
}

@test "Both platforms: MiniMax base URL is identical" {
  grep -q "https://api.minimax.io/anthropic" ./macos-provider-switch.sh
  local macos_has_url=$?

  grep -q "https://api.minimax.io/anthropic" ./linux-provider-switch.sh
  local linux_has_url=$?

  [ "$macos_has_url" -eq 0 ]
  [ "$linux_has_url" -eq 0 ]
}

@test "Both platforms: English messages match" {
  # macOS
  run bash -c 'source ./macos-provider-switch.sh && LANG_CHOICE="en" && t SETTINGS_WRITTEN'
  local macos_msg="$output"

  # Linux
  run bash -c 'source ./linux-provider-switch.sh && LANG_CHOICE="en" && t SETTINGS_WRITTEN'
  local linux_msg="$output"

  [ "$macos_msg" = "$linux_msg" ]
  [[ "$macos_msg" =~ "settings.json written" ]]
}
