#!/bin/bash

# Test suite for issue fetcher functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_PATH="$SCRIPT_DIR/../plugins/sidekick-dedupe-issues"

# Source the plugin functions (we'll need to refactor to make this testable)
TEST_MODE=true
source "$SCRIPT_DIR/../plugins/lib/sidekick-run-dedupe-issues/issue_deduplicator.sh" 2>/dev/null || true

# Test colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: '$expected'"
        echo "  Got: '$actual'"
        ((TESTS_FAILED++))
    fi
}

assert_json_valid() {
    local json="$1"
    local test_name="$2"
    
    if echo "$json" | jq empty 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Invalid JSON"
        ((TESTS_FAILED++))
    fi
}

echo "Testing issue fetcher functionality..."
echo "========================================"

# Test 1: fetch_all_issues function exists
if declare -f fetch_all_issues >/dev/null; then
    echo -e "${GREEN}✓${NC} fetch_all_issues function exists"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} fetch_all_issues function does not exist"
    ((TESTS_FAILED++))
fi

# Test 2: normalize_title function
if declare -f normalize_title >/dev/null; then
    result=$(normalize_title "Bug: Application Crashes on Startup!")
    expected="bug application crashes on startup"
    assert_equals "$expected" "$result" "normalize_title removes special chars and lowercases"
    
    result=$(normalize_title "The app is not working")
    expected="the app is not working"
    assert_equals "$expected" "$result" "normalize_title preserves words (simplified)"
else
    echo -e "${RED}✗${NC} normalize_title function does not exist"
    ((TESTS_FAILED++))
fi

# Test 3: calculate_levenshtein function
if declare -f calculate_levenshtein >/dev/null; then
    result=$(calculate_levenshtein "test" "test")
    assert_equals "100" "$result" "Identical strings have 100% similarity"
    
    result=$(calculate_levenshtein "test" "tent")
    # Should be around 75% (3/4 chars match)
    if [[ "$result" -ge 70 ]] && [[ "$result" -le 80 ]]; then
        echo -e "${GREEN}✓${NC} Similar strings have appropriate similarity"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Similar strings similarity incorrect: $result"
        ((TESTS_FAILED++))
    fi
    
    result=$(calculate_levenshtein "abc" "xyz")
    assert_equals "0" "$result" "Completely different strings have 0% similarity"
else
    echo -e "${RED}✗${NC} calculate_levenshtein function does not exist"
    ((TESTS_FAILED++))
fi

# Test 4: calculate_token_overlap function
if declare -f calculate_token_overlap >/dev/null; then
    result=$(calculate_token_overlap "app crashes startup" "startup app crashes")
    assert_equals "100" "$result" "Same tokens in different order = 100%"
    
    result=$(calculate_token_overlap "app crashes" "app fails")
    assert_equals "33" "$result" "One common token out of three = 33%"
    
    result=$(calculate_token_overlap "abc def" "xyz qrs")
    assert_equals "0" "$result" "No common tokens = 0%"
else
    echo -e "${RED}✗${NC} calculate_token_overlap function does not exist"
    ((TESTS_FAILED++))
fi

# Test 5: similarity_score function
if declare -f similarity_score >/dev/null; then
    result=$(similarity_score "Bug: App crashes" "Bug: App crashes")
    assert_equals "100" "$result" "Identical titles = 100%"
    
    result=$(similarity_score "App crashes on startup" "Application crashes at startup")
    # Should be high similarity (> 70%)
    if [[ "$result" -ge 70 ]]; then
        echo -e "${GREEN}✓${NC} Similar titles have high similarity score"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Similar titles score too low: $result"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗${NC} similarity_score function does not exist"
    ((TESTS_FAILED++))
fi

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