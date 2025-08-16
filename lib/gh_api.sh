#!/bin/bash

# Build API endpoint for PR issue comments
build_pr_comments_endpoint() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    echo "repos/${org}/${repo}/issues/${pr_number}/comments"
}

# Build API endpoint for PR review comments
build_pr_review_comments_endpoint() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    echo "repos/${org}/${repo}/pulls/${pr_number}/comments"
}

# Build API endpoint for PR reviews
build_pr_reviews_endpoint() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    echo "repos/${org}/${repo}/pulls/${pr_number}/reviews"
}

# Fetch PR issue comments
fetch_pr_comments() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    
    local endpoint=$(build_pr_comments_endpoint "$org" "$repo" "$pr_number")
    gh api "$endpoint" --paginate 2>/dev/null || echo "[]"
}

# Fetch PR review comments
fetch_pr_review_comments() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    
    local endpoint=$(build_pr_review_comments_endpoint "$org" "$repo" "$pr_number")
    gh api "$endpoint" --paginate 2>/dev/null || echo "[]"
}

# Fetch PR reviews
fetch_pr_reviews() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    
    local endpoint=$(build_pr_reviews_endpoint "$org" "$repo" "$pr_number")
    gh api "$endpoint" --paginate 2>/dev/null || echo "[]"
}

# Fetch all PR data (comments, review comments, and reviews)
fetch_all_pr_data() {
    local org="$1"
    local repo="$2"
    local pr_number="$3"
    
    local issue_comments=$(fetch_pr_comments "$org" "$repo" "$pr_number")
    local review_comments=$(fetch_pr_review_comments "$org" "$repo" "$pr_number")
    local reviews=$(fetch_pr_reviews "$org" "$repo" "$pr_number")
    
    # Combine all data into a single JSON object
    jq -n \
        --argjson issue_comments "$issue_comments" \
        --argjson review_comments "$review_comments" \
        --argjson reviews "$reviews" \
        '{
            issue_comments: $issue_comments,
            review_comments: $review_comments,
            reviews: $reviews
        }'
}