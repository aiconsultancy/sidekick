#!/bin/bash

source "$(dirname "$0")/../lib/gh_api.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected non-empty value"
        ((TESTS_FAILED++))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: '$needle'"
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
        echo "  Invalid JSON structure"
        ((TESTS_FAILED++))
    fi
}

echo "Testing GitHub API Functions..."

# Test 1: Check if gh CLI is available
if command -v gh >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} gh CLI is installed"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} gh CLI is not installed - skipping API tests"
    echo "  Install with: brew install gh"
    exit 0
fi

# Test 2: Build API endpoint for PR comments
endpoint=$(build_pr_comments_endpoint "aiconsultancy" "indra" "985")
assert_contains "$endpoint" "repos/aiconsultancy/indra" "Build correct API endpoint"
assert_contains "$endpoint" "issues/985/comments" "Include PR number in endpoint"

# Test 3: Build API endpoint for review comments
endpoint=$(build_pr_review_comments_endpoint "aiconsultancy" "indra" "985")
assert_contains "$endpoint" "repos/aiconsultancy/indra" "Build review comments endpoint"
assert_contains "$endpoint" "pulls/985/comments" "Include PR number in review endpoint"

# Test 4: Build API endpoint for reviews
endpoint=$(build_pr_reviews_endpoint "aiconsultancy" "indra" "985")
assert_contains "$endpoint" "repos/aiconsultancy/indra" "Build reviews endpoint"
assert_contains "$endpoint" "pulls/985/reviews" "Include PR number in reviews endpoint"

# Test 5: Mock fetch function with sample data
mock_fetch_pr_comments() {
    echo '[
        {
            "id": 123456,
            "user": {"login": "user1"},
            "body": "This looks good!",
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-01T10:00:00Z"
        }
    ]'
}

result=$(mock_fetch_pr_comments)
assert_json_valid "$result" "Mock data returns valid JSON"
assert_contains "$result" '"id": 123456' "Mock data contains comment ID"
assert_contains "$result" '"login": "user1"' "Mock data contains author"

echo ""
echo "GitHub API Tests: $TESTS_PASSED passed, $TESTS_FAILED failed"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi