#!/bin/bash

# Integration tests for sidekick-dedupe-issues plugin
# Tests the complete workflow with mock data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_PATH="$SCRIPT_DIR/../plugins/sidekick-run-dedupe-issues"
LIB_PATH="$SCRIPT_DIR/../plugins/lib/sidekick-run-dedupe-issues/issue_deduplicator.sh"

# Test colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Source the library functions
TEST_MODE=true
source "$LIB_PATH" 2>/dev/null || {
    echo -e "${RED}Failed to source library functions${NC}"
    exit 1
}

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

assert_json_array_length() {
    local json="$1"
    local expected_length="$2"
    local test_name="$3"
    
    local actual_length=$(echo "$json" | jq 'length')
    
    if [[ "$expected_length" == "$actual_length" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected length: $expected_length"
        echo "  Got length: $actual_length"
        ((TESTS_FAILED++))
    fi
}

echo "Running integration tests for dedupe-issues..."
echo "=========================================="
echo ""

# Test 1: Mock data preparation
echo "Test Suite 1: Duplicate Detection with Mock Data"
echo "-----------------------------------------"

# Create mock issue data
mock_issues='[
  {
    "number": 100,
    "title": "App crashes on startup",
    "createdAt": "2024-01-15T10:00:00Z",
    "author": {"login": "user1"},
    "url": "https://github.com/org/repo/issues/100"
  },
  {
    "number": 101,
    "title": "Application crashes at startup",
    "createdAt": "2024-01-14T10:00:00Z",
    "author": {"login": "user2"},
    "url": "https://github.com/org/repo/issues/101"
  },
  {
    "number": 102,
    "title": "Bug: Memory leak in parser",
    "createdAt": "2024-01-13T10:00:00Z",
    "author": {"login": "user3"},
    "url": "https://github.com/org/repo/issues/102"
  },
  {
    "number": 103,
    "title": "Memory leak found in parser module",
    "createdAt": "2024-01-12T10:00:00Z",
    "author": {"login": "user4"},
    "url": "https://github.com/org/repo/issues/103"
  },
  {
    "number": 104,
    "title": "Completely different issue",
    "createdAt": "2024-01-11T10:00:00Z",
    "author": {"login": "user5"},
    "url": "https://github.com/org/repo/issues/104"
  }
]'

# Test duplicate detection with lower threshold for these test cases
duplicate_groups=$(find_duplicate_groups "$mock_issues" 70)
group_count=$(echo "$duplicate_groups" | jq 'length')

echo "Found $group_count duplicate groups"
assert_equals "2" "$group_count" "Should find 2 duplicate groups"

# Test 2: Group processing
echo ""
echo "Test Suite 2: Group Processing"
echo "-----------------------------------------"

if [[ "$group_count" -gt 0 ]]; then
    # Process first group
    first_group=$(echo "$duplicate_groups" | jq '.[0]')
    processed=$(process_duplicate_group "$mock_issues" "$first_group")
    
    keeper=$(echo "$processed" | jq -r '.keeper')
    duplicates_count=$(echo "$processed" | jq '.duplicates | length')
    
    # The keeper should be the newest (100 is newer than 101)
    assert_equals "100" "$keeper" "Keeper should be issue #100 (newest)"
    assert_equals "1" "$duplicates_count" "Should have 1 duplicate"
    
    # Check that duplicate is correctly identified
    duplicate=$(echo "$processed" | jq -r '.duplicates[0]')
    assert_equals "101" "$duplicate" "Duplicate should be issue #101"
fi

# Test 3: Similarity scoring edge cases
echo ""
echo "Test Suite 3: Similarity Scoring Edge Cases"
echo "-----------------------------------------"

# Test exact match
score=$(similarity_score "Bug fix" "Bug fix")
assert_equals "100" "$score" "Exact match should be 100%"

# Test with special characters
score1=$(similarity_score "Bug: [URGENT] Fix memory leak!" "Bug URGENT Fix memory leak")
if [[ "$score1" -ge 90 ]]; then
    echo -e "${GREEN}✓${NC} Special characters handled correctly (score: $score1)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Special characters not handled correctly (score: $score1)"
    ((TESTS_FAILED++))
fi

# Test with stop words
score2=$(similarity_score "The app is not working" "App not working")
if [[ "$score2" -ge 85 ]]; then
    echo -e "${GREEN}✓${NC} Stop words handled correctly (score: $score2)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Stop words not handled correctly (score: $score2)"
    ((TESTS_FAILED++))
fi

# Test 4: Threshold sensitivity
echo ""
echo "Test Suite 4: Threshold Sensitivity"
echo "-----------------------------------------"

# Test with high threshold (95%)
strict_groups=$(find_duplicate_groups "$mock_issues" 95)
strict_count=$(echo "$strict_groups" | jq 'length')
echo "With 95% threshold: $strict_count groups"

# Test with low threshold (70%)
loose_groups=$(find_duplicate_groups "$mock_issues" 70)
loose_count=$(echo "$loose_groups" | jq 'length')
echo "With 70% threshold: $loose_count groups"

if [[ $loose_count -ge $strict_count ]]; then
    echo -e "${GREEN}✓${NC} Lower threshold finds same or more duplicates"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Threshold behavior incorrect"
    ((TESTS_FAILED++))
fi

# Test 5: Empty and edge cases
echo ""
echo "Test Suite 5: Edge Cases"
echo "-----------------------------------------"

# Test with empty issue list
empty_groups=$(find_duplicate_groups "[]" 85)
assert_json_array_length "$empty_groups" "0" "Empty list returns no groups"

# Test with single issue
single_issue='[{"number": 1, "title": "Single issue", "createdAt": "2024-01-01T10:00:00Z"}]'
single_groups=$(find_duplicate_groups "$single_issue" 85)
assert_json_array_length "$single_groups" "0" "Single issue returns no groups"

# Test with no duplicates
no_dup_issues='[
  {"number": 1, "title": "First unique issue", "createdAt": "2024-01-01T10:00:00Z"},
  {"number": 2, "title": "Second completely different", "createdAt": "2024-01-02T10:00:00Z"},
  {"number": 3, "title": "Third unrelated problem", "createdAt": "2024-01-03T10:00:00Z"}
]'
no_dup_groups=$(find_duplicate_groups "$no_dup_issues" 85)
assert_json_array_length "$no_dup_groups" "0" "No duplicates returns empty groups"

# Test 6: Large dataset performance
echo ""
echo "Test Suite 6: Performance with Large Dataset"
echo "-----------------------------------------"

# Generate large dataset
large_dataset="["
for i in {1..100}; do
    if [[ $i -gt 1 ]]; then
        large_dataset="$large_dataset,"
    fi
    # Create some intentional duplicates
    if [[ $((i % 10)) -eq 0 ]]; then
        title="Repeated issue about performance"
    else
        title="Unique issue number $i"
    fi
    large_dataset="$large_dataset{\"number\":$i,\"title\":\"$title\",\"createdAt\":\"2024-01-01T10:00:00Z\"}"
done
large_dataset="$large_dataset]"

# Measure time for large dataset
start_time=$(date +%s)
large_groups=$(find_duplicate_groups "$large_dataset" 85)
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Processed 100 issues in $duration seconds"
if [[ $duration -lt 10 ]]; then
    echo -e "${GREEN}✓${NC} Performance acceptable for 100 issues"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Performance might be slow for large datasets"
fi

# Summary
echo ""
echo "=========================================="
echo "Integration Test Results:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "All integration tests passed!"
    exit 0
fi