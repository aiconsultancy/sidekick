#!/usr/bin/env bash

# Test script for sidekick-pr-rename plugin

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the libraries in correct order
source "$PROJECT_ROOT/lib/output_helpers.sh"
source "$PROJECT_ROOT/plugins/lib/sidekick-pr-rename/extraction.sh"

# Add missing helper functions for tests
info() {
    echo "ℹ $1"
}

success() {
    echo "$1"
}

error() {
    echo "ERROR: $1" >&2
}

warning() {
    echo "⚠ $1"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_case() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        success "✓ $test_name"
        ((TESTS_PASSED++))
    else
        error "✗ $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((TESTS_FAILED++))
    fi
}

echo "Testing PR Rename Module Extraction"
echo "===================================="
echo

# Test branch name extraction patterns
info "Testing branch name patterns..."

# Test 1: Standard feat branch
BRANCH="feat/2.2.13-service-profile-media"
if [[ "$BRANCH" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    MODULE_ID="M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
else
    MODULE_ID=""
fi
test_case "Extract from feat branch" "M2.2.13" "$MODULE_ID"

# Test 2: Fix branch
BRANCH="fix/1.0.5-security-patch"
if [[ "$BRANCH" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    MODULE_ID="M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
else
    MODULE_ID=""
fi
test_case "Extract from fix branch" "M1.0.5" "$MODULE_ID"

# Test 3: Branch without module ID
BRANCH="feature/new-login-system"
if [[ "$BRANCH" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    MODULE_ID="M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
else
    MODULE_ID=""
fi
test_case "No module in branch name" "" "$MODULE_ID"

# Test 4: Complex branch name
BRANCH="chore/3.1.2-update-deps-v2.0.1"
if [[ "$BRANCH" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    MODULE_ID="M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
else
    MODULE_ID=""
fi
test_case "Extract first match from complex branch" "M3.1.2" "$MODULE_ID"

echo
info "Testing module ID validation..."

# Test validation function
test_case "Valid module ID" "0" "$(validate_module_id 'M1.2.3' && echo '0' || echo '1')"
test_case "Invalid module ID (missing M)" "1" "$(validate_module_id '1.2.3' && echo '0' || echo '1')"
test_case "Invalid module ID (wrong format)" "1" "$(validate_module_id 'M1-2-3' && echo '0' || echo '1')"
test_case "Invalid module ID (extra text)" "1" "$(validate_module_id 'M1.2.3.4' && echo '0' || echo '1')"

echo
info "Testing existing module ID detection..."

# Test detecting same module ID
PR_TITLE="feat(domain): implement ServiceProfileMedia entity (M2.2.13)"
if [[ "$PR_TITLE" =~ (M[0-9]+\.[0-9]+\.[0-9]+) ]]; then
    FOUND_ID="${BASH_REMATCH[1]}"
else
    FOUND_ID=""
fi
test_case "Detect existing module ID at end" "M2.2.13" "$FOUND_ID"

# Test detecting module ID in middle
PR_TITLE="feat: M2.2.13 implement ServiceProfileMedia entity"
if [[ "$PR_TITLE" =~ (M[0-9]+\.[0-9]+\.[0-9]+) ]]; then
    FOUND_ID="${BASH_REMATCH[1]}"
else
    FOUND_ID=""
fi
test_case "Detect module ID in middle" "M2.2.13" "$FOUND_ID"

echo
info "Testing PR title modifications..."

# Test title modification
PR_TITLE="feat(domain): implement ServiceProfileMedia entity"
MODULE_ID="M2.2.13"

# Remove existing module ID if present
NEW_TITLE=$(echo "$PR_TITLE" | sed -E 's/ \(M[0-9]+\.[0-9]+\.[0-9]+\)$//')
NEW_TITLE="$NEW_TITLE ($MODULE_ID)"

test_case "Add module ID to title" "feat(domain): implement ServiceProfileMedia entity (M2.2.13)" "$NEW_TITLE"

# Test replacing existing module ID at end
PR_TITLE="feat(domain): implement ServiceProfileMedia entity (M1.1.1)"
MODULE_ID="M2.2.13"

NEW_TITLE=$(echo "$PR_TITLE" | sed -E 's/[[:space:]]*\(?M[0-9]+\.[0-9]+\.[0-9]+\)?//g' | sed 's/[[:space:]]*$//')
NEW_TITLE="$NEW_TITLE ($MODULE_ID)"

test_case "Replace existing module ID at end" "feat(domain): implement ServiceProfileMedia entity (M2.2.13)" "$NEW_TITLE"

# Test replacing module ID in middle of title
PR_TITLE="feat: M1.1.1 implement ServiceProfileMedia entity"
MODULE_ID="M2.2.13"

NEW_TITLE=$(echo "$PR_TITLE" | sed -E 's/[[:space:]]*\(?M[0-9]+\.[0-9]+\.[0-9]+\)?//g' | sed 's/[[:space:]]*$//')
NEW_TITLE="$NEW_TITLE ($MODULE_ID)"

test_case "Replace module ID in middle" "feat: implement ServiceProfileMedia entity (M2.2.13)" "$NEW_TITLE"

# Test title with module ID without parentheses
PR_TITLE="feat(domain): implement ServiceProfileMedia entity M1.1.1"
MODULE_ID="M2.2.13"

NEW_TITLE=$(echo "$PR_TITLE" | sed -E 's/[[:space:]]*\(?M[0-9]+\.[0-9]+\.[0-9]+\)?//g' | sed 's/[[:space:]]*$//')
NEW_TITLE="$NEW_TITLE ($MODULE_ID)"

test_case "Replace module ID without parens" "feat(domain): implement ServiceProfileMedia entity (M2.2.13)" "$NEW_TITLE"

# Print summary
echo
echo "===================================="
success "Tests Passed: $TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    error "Tests Failed: $TESTS_FAILED"
    exit 1
else
    success "All tests passed!"
fi