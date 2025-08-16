#!/bin/bash

# Format a single comment to our standard JSON structure
format_comment_json() {
    local comment="$1"
    
    # Extract fields from the comment
    local id=$(echo "$comment" | jq -r '.id // ""')
    local author=$(echo "$comment" | jq -r '.user.login // ""')
    local body=$(echo "$comment" | jq -r '.body // ""')
    local created_at=$(echo "$comment" | jq -r '.created_at // ""')
    local updated_at=$(echo "$comment" | jq -r '.updated_at // ""')
    local url=$(echo "$comment" | jq -r '.html_url // ""')
    local reactions=$(echo "$comment" | jq '.reactions // {}')
    
    # Build formatted JSON
    if [[ -z "$reactions" ]] || [[ "$reactions" == "null" ]]; then
        reactions="{}"
    fi
    
    jq -n \
        --arg id "$id" \
        --arg author "$author" \
        --arg body "$body" \
        --arg created_at "$created_at" \
        --arg updated_at "$updated_at" \
        --arg url "$url" \
        --argjson reactions "$reactions" \
        '{
            comment_id: $id,
            author: $author,
            body: $body,
            created_at: $created_at,
            updated_at: $updated_at,
            url: $url,
            reactions: $reactions
        }'
}

# Format comment with additional metadata
format_comment_with_metadata() {
    local comment="$1"
    local status="${2:-pending}"
    local duplicate_group="${3:-}"
    
    local formatted=$(format_comment_json "$comment")
    
    # Add metadata
    formatted=$(echo "$formatted" | jq \
        --arg status "$status" \
        --arg duplicate_group "$duplicate_group" \
        '. + {
            status: $status,
            duplicate_group: (if $duplicate_group == "" then null else $duplicate_group end)
        }')
    
    echo "$formatted"
}

# Detect comment status from keywords
detect_comment_status() {
    local comment="$1"
    local body=$(echo "$comment" | jq -r '.body // ""' | tr '[:upper:]' '[:lower:]')
    
    if [[ "$body" == *"[resolved]"* ]] || [[ "$body" == *"[fixed]"* ]]; then
        echo "resolved"
    elif [[ "$body" == *"[ignore]"* ]] || [[ "$body" == *"[wontfix]"* ]]; then
        echo "ignored"
    else
        echo "pending"
    fi
}

# Generate statistics from the data
generate_statistics() {
    local all_data="$1"
    local duplicate_groups="$2"
    
    local issue_count=$(echo "$all_data" | jq '.issue_comments | length')
    local review_count=$(echo "$all_data" | jq '.review_comments | length')
    local reviews_count=$(echo "$all_data" | jq '.reviews | length')
    local total=$((issue_count + review_count))
    
    local duplicate_count=0
    if [[ -n "$duplicate_groups" ]] && [[ "$duplicate_groups" != "{}" ]]; then
        # Count all IDs in duplicate groups
        duplicate_count=$(echo "$duplicate_groups" | jq '[.[] | length] | add // 0')
    fi
    
    jq -n \
        --arg total "$total" \
        --arg issue_count "$issue_count" \
        --arg review_count "$review_count" \
        --arg reviews_count "$reviews_count" \
        --arg duplicate_count "$duplicate_count" \
        '{
            total_comments: ($total | tonumber),
            issue_comments: ($issue_count | tonumber),
            review_comments: ($review_count | tonumber),
            reviews: ($reviews_count | tonumber),
            duplicate_count: ($duplicate_count | tonumber)
        }'
}

# Format complete output structure
format_complete_output() {
    local all_data="$1"
    local duplicate_groups="$2"
    local format="${3:-json}"
    
    # Process all comments
    local formatted_comments="[]"
    
    # Process issue comments
    local issue_comments=$(echo "$all_data" | jq '.issue_comments // []')
    local num_issue_comments=$(echo "$issue_comments" | jq 'length')
    
    for ((i=0; i<$num_issue_comments; i++)); do
        local comment=$(echo "$issue_comments" | jq ".[$i]")
        local status=$(detect_comment_status "$comment")
        
        # Check if comment is in a duplicate group
        local comment_id=$(echo "$comment" | jq -r '.id')
        local duplicate_group=""
        
        if [[ -n "$duplicate_groups" ]]; then
            for group_key in $(echo "$duplicate_groups" | jq -r 'keys[]'); do
                if echo "$duplicate_groups" | jq -e ".\"$group_key\" | contains([\"$comment_id\"])" >/dev/null 2>&1; then
                    duplicate_group="$group_key"
                    break
                fi
            done
        fi
        
        local formatted=$(format_comment_with_metadata "$comment" "$status" "$duplicate_group")
        formatted=$(echo "$formatted" | jq '. + {type: "issue_comment"}')
        
        # Safely append to array
        if [[ "$formatted_comments" == "[]" ]]; then
            formatted_comments="[$formatted]"
        else
            formatted_comments=$(echo "$formatted_comments" | jq --argjson new_comment "$formatted" '. + [$new_comment]')
        fi
    done
    
    # Process review comments
    local review_comments=$(echo "$all_data" | jq '.review_comments // []')
    local num_review_comments=$(echo "$review_comments" | jq 'length')
    
    for ((i=0; i<$num_review_comments; i++)); do
        local comment=$(echo "$review_comments" | jq ".[$i]")
        local status=$(detect_comment_status "$comment")
        local comment_id=$(echo "$comment" | jq -r '.id')
        local duplicate_group=""
        
        if [[ -n "$duplicate_groups" ]]; then
            for group_key in $(echo "$duplicate_groups" | jq -r 'keys[]'); do
                if echo "$duplicate_groups" | jq -e ".\"$group_key\" | contains([\"$comment_id\"])" >/dev/null 2>&1; then
                    duplicate_group="$group_key"
                    break
                fi
            done
        fi
        
        local formatted=$(format_comment_with_metadata "$comment" "$status" "$duplicate_group")
        formatted=$(echo "$formatted" | jq '. + {type: "review_comment"}')
        
        # Safely append to array
        if [[ "$formatted_comments" == "[]" ]]; then
            formatted_comments="[$formatted]"
        else
            formatted_comments=$(echo "$formatted_comments" | jq --argjson new_comment "$formatted" '. + [$new_comment]')
        fi
    done
    
    # Generate statistics
    local stats=$(generate_statistics "$all_data" "$duplicate_groups")
    
    # Build final output
    local dup_groups_json="${duplicate_groups:-{}}"
    if [[ -z "$dup_groups_json" ]] || [[ "$dup_groups_json" == "" ]]; then
        dup_groups_json="{}"
    fi
    # Ensure valid JSON
    if ! echo "$dup_groups_json" | jq empty 2>/dev/null; then
        dup_groups_json="{}"
    fi
    
    # Debug: Check each variable  
    # echo "DEBUG: formatted_comments type: $(echo "$formatted_comments" | jq -r type 2>/dev/null || echo "invalid")" >&2
    # echo "DEBUG: dup_groups_json type: $(echo "$dup_groups_json" | jq -r type 2>/dev/null || echo "invalid")" >&2
    # echo "DEBUG: stats type: $(echo "$stats" | jq -r type 2>/dev/null || echo "invalid")" >&2
    
    # Ensure all JSON is valid before passing to jq
    if ! echo "$formatted_comments" | jq empty 2>/dev/null; then
        # echo "DEBUG: formatted_comments is invalid, resetting to []" >&2
        formatted_comments="[]"
    fi
    if ! echo "$dup_groups_json" | jq empty 2>/dev/null; then
        # echo "DEBUG: dup_groups_json is invalid, resetting to {}" >&2
        dup_groups_json="{}"
    fi
    if ! echo "$stats" | jq empty 2>/dev/null; then
        # echo "DEBUG: stats is invalid, resetting to {}" >&2
        stats="{}"
    fi
    
    # Create timestamp separately to avoid issues
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local output=$(jq -n \
        --argjson comments "$formatted_comments" \
        --argjson duplicate_groups "$dup_groups_json" \
        --argjson stats "$stats" \
        --arg timestamp "$timestamp" \
        '{
            pr_comments: $comments,
            metadata: {
                statistics: $stats,
                duplicate_groups: $duplicate_groups,
                extraction_timestamp: $timestamp
            }
        }')
    
    # Convert to YAML if requested
    if [[ "$format" == "yaml" ]]; then
        if command -v yq >/dev/null 2>&1; then
            echo "$output" | yq -P '.'
        elif command -v python3 >/dev/null 2>&1; then
            echo "$output" | python3 -c "import json, yaml, sys; print(yaml.dump(json.load(sys.stdin), default_flow_style=False))"
        else
            # Fallback to simple conversion
            echo "pr_comments:"
            echo "$formatted_comments" | jq -r '.[] | "  - comment_id: \(.comment_id)\n    author: \(.author)\n    body: \(.body)\n    status: \(.status)"'
            echo "metadata:"
            echo "  statistics:"
            echo "$stats" | jq -r 'to_entries | .[] | "    \(.key): \(.value)"'
            echo "  duplicate_groups:"
            echo "$duplicate_groups" | jq -r 'to_entries | .[] | "    \(.key): \(.value | @json)"'
        fi
    else
        echo "$output"
    fi
}