#!/usr/bin/env bash
# Run all security tests with colored output

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Security Test Suite for Provider Switch Scripts        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if ! command -v bats >/dev/null 2>&1; then
  echo -e "${RED}✗ Bats is not installed${NC}"
  echo "Install from: https://github.com/bats-core/bats-core"
  echo "macOS: brew install bats-core"
  echo "Ubuntu: sudo apt install bats"
  exit 1
fi

if [[ ! -f "$REPO_ROOT/linux-provider-switch.sh" ]]; then
  echo -e "${RED}✗ Cannot find provider switch scripts${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Bats testing framework found${NC}"
echo -e "${GREEN}✓ Provider switch scripts found${NC}"
echo ""
echo -e "${YELLOW}Running security tests...${NC}"
echo ""

total_files=0
passed_files=0
failed_files=0

for test_file in "$SCRIPT_DIR"/*.bats; do
  if [[ -f "$test_file" ]]; then
    test_name=$(basename "$test_file")
    echo -e "${BLUE}Testing: $test_name${NC}"
    # Run once from repo root so relative source paths in bats files resolve.
    test_output=""
    if test_output=$(cd "$REPO_ROOT" && bats "$test_file" 2>&1); then
      echo -e "${GREEN}✓ $test_name passed${NC}"
      passed_files=$((passed_files + 1))
    else
      echo -e "${RED}✗ $test_name failed${NC}"
      printf "%s\n" "$test_output"
      failed_files=$((failed_files + 1))
    fi
    total_files=$((total_files + 1))
    echo ""
  fi
done

echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "Total test files: $total_files"
echo -e "${GREEN}Passed: $passed_files${NC}"
if [[ $failed_files -gt 0 ]]; then
  echo -e "${RED}Failed: $failed_files${NC}"
  exit 1
else
  echo -e "${GREEN}All security tests passed!${NC}"
fi
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
