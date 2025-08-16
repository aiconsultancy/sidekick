#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}Running PR Comment Extractor Test Suite${NC}"
echo "========================================"

TESTS_PASSED=0
TESTS_FAILED=0

for test_file in tests/test_*.sh; do
    if [[ -f "$test_file" ]]; then
        echo -e "\n${BOLD}Running: $(basename $test_file)${NC}"
        if bash "$test_file"; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo -e "${RED}✗ Test failed: $(basename $test_file)${NC}"
        fi
    fi
done

echo -e "\n========================================"
echo -e "${BOLD}Test Results:${NC}"
echo -e "${GREEN}✓ Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}✗ Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
fi