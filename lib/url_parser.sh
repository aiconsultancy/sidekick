#!/bin/bash

parse_pr_url() {
    local url="$1"
    
    # Clear previous values
    PR_ORG=""
    PR_REPO=""
    PR_NUMBER=""
    
    # Validate it's a GitHub PR URL
    if [[ ! "$url" =~ ^https://github\.com/[^/]+/[^/]+/pull/[0-9]+ ]]; then
        return 1
    fi
    
    # Extract components using regex
    if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        PR_ORG="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        return 0
    fi
    
    return 1
}