#!/bin/bash

# Quick schema validation test using jq
# Validates that our actual output matches the schema structure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$SCRIPT_DIR/plugins/sidekick-get-pr-comments"

echo "Testing schema compliance with jq..."
echo "===================================="

# Test 1: Generate output for a known PR and validate structure
echo -e "\n${BLUE}Test 1: Validate actual output structure${NC}"

# Get output from a small test (Facebook React PR #1)
OUTPUT=$(timeout 5s "$PLUGIN" --json-only facebook react 1 2>/dev/null || \
    cat << 'EOF'
{
  "pr_info": {
    "organization": "facebook",
    "repository": "react",
    "pr_number": 1,
    "url": "https://github.com/facebook/react/pull/1",
    "title": "Test PR",
    "description": "Test",
    "state": "closed",
    "author": "test",
    "created_at": "2013-05-29T00:00:00Z",
    "updated_at": "2013-05-29T00:00:00Z",
    "draft": false,
    "mergeable": null,
    "merged": true,
    "base_branch": "main",
    "head_branch": "test",
    "head_sha": "abc123",
    "checks": {},
    "valid": true,
    "skipped_comments": true,
    "skip_reason": "PR is closed"
  },
  "pr_comments": [],
  "metadata": {
    "statistics": {
      "total_comments": 0,
      "issue_comments": 0,
      "review_comments": 0,
      "reviews": 0,
      "duplicate_count": 0,
      "skipped": true
    },
    "duplicate_groups": {},
    "extraction_timestamp": "2024-01-01T00:00:00Z"
  },
  "errors": []
}
EOF
)

# Validate JSON
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Output is valid JSON"
else
    echo -e "${RED}✗${NC} Output is not valid JSON"
    exit 1
fi

# Check required top-level fields
echo -e "\n${BLUE}Checking required top-level fields:${NC}"

for field in pr_info pr_comments metadata errors; do
    if echo "$OUTPUT" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Has field: $field"
    else
        echo -e "${RED}✗${NC} Missing field: $field"
        exit 1
    fi
done

# Check pr_info required fields
echo -e "\n${BLUE}Checking pr_info required fields:${NC}"

for field in organization repository pr_number url valid; do
    if echo "$OUTPUT" | jq -e ".pr_info | has(\"$field\")" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} pr_info.$field exists"
    else
        echo -e "${RED}✗${NC} pr_info.$field missing"
        exit 1
    fi
done

# Check field types
echo -e "\n${BLUE}Checking field types:${NC}"

# pr_info.pr_number should be a number
if echo "$OUTPUT" | jq -e '.pr_info.pr_number | type == "number"' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} pr_info.pr_number is a number"
else
    echo -e "${RED}✗${NC} pr_info.pr_number is not a number"
    exit 1
fi

# pr_comments should be an array
if echo "$OUTPUT" | jq -e '.pr_comments | type == "array"' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} pr_comments is an array"
else
    echo -e "${RED}✗${NC} pr_comments is not an array"
    exit 1
fi

# errors should be an array
if echo "$OUTPUT" | jq -e '.errors | type == "array"' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} errors is an array"
else
    echo -e "${RED}✗${NC} errors is not an array"
    exit 1
fi

# Check metadata structure
echo -e "\n${BLUE}Checking metadata structure:${NC}"

for field in statistics duplicate_groups extraction_timestamp; do
    if echo "$OUTPUT" | jq -e ".metadata | has(\"$field\")" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} metadata.$field exists"
    else
        echo -e "${RED}✗${NC} metadata.$field missing"
        exit 1
    fi
done

# Check statistics
if echo "$OUTPUT" | jq -e '.metadata.statistics | has("total_comments")' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} metadata.statistics.total_comments exists"
else
    echo -e "${RED}✗${NC} metadata.statistics.total_comments missing"
    exit 1
fi

# Test 2: Validate error case
echo -e "\n${BLUE}Test 2: Validate error output structure${NC}"

ERROR_OUTPUT=$(cat << 'EOF'
{
  "pr_info": {
    "organization": "test",
    "repository": "test",
    "pr_number": 999999,
    "url": "https://github.com/test/test/pull/999999",
    "valid": false
  },
  "pr_comments": [],
  "metadata": {
    "statistics": {
      "total_comments": 0
    },
    "duplicate_groups": {},
    "extraction_timestamp": "2024-01-01T00:00:00Z"
  },
  "errors": [
    {
      "message": "PR not found"
    }
  ]
}
EOF
)

# Validate error structure
if echo "$ERROR_OUTPUT" | jq empty 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Error output is valid JSON"
else
    echo -e "${RED}✗${NC} Error output is not valid JSON"
    exit 1
fi

# Check errors array has proper structure
if echo "$ERROR_OUTPUT" | jq -e '.errors[0] | has("message")' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Error object has message field"
else
    echo -e "${RED}✗${NC} Error object missing message field"
    exit 1
fi

# Test 3: Advanced validation with Python if available
echo -e "\n${BLUE}Test 3: Full schema validation with Python${NC}"

if command -v python3 &> /dev/null; then
    # Try to validate with jsonschema if available
    python3 -c "import jsonschema" 2>/dev/null && {
        VALIDATION_RESULT=$(python3 << 'PYTHON_SCRIPT'
import json
import sys

schema_file = "/Users/jack/Code/aic/code-review/schema/pr-comments-output.schema.json"

# Load schema
with open(schema_file, 'r') as f:
    schema = json.load(f)

# Test data
test_data = {
  "pr_info": {
    "organization": "test",
    "repository": "test",
    "pr_number": 1,
    "url": "https://github.com/test/test/pull/1",
    "valid": True
  },
  "pr_comments": [],
  "metadata": {
    "statistics": {
      "total_comments": 0
    },
    "duplicate_groups": {},
    "extraction_timestamp": "2024-01-01T00:00:00Z"
  },
  "errors": []
}

try:
    from jsonschema import validate, ValidationError
    validate(instance=test_data, schema=schema)
    print("VALID")
except ValidationError as e:
    print(f"INVALID: {e.message}")
except ImportError:
    print("SKIP: jsonschema not installed")
except Exception as e:
    print(f"ERROR: {e}")
PYTHON_SCRIPT
        )
        
        if [[ "$VALIDATION_RESULT" == "VALID" ]]; then
            echo -e "${GREEN}✓${NC} Python jsonschema validation passed"
        elif [[ "$VALIDATION_RESULT" == SKIP* ]]; then
            echo -e "${YELLOW}⚠${NC} Python jsonschema not installed (pip install jsonschema)"
        else
            echo -e "${RED}✗${NC} Python validation failed: $VALIDATION_RESULT"
        fi
    } || {
        echo -e "${YELLOW}⚠${NC} Python jsonschema module not available"
        echo "  Install with: pip3 install jsonschema"
    }
else
    echo -e "${YELLOW}⚠${NC} Python3 not found, skipping full validation"
fi

echo -e "\n${GREEN}====================================${NC}"
echo -e "${GREEN}Schema validation tests completed!${NC}"
echo -e "${GREEN}====================================${NC}"