#!/bin/bash

source "$(dirname "$0")/../lib/duplicate_detector.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

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

assert_true() {
    local condition="$1"
    local test_name="$2"
    
    if [[ "$condition" == "true" ]] || [[ "$condition" == "1" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: true"
        echo "  Got: '$condition'"
        ((TESTS_FAILED++))
    fi
}

assert_false() {
    local condition="$1"
    local test_name="$2"
    
    if [[ "$condition" == "false" ]] || [[ "$condition" == "0" ]] || [[ -z "$condition" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: false"
        echo "  Got: '$condition'"
        ((TESTS_FAILED++))
    fi
}

echo "Testing Duplicate Detection..."

# Test 1: Exact duplicates
result=$(are_duplicates "This needs fixing" "This needs fixing")
assert_true "$result" "Detect exact duplicates"

# Test 2: Case insensitive duplicates
result=$(are_duplicates "LGTM" "lgtm")
assert_true "$result" "Detect case-insensitive duplicates"

# Test 3: Duplicates with extra whitespace
result=$(are_duplicates "  Looks good  " "Looks good")
assert_true "$result" "Detect duplicates with extra whitespace"

# Test 4: Common approval patterns
result=$(are_duplicates "LGTM" "Looks good to me")
assert_true "$result" "Detect LGTM variations as duplicates"

result=$(are_duplicates "👍" "LGTM")
assert_true "$result" "Detect emoji approvals as duplicates"

result=$(are_duplicates "Approved" "LGTM")
assert_true "$result" "Detect approval variations"

# Test 5: Non-duplicates
result=$(are_duplicates "This needs fixing" "This looks great")
assert_false "$result" "Different comments are not duplicates"

result=$(are_duplicates "Fix the typo on line 10" "Update the documentation")
assert_false "$result" "Distinct suggestions are not duplicates"

# Test 6: Similarity scoring
score=$(calculate_similarity "The code looks good" "The code looks great")
if (( $(echo "$score > 0.7" | bc -l) )); then
    echo -e "${GREEN}✓${NC} High similarity for similar comments"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Should have high similarity for similar comments"
    echo "  Score: $score"
    ((TESTS_FAILED++))
fi

score=$(calculate_similarity "Fix this bug" "Great documentation")
if (( $(echo "$score < 0.3" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Low similarity for different comments"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Should have low similarity for different comments"
    echo "  Score: $score"
    ((TESTS_FAILED++))
fi

# Test 7: Find duplicates in array
sample_comments='[
    {"id": 1, "body": "LGTM"},
    {"id": 2, "body": "Looks good to me"},
    {"id": 3, "body": "Fix the typo"},
    {"id": 4, "body": "lgtm"},
    {"id": 5, "body": "Please fix the typo"}
]'

duplicates=$(find_duplicate_groups "$sample_comments")
# Check if duplicates were found correctly
if [[ "$duplicates" == *'"1"'* ]] && [[ "$duplicates" == *'"2"'* ]] && [[ "$duplicates" == *'"4"'* ]]; then
    echo -e "${GREEN}✓${NC} Find duplicate groups correctly"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Failed to find duplicate groups"
    echo "  Result: $duplicates"
    ((TESTS_FAILED++))
fi

echo ""
echo "Duplicate Detection Tests: $TESTS_PASSED passed, $TESTS_FAILED failed"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi