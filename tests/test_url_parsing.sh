#!/bin/bash

source "$(dirname "$0")/../lib/url_parser.sh" 2>/dev/null || true

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

echo "Testing URL Parser..."

# Test 1: Parse GitHub PR URL
parse_pr_url "https://github.com/aiconsultancy/indra/pull/985"
assert_equals "aiconsultancy" "$PR_ORG" "Extract org from URL"
assert_equals "indra" "$PR_REPO" "Extract repo from URL"
assert_equals "985" "$PR_NUMBER" "Extract PR number from URL"

# Test 2: Parse GitHub PR URL with trailing slash
parse_pr_url "https://github.com/user/repo/pull/123/"
assert_equals "user" "$PR_ORG" "Extract org from URL with trailing slash"
assert_equals "repo" "$PR_REPO" "Extract repo from URL with trailing slash"
assert_equals "123" "$PR_NUMBER" "Extract PR number from URL with trailing slash"

# Test 3: Parse GitHub PR URL with additional path
parse_pr_url "https://github.com/org/project/pull/456/files"
assert_equals "org" "$PR_ORG" "Extract org from URL with files path"
assert_equals "project" "$PR_REPO" "Extract repo from URL with files path"
assert_equals "456" "$PR_NUMBER" "Extract PR number from URL with files path"

# Test 4: Invalid URL should return error
unset PR_ORG PR_REPO PR_NUMBER
parse_pr_url "https://github.com/invalid-url" 2>/dev/null
if [[ -z "$PR_ORG" && -z "$PR_REPO" && -z "$PR_NUMBER" ]]; then
    echo -e "${GREEN}✓${NC} Invalid URL returns empty values"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Invalid URL should return empty values"
    ((TESTS_FAILED++))
fi

# Test 5: Parse hyphenated repo names
parse_pr_url "https://github.com/my-org/my-cool-repo/pull/789"
assert_equals "my-org" "$PR_ORG" "Extract hyphenated org name"
assert_equals "my-cool-repo" "$PR_REPO" "Extract hyphenated repo name"
assert_equals "789" "$PR_NUMBER" "Extract PR number with hyphenated names"

echo ""
echo "URL Parser Tests: $TESTS_PASSED passed, $TESTS_FAILED failed"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi