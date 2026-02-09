#!/usr/bin/env bash
# Quick integration test without Bats

echo "=========================================="
echo "Quick Integration Tests"
echo "=========================================="
echo ""

# Test 1: sanitize_token
echo "Test 1: sanitize_token"
source ./macos-provider-switch.sh
if sanitize_token "sk-ant-test123" >/dev/null 2>&1; then
  echo "✓ Valid ASCII token accepted"
else
  echo "✗ Valid ASCII token rejected"
fi

# Test 2: settings.json
echo ""
echo "Test 2: settings.json manipulation"
TEST_SETTINGS="/tmp/test-settings-$$.json"
cat >"$TEST_SETTINGS" << 'JSONEOF'
{"env": {}}
JSONEOF

source ./macos-provider-switch.sh
if SETTINGS="$TEST_SETTINGS" set_env_string "TEST_KEY" "test_value"; then
  echo "✓ Settings write successful"
else
  echo "✗ Settings write failed"
fi

# Test 3: Secret storage
echo ""
echo "Test 3: Secret storage"
TEST_SECRETS="/tmp/test-secrets-$$.json"
source ./linux-provider-switch.sh
if CLAUDE_PROVIDER_SECRET_BACKEND="file" SECRETS_FILE="$TEST_SECRETS" store_secret "test-account" "test-value"; then
  echo "✓ Secret storage works"
else
  echo "✗ Secret storage failed"
fi

# Cleanup
rm -f "$TEST_SETTINGS" "$TEST_SECRETS"

echo ""
echo "=========================================="
echo "Quick tests completed!"
echo "=========================================="
