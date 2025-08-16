#!/bin/bash

# Issue Deduplicator Library Functions
# Core functions for detecting and managing duplicate GitHub issues

# Fetch all open issues from repository with error handling
fetch_all_issues() {
    local org="$1"
    local repo="$2"
    local limit="${3:-1000}"
    
    # Validate inputs
    if [[ -z "$org" ]] || [[ -z "$repo" ]]; then
        echo "[]" >&2
        return 1
    fi
    
    # Check for gh CLI
    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) is not installed" >&2
        echo "[]"
        return 1
    fi
    
    # Check authentication
    if ! gh auth status &>/dev/null; then
        echo "Error: Not authenticated with GitHub. Run: gh auth login" >&2
        echo "[]"
        return 1
    fi
    
    # Fetch with retry logic
    local attempts=0
    local max_attempts=3
    local result=""
    
    while [[ $attempts -lt $max_attempts ]]; do
        result=$(gh issue list \
            --repo "$org/$repo" \
            --limit "$limit" \
            -s open \
            --json number,title,createdAt,author,url 2>&1)
        
        if [[ $? -eq 0 ]]; then
            echo "$result"
            return 0
        fi
        
        # Check for rate limiting
        if echo "$result" | grep -q "rate limit"; then
            echo "Error: GitHub API rate limit exceeded. Try again later." >&2
            echo "[]"
            return 1
        fi
        
        # Check for repo not found
        if echo "$result" | grep -q "Could not resolve"; then
            echo "Error: Repository $org/$repo not found or not accessible" >&2
            echo "[]"
            return 1
        fi
        
        ((attempts++))
        if [[ $attempts -lt $max_attempts ]]; then
            sleep 2
        fi
    done
    
    echo "Error: Failed to fetch issues after $max_attempts attempts" >&2
    echo "[]"
    return 1
}

# Normalize title for comparison
normalize_title() {
    local title="$1"
    
    # Convert to lowercase
    title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    
    # Remove special characters except spaces
    title=$(echo "$title" | sed 's/[^a-z0-9 ]//g')
    
    # Remove common stop words efficiently using a single sed command
    # Use space boundaries to ensure we only match whole words
    title=$(echo " $title " | sed -E 's/ (the|a|an|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|could|should|may|might|must|can|shall|to|of|in|for|on|at|with|by|from|about|into|through|during|before|after|above|below|between|under|over|not) / /g')
    
    # Remove extra spaces and trim
    title=$(echo "$title" | tr -s ' ' | sed 's/^ *//;s/ *$//')
    
    echo "$title"
}

# Calculate Levenshtein distance as percentage similarity
calculate_levenshtein() {
    local str1="$1"
    local str2="$2"
    
    # If strings are identical
    if [[ "$str1" == "$str2" ]]; then
        echo "100"
        return
    fi
    
    local len1=${#str1}
    local len2=${#str2}
    
    # If one string is empty
    if [[ $len1 -eq 0 ]] || [[ $len2 -eq 0 ]]; then
        echo "0"
        return
    fi
    
    # For completely different strings
    local has_common=false
    for ((i=0; i<$len1; i++)); do
        local char="${str1:$i:1}"
        if [[ "$str2" == *"$char"* ]]; then
            has_common=true
            break
        fi
    done
    
    if [[ "$has_common" == "false" ]]; then
        echo "0"
        return
    fi
    
    # Count matching characters at same positions
    local matches=0
    local min_len=$len1
    if [[ $len2 -lt $min_len ]]; then
        min_len=$len2
    fi
    
    for ((i=0; i<$min_len; i++)); do
        if [[ "${str1:$i:1}" == "${str2:$i:1}" ]]; then
            ((matches++))
        fi
    done
    
    # Also check for shifted matches
    local shifted_matches=0
    for ((i=0; i<$len1; i++)); do
        for ((j=0; j<$len2; j++)); do
            if [[ "${str1:$i:1}" == "${str2:$j:1}" ]]; then
                ((shifted_matches++))
                break
            fi
        done
    done
    
    # Use the better score
    if [[ $shifted_matches -gt $matches ]]; then
        matches=$shifted_matches
    fi
    
    # Calculate percentage based on average length
    local avg_len=$(( (len1 + len2) / 2 ))
    local percentage=$((matches * 100 / avg_len))
    
    # Cap at 100
    if [[ $percentage -gt 100 ]]; then
        percentage=100
    fi
    
    echo "$percentage"
}

# Calculate token overlap percentage (Jaccard similarity)
calculate_token_overlap() {
    local str1="$1"
    local str2="$2"
    
    # Split into tokens
    local -a tokens1=($str1)
    local -a tokens2=($str2)
    
    # If either is empty
    if [[ ${#tokens1[@]} -eq 0 ]] || [[ ${#tokens2[@]} -eq 0 ]]; then
        echo "0"
        return
    fi
    
    # Count intersection
    local intersection=0
    for token1 in "${tokens1[@]}"; do
        for token2 in "${tokens2[@]}"; do
            if [[ "$token1" == "$token2" ]]; then
                ((intersection++))
                break
            fi
        done
    done
    
    # Count union (total unique tokens)
    local -a all_tokens=("${tokens1[@]}" "${tokens2[@]}")
    local -a unique_tokens=()
    for token in "${all_tokens[@]}"; do
        local found=0
        for unique in "${unique_tokens[@]}"; do
            if [[ "$token" == "$unique" ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            unique_tokens+=("$token")
        fi
    done
    
    local union=${#unique_tokens[@]}
    
    # Calculate Jaccard similarity
    if [[ $union -eq 0 ]]; then
        echo "0"
    else
        local percentage=$((intersection * 100 / union))
        echo "$percentage"
    fi
}

# Calculate weighted similarity score
similarity_score() {
    local title1="$1"
    local title2="$2"
    
    # Normalize titles
    local norm1=$(normalize_title "$title1")
    local norm2=$(normalize_title "$title2")
    
    # If normalized titles are identical
    if [[ "$norm1" == "$norm2" ]]; then
        echo "100"
        return
    fi
    
    # Calculate Levenshtein similarity (70% weight)
    local lev_score=$(calculate_levenshtein "$norm1" "$norm2")
    
    # Calculate token overlap (30% weight)
    local token_score=$(calculate_token_overlap "$norm1" "$norm2")
    
    # Weighted average
    local final_score=$(( (lev_score * 70 + token_score * 30) / 100 ))
    
    echo "$final_score"
}

# Show progress spinner
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-Processing}"
    
    local percentage=$((current * 100 / total))
    printf "\r%s... %d/%d (%d%%)" "$message" "$current" "$total" "$percentage" >&2
}

# Find duplicate groups based on threshold
find_duplicate_groups() {
    local issues_json="$1"
    local threshold="${2:-85}"
    
    # Parse issues into array
    local issue_count=$(echo "$issues_json" | jq 'length')
    
    if [[ $issue_count -eq 0 ]]; then
        echo "[]"
        return
    fi
    
    # Build similarity groups
    local groups="[]"
    local processed=""
    
    for ((i=0; i<$issue_count; i++)); do
        if [[ -t 2 ]]; then  # Only show progress if stderr is a terminal
            show_progress $((i+1)) $issue_count "Analyzing issues"
        fi
        # Skip if already processed
        if [[ "$processed" == *",$i,"* ]]; then
            continue
        fi
        
        local issue_i=$(echo "$issues_json" | jq ".[$i]")
        local title_i=$(echo "$issue_i" | jq -r '.title')
        local number_i=$(echo "$issue_i" | jq -r '.number')
        
        # Start new group with this issue
        local group="[$number_i"
        local has_duplicates=false
        
        # Compare with remaining issues
        for ((j=i+1; j<$issue_count; j++)); do
            # Skip if already processed
            if [[ "$processed" == *",$j,"* ]]; then
                continue
            fi
            
            local issue_j=$(echo "$issues_json" | jq ".[$j]")
            local title_j=$(echo "$issue_j" | jq -r '.title')
            local number_j=$(echo "$issue_j" | jq -r '.number')
            
            # Calculate similarity
            local score=$(similarity_score "$title_i" "$title_j")
            
            if [[ $score -ge $threshold ]]; then
                group="$group,$number_j"
                processed="$processed,$j,"
                has_duplicates=true
            fi
        done
        
        group="$group]"
        processed="$processed,$i,"
        
        # Only add groups with duplicates
        if [[ "$has_duplicates" == "true" ]]; then
            if [[ "$groups" == "[]" ]]; then
                groups="[$group]"
            else
                groups="${groups%]}, $group]"
            fi
        fi
    done
    
    echo "$groups"
}

# Process a duplicate group to identify keeper and duplicates
process_duplicate_group() {
    local issues_json="$1"
    local group="$2"
    
    # Parse group (array of issue numbers)
    local group_numbers=$(echo "$group" | tr -d '[]' | tr ',' ' ')
    
    # Find the newest issue (remember: list is already sorted newest first)
    local newest_number=""
    local newest_date=""
    
    for number in $group_numbers; do
        local issue=$(echo "$issues_json" | jq ".[] | select(.number == $number)")
        local created_at=$(echo "$issue" | jq -r '.createdAt')
        
        if [[ -z "$newest_date" ]] || [[ "$created_at" > "$newest_date" ]]; then
            newest_date="$created_at"
            newest_number="$number"
        fi
    done
    
    # Build result with keeper and duplicates
    local result="{\"keeper\": $newest_number, \"duplicates\": ["
    local first=true
    
    for number in $group_numbers; do
        if [[ "$number" != "$newest_number" ]]; then
            if [[ "$first" == "false" ]]; then
                result="$result, "
            fi
            result="$result$number"
            first=false
        fi
    done
    
    result="$result]}"
    echo "$result"
}

# Export functions if sourced in test mode
if [[ "$TEST_MODE" == "true" ]]; then
    export -f fetch_all_issues
    export -f normalize_title
    export -f calculate_levenshtein
    export -f calculate_token_overlap
    export -f similarity_score
    export -f find_duplicate_groups
    export -f process_duplicate_group
fi