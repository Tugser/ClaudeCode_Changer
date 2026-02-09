#!/usr/bin/env bash
# Run all unit tests
# Usage: ./run_all_tests.sh

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

echo "=========================================="
echo "Running All Unit Tests"
echo "=========================================="
echo ""

for test_file in "$TEST_DIR"/unit/*.sh; do
  if [ -f "$test_file" ]; then
    echo "Running: $(basename "$test_file")"
    echo "----------------------------------------"
    if bash "$test_file"; then
      echo "✓ PASSED"
    else
      echo "✗ FAILED"
      FAILED=$((FAILED + 1))
    fi
    echo ""
  fi
done

echo "=========================================="
if [ $FAILED -eq 0 ]; then
  echo "All tests passed!"
  echo "=========================================="
  exit 0
else
  echo "$FAILED test suite(s) failed"
  echo "=========================================="
  exit 1
fi
