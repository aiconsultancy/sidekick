#!/bin/bash

echo "============================================"
echo "PR Comment Extractor - Enhanced Metadata Demo"
echo "============================================"
echo ""

echo "Testing with a real PR to show all the new metadata..."
echo ""

# Extract and show key metadata
OUTPUT=$(./pr-comment-extractor.sh -j https://github.com/aiconsultancy/indra/pull/985 2>/dev/null)

echo "📋 PR Information:"
echo "=================="
echo "$OUTPUT" | jq -r '.pr_info | "Title: \(.title)\nState: \(.state)\nAuthor: \(.author)\nDraft: \(.draft)\nMergeable: \(.mergeable)"'

echo ""
echo "🌳 Branch Information:"
echo "====================="
echo "$OUTPUT" | jq -r '.pr_info | "Head Branch: \(.head_branch)\nBase Branch: \(.base_branch)\nHead SHA: \(.head_sha[0:8])..."'

echo ""
echo "✅ CI/Check Status:"
echo "==================="
echo "$OUTPUT" | jq -r '.pr_info.checks | "Total Checks: \(.total)\n✓ Passed: \(.passed)\n✗ Failed: \(.failed)\n⏳ Pending: \(.pending)"'

echo ""
echo "📝 Individual Check Results:"
echo "============================"
echo "$OUTPUT" | jq -r '.pr_info.checks.runs[] | "- \(.name): \(.status) (\(.conclusion))"'

echo ""
echo "📊 Comment Statistics:"
echo "====================="
echo "$OUTPUT" | jq -r '.metadata.statistics | "Issue Comments: \(.issue_comments)\nReview Comments: \(.review_comments)\nReviews: \(.reviews)\nTotal: \(.total_comments)"'

echo ""
echo "🚨 Errors:"
echo "=========="
ERROR_COUNT=$(echo "$OUTPUT" | jq '.errors | length')
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "No errors encountered ✓"
else
    echo "$OUTPUT" | jq -r '.errors[] | "- \(.message)"'
fi

echo ""
echo "============================================"
echo "All enhanced metadata features demonstrated!"
echo "============================================"