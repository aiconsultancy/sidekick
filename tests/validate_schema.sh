#!/bin/bash

# JSON Schema Validator for sidekick-get-pr-comments
# Uses jq to check structure and Python for full schema validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/schema/pr-comments-output.schema.json"
PLUGIN="$SCRIPT_DIR/plugins/sidekick-get-pr-comments"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    if [[ -n "$2" ]]; then
        echo "  $2"
    fi
    ((TESTS_FAILED++))
}

info() {
    echo -e "${BLUE}→${NC} $1"
}

# Function to validate JSON structure with jq
validate_structure_jq() {
    local json="$1"
    local test_name="$2"
    
    # Check required top-level fields
    local has_pr_info=$(echo "$json" | jq 'has("pr_info")')
    local has_pr_comments=$(echo "$json" | jq 'has("pr_comments")')
    local has_metadata=$(echo "$json" | jq 'has("metadata")')
    local has_errors=$(echo "$json" | jq 'has("errors")')
    
    if [[ "$has_pr_info" == "true" ]] && \
       [[ "$has_pr_comments" == "true" ]] && \
       [[ "$has_metadata" == "true" ]] && \
       [[ "$has_errors" == "true" ]]; then
        pass "$test_name: Has all required top-level fields"
    else
        fail "$test_name: Missing required top-level fields"
        echo "  pr_info: $has_pr_info, pr_comments: $has_pr_comments"
        echo "  metadata: $has_metadata, errors: $has_errors"
        return 1
    fi
    
    # Check pr_info required fields
    local pr_info_valid=$(echo "$json" | jq '
        .pr_info | 
        has("organization") and 
        has("repository") and 
        has("pr_number") and 
        has("url") and 
        has("valid")
    ')
    
    if [[ "$pr_info_valid" == "true" ]]; then
        pass "$test_name: pr_info has required fields"
    else
        fail "$test_name: pr_info missing required fields"
        return 1
    fi
    
    # Check pr_comments is an array
    local is_array=$(echo "$json" | jq '.pr_comments | type == "array"')
    if [[ "$is_array" == "true" ]]; then
        pass "$test_name: pr_comments is an array"
    else
        fail "$test_name: pr_comments is not an array"
        return 1
    fi
    
    # Check metadata structure
    local metadata_valid=$(echo "$json" | jq '
        .metadata | 
        has("statistics") and 
        has("duplicate_groups") and 
        has("extraction_timestamp")
    ')
    
    if [[ "$metadata_valid" == "true" ]]; then
        pass "$test_name: metadata has required fields"
    else
        fail "$test_name: metadata missing required fields"
        return 1
    fi
    
    # Check statistics
    local stats_valid=$(echo "$json" | jq '
        .metadata.statistics | 
        has("total_comments")
    ')
    
    if [[ "$stats_valid" == "true" ]]; then
        pass "$test_name: statistics has required fields"
    else
        fail "$test_name: statistics missing total_comments"
        return 1
    fi
    
    # Check errors is an array
    local errors_array=$(echo "$json" | jq '.errors | type == "array"')
    if [[ "$errors_array" == "true" ]]; then
        pass "$test_name: errors is an array"
    else
        fail "$test_name: errors is not an array"
        return 1
    fi
    
    return 0
}

# Function to validate with Python jsonschema
validate_with_python() {
    local json="$1"
    local test_name="$2"
    
    if ! command -v python3 &> /dev/null; then
        info "Python3 not found, skipping full schema validation"
        return 0
    fi
    
    # Check if jsonschema is installed
    if ! python3 -c "import jsonschema" 2>/dev/null; then
        info "Python jsonschema not installed, trying basic validation"
        info "Install with: pip3 install jsonschema"
        return 0
    fi
    
    # Create Python validation script
    local result=$(python3 << EOF
import json
import sys
from jsonschema import validate, ValidationError, Draft7Validator

try:
    schema = json.loads('''$(cat "$SCHEMA_FILE")''')
    data = json.loads('''$json''')
    
    # Create validator
    validator = Draft7Validator(schema)
    
    # Collect all errors
    errors = list(validator.iter_errors(data))
    
    if errors:
        print("INVALID")
        for error in errors[:5]:  # Show first 5 errors
            print(f"- {error.message}")
            if error.path:
                print(f"  Path: {'.'.join(str(p) for p in error.path)}")
    else:
        print("VALID")
        
except json.JSONDecodeError as e:
    print(f"JSON_ERROR: {e}")
except Exception as e:
    print(f"ERROR: {e}")
EOF
    )
    
    if [[ "$result" == "VALID" ]]; then
        pass "$test_name: Full schema validation passed"
        return 0
    elif [[ "$result" == INVALID* ]]; then
        fail "$test_name: Schema validation failed"
        echo "$result" | tail -n +2 | while IFS= read -r line; do
            echo "  $line"
        done
        return 1
    else
        fail "$test_name: Validation error"
        echo "  $result"
        return 1
    fi
}

# Main validation
echo "========================================"
echo "JSON Schema Validation for PR Comments"
echo "========================================"
echo ""

# Test 1: Validate a successful extraction
info "Test 1: Validating successful PR extraction output"
echo ""

# Run the plugin with a test PR (using json-only mode)
TEST_OUTPUT=$(SIDEKICK_GITHUB_ORG=facebook SIDEKICK_GITHUB_REPO=react \
    "$PLUGIN" --json-only 1 2>/dev/null || echo '{"error": "Failed to fetch"}')

if echo "$TEST_OUTPUT" | jq empty 2>/dev/null; then
    pass "Output is valid JSON"
    
    # Validate structure with jq
    validate_structure_jq "$TEST_OUTPUT" "Structure check"
    
    # Validate with Python if available
    validate_with_python "$TEST_OUTPUT" "Schema validation"
else
    fail "Output is not valid JSON"
fi

echo ""

# Test 2: Validate error output
info "Test 2: Validating error output structure"
echo ""

# Test with invalid PR to get error output
ERROR_OUTPUT=$(SIDEKICK_GITHUB_ORG=nonexistent SIDEKICK_GITHUB_REPO=nonexistent \
    "$PLUGIN" --json-only 99999 2>/dev/null || true)

if [[ -n "$ERROR_OUTPUT" ]] && echo "$ERROR_OUTPUT" | jq empty 2>/dev/null; then
    pass "Error output is valid JSON"
    
    # Check it has required fields even in error state
    validate_structure_jq "$ERROR_OUTPUT" "Error structure"
else
    fail "Error output is not valid JSON"
fi

echo ""

# Test 3: Check schema file itself
info "Test 3: Validating schema file"
echo ""

if [[ -f "$SCHEMA_FILE" ]]; then
    pass "Schema file exists"
    
    if jq empty "$SCHEMA_FILE" 2>/dev/null; then
        pass "Schema file is valid JSON"
        
        # Check it's a valid JSON Schema
        local has_schema=$(jq 'has("$schema")' "$SCHEMA_FILE")
        local has_type=$(jq 'has("type")' "$SCHEMA_FILE")
        local has_properties=$(jq 'has("properties")' "$SCHEMA_FILE")
        
        if [[ "$has_schema" == "true" ]] && \
           [[ "$has_type" == "true" ]] && \
           [[ "$has_properties" == "true" ]]; then
            pass "Schema has valid JSON Schema structure"
        else
            fail "Schema missing JSON Schema fields"
        fi
    else
        fail "Schema file is not valid JSON"
    fi
else
    fail "Schema file not found at $SCHEMA_FILE"
fi

echo ""

# Test 4: Validate against mock data
info "Test 4: Validating against mock data"
echo ""

# Create mock data that should be valid
MOCK_DATA=$(cat << 'EOF'
{
  "pr_info": {
    "organization": "test-org",
    "repository": "test-repo",
    "pr_number": 123,
    "url": "https://github.com/test-org/test-repo/pull/123",
    "title": "Test PR",
    "description": "Test description",
    "state": "open",
    "author": "testuser",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z",
    "draft": false,
    "mergeable": true,
    "merged": false,
    "base_branch": "main",
    "head_branch": "feature",
    "head_sha": "abc123",
    "checks": {
      "total": 5,
      "passed": 3,
      "failed": 1,
      "pending": 1,
      "runs": []
    },
    "valid": true
  },
  "pr_comments": [
    {
      "comment_id": "1",
      "author": "reviewer",
      "body": "LGTM",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "url": "https://github.com/test-org/test-repo/pull/123#comment-1",
      "type": "issue_comment",
      "status": "pending"
    }
  ],
  "metadata": {
    "statistics": {
      "total_comments": 1,
      "issue_comments": 1,
      "review_comments": 0,
      "reviews": 0,
      "duplicate_count": 0
    },
    "duplicate_groups": {},
    "extraction_timestamp": "2024-01-01T00:00:00Z"
  },
  "errors": []
}
EOF
)

validate_structure_jq "$MOCK_DATA" "Mock data structure"
validate_with_python "$MOCK_DATA" "Mock data schema"

echo ""
echo "========================================"
echo "Validation Results:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "All validation tests passed!"
fi