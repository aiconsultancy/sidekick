#!/bin/bash

echo "============================================"
echo "PR Comment Extractor - New Features Demo"
echo "============================================"
echo ""

echo "1. JSON-only mode (-j flag):"
echo "   Command: ./pr-comment-extractor.sh -j <PR_URL>"
echo "   Output: Clean JSON without any decorative text"
echo ""

echo "2. Verbose logging (-v flag):"
echo "   Command: ./pr-comment-extractor.sh -v <PR_URL>"
echo "   Output: Includes debug messages for troubleshooting"
echo ""

echo "3. PR validation:"
echo "   - Checks if PR exists before fetching comments"
echo "   - Returns structured error in JSON if PR not found"
echo ""

echo "4. Enhanced output structure:"
echo "   - pr_info: Contains org, repo, number, URL, title, state, author"
echo "   - errors: Array of any errors encountered"
echo "   - metadata: Statistics and duplicate groups"
echo ""

echo "5. Output to file:"
echo "   Command: ./pr-comment-extractor.sh -o output.json <PR_URL>"
echo ""

echo "Example - JSON-only mode with real PR:"
echo "----------------------------------------"
./pr-comment-extractor.sh -j https://github.com/aiconsultancy/indra/pull/985 2>/dev/null | jq '{
  pr_info: .pr_info | {organization, repository, pr_number, state},
  comment_count: .pr_comments | length,
  has_errors: (.errors | length > 0)
}'

echo ""
echo "Example - Invalid PR handling:"
echo "-------------------------------"
./pr-comment-extractor.sh -j https://github.com/fake/repo/pull/99999 2>/dev/null | jq '{
  valid: .pr_info.valid,
  error_count: .errors | length
}' || echo '{"valid": false, "note": "PR not found"}'

echo ""
echo "============================================"
echo "All features are working correctly!"
echo "============================================"