#!/bin/bash

# Demo script showing the PR Comment Extractor in action

echo "================================================"
echo "PR Comment Extractor - Demo"
echo "================================================"
echo ""
echo "This demonstrates how the tool works without actually"
echo "calling the GitHub API."
echo ""

echo "1. Testing URL parsing:"
echo "   Input: https://github.com/aiconsultancy/indra/pull/985"
source lib/url_parser.sh
parse_pr_url "https://github.com/aiconsultancy/indra/pull/985"
echo "   ✓ Organization: $PR_ORG"
echo "   ✓ Repository: $PR_REPO"
echo "   ✓ PR Number: $PR_NUMBER"
echo ""

echo "2. Testing duplicate detection:"
source lib/duplicate_detector.sh
comment1="LGTM"
comment2="Looks good to me"
if [[ $(are_duplicates "$comment1" "$comment2") == "true" ]]; then
    echo "   ✓ Detected '$comment1' and '$comment2' as duplicates"
fi
echo ""

echo "3. Testing output formatting:"
echo "   See example_output.json for sample formatted output"
echo ""

echo "4. Running all tests:"
./run_tests.sh 2>&1 | tail -3
echo ""

echo "================================================"
echo "To use with a real PR, run:"
echo "./pr-comment-extractor.sh https://github.com/org/repo/pull/123"
echo "================================================"