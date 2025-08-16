#!/bin/bash

# Test suite for sidekick-dedupe-issues plugin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_PATH="$SCRIPT_DIR/../plugins/sidekick-run-dedupe-issues"

# Test colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected exit code: $expected, Got: $actual"
        ((TESTS_FAILED++))
    fi
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"
    
    if [[ "$output" == *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected output to contain: '$expected'"
        ((TESTS_FAILED++))
    fi
}

assert_not_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"
    
    if [[ "$output" != *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected output NOT to contain: '$expected'"
        ((TESTS_FAILED++))
    fi
}

echo "Testing sidekick-dedupe-issues plugin..."
echo "========================================"

# Test 1: Plugin file exists and is executable
if [[ -x "$PLUGIN_PATH" ]]; then
    echo -e "${GREEN}✓${NC} Plugin file exists and is executable"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Plugin file does not exist or is not executable"
    ((TESTS_FAILED++))
fi

# Test 2: Help flag shows usage
output=$($PLUGIN_PATH --help 2>&1)
exit_code=$?
assert_exit_code 0 $exit_code "Help flag returns success"
assert_contains "$output" "Usage:" "Help output contains usage"
assert_contains "$output" "dedupe-issues" "Help output contains command name"
assert_contains "$output" "--threshold" "Help output contains threshold option"
assert_contains "$output" "--dry-run" "Help output contains dry-run option"
assert_contains "$output" "--confirm" "Help output contains confirm option"

# Test 3: Default is dry-run mode
output=$($PLUGIN_PATH test-org test-repo 2>&1)
exit_code=$?
assert_contains "$output" "DRY RUN" "Default mode is dry-run"
assert_not_contains "$output" "Closing issue" "Dry-run doesn't close issues"

# Test 4: Threshold validation
output=$($PLUGIN_PATH --threshold 150 test-org test-repo 2>&1)
exit_code=$?
assert_exit_code 1 $exit_code "Invalid threshold returns error"
assert_contains "$output" "Invalid threshold" "Error message for invalid threshold"

output=$($PLUGIN_PATH --threshold -10 test-org test-repo 2>&1)
exit_code=$?
assert_exit_code 1 $exit_code "Negative threshold returns error"

# Test 5: Required arguments
output=$($PLUGIN_PATH 2>&1)
exit_code=$?
assert_exit_code 1 $exit_code "Missing arguments returns error"
assert_contains "$output" "Missing required" "Error message for missing args"

# Test 6: Environment variable support
export SIDEKICK_GITHUB_ORG=test-org
export SIDEKICK_GITHUB_REPO=test-repo
output=$($PLUGIN_PATH --help 2>&1)
assert_contains "$output" "SIDEKICK_GITHUB_ORG" "Help mentions env variables"
unset SIDEKICK_GITHUB_ORG
unset SIDEKICK_GITHUB_REPO

# Test 7: Verbose mode
output=$($PLUGIN_PATH -v test-org test-repo 2>&1)
assert_contains "$output" "Verbose mode enabled" "Verbose flag works"

# Test 8: Limit option
output=$($PLUGIN_PATH --limit 500 test-org test-repo 2>&1)
assert_contains "$output" "limit: 500" "Limit option is recognized"

echo ""
echo "========================================"
echo "Test Results:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi