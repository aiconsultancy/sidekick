#!/bin/bash

source "$(dirname "$0")/../lib/output_formatter.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

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

assert_yaml_valid() {
    local yaml="$1"
    local test_name="$2"
    
    # Use python to validate YAML if available, otherwise basic check
    if command -v python3 >/dev/null 2>&1; then
        if echo "$yaml" | python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $test_name"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC} $test_name"
            echo "  Invalid YAML structure"
            ((TESTS_FAILED++))
        fi
    else
        # Basic YAML check
        if [[ "$yaml" =~ ^[a-zA-Z_] ]]; then
            echo -e "${GREEN}✓${NC} $test_name (basic check)"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC} $test_name"
            ((TESTS_FAILED++))
        fi
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

echo "Testing Output Formatter..."

# Test 1: Format single comment to JSON
sample_comment='{
    "id": 123456,
    "user": {"login": "reviewer1"},
    "body": "Please fix the typo on line 10",
    "created_at": "2024-01-01T10:00:00Z",
    "updated_at": "2024-01-01T10:00:00Z",
    "html_url": "https://github.com/org/repo/pull/1#issuecomment-123456"
}'

formatted=$(format_comment_json "$sample_comment")
assert_json_valid "$formatted" "Format single comment as JSON"
assert_contains "$formatted" '"comment_id"' "Include comment_id field"
assert_contains "$formatted" '"author"' "Include author field"
assert_contains "$formatted" '"body"' "Include body field"
assert_contains "$formatted" '"created_at"' "Include created_at field"
assert_contains "$formatted" '"url"' "Include URL field"

# Test 2: Format comment with metadata
formatted=$(format_comment_with_metadata "$sample_comment" "resolved" "group_1")
assert_json_valid "$formatted" "Format comment with metadata"
assert_contains "$formatted" '"status": "resolved"' "Include status metadata"
assert_contains "$formatted" '"duplicate_group": "group_1"' "Include duplicate group"

# Test 3: Format complete output structure
all_data='{
    "issue_comments": ['"$sample_comment"'],
    "review_comments": [],
    "reviews": []
}'

duplicate_groups='{"group_1": ["123456", "789012"]}'

output=$(format_complete_output "$all_data" "$duplicate_groups" "json")
assert_json_valid "$output" "Format complete JSON output"
assert_contains "$output" '"pr_comments"' "Include pr_comments section"
assert_contains "$output" '"metadata"' "Include metadata section"
assert_contains "$output" '"duplicate_groups"' "Include duplicate groups"
assert_contains "$output" '"total_comments"' "Include comment count"

# Test 4: Format as YAML
output=$(format_complete_output "$all_data" "$duplicate_groups" "yaml")
assert_yaml_valid "$output" "Format complete YAML output"
assert_contains "$output" "pr_comments:" "Include pr_comments in YAML"
assert_contains "$output" "metadata:" "Include metadata in YAML"

# Test 5: Add resolved/ignored tracking
comment_with_resolved='{
    "id": 999,
    "body": "[RESOLVED] Fixed in commit abc123",
    "user": {"login": "dev1"}
}'

formatted=$(format_comment_json "$comment_with_resolved")
resolved_status=$(detect_comment_status "$comment_with_resolved")
assert_contains "$resolved_status" "resolved" "Detect resolved status from comment"

comment_with_ignored='{
    "id": 888,
    "body": "[IGNORE] This is by design",
    "user": {"login": "dev2"}
}'

ignored_status=$(detect_comment_status "$comment_with_ignored")
assert_contains "$ignored_status" "ignored" "Detect ignored status from comment"

# Test 6: Format statistics
stats=$(generate_statistics "$all_data" "$duplicate_groups")
assert_json_valid "$stats" "Generate valid statistics JSON"
assert_contains "$stats" '"total_comments"' "Include total count in stats"
assert_contains "$stats" '"duplicate_count"' "Include duplicate count"

echo ""
echo "Output Formatter Tests: $TESTS_PASSED passed, $TESTS_FAILED failed"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi