#!/bin/bash

# Normalize text for comparison
normalize_text() {
    local text="$1"
    # Convert to lowercase, trim whitespace, remove multiple spaces
    echo "$text" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' '
}

# Check if two comments are semantically duplicates
are_duplicates() {
    local comment1="$1"
    local comment2="$2"
    
    # Normalize both comments
    local norm1=$(normalize_text "$comment1")
    local norm2=$(normalize_text "$comment2")
    
    # Exact match after normalization
    if [[ "$norm1" == "$norm2" ]]; then
        echo "true"
        return 0
    fi
    
    # Check for common approval patterns
    local approval_patterns=("lgtm" "looks good to me" "looks good" "approved" "👍" "+1" "ship it")
    
    local is_approval1=false
    local is_approval2=false
    
    for pattern in "${approval_patterns[@]}"; do
        if [[ "$norm1" == *"$pattern"* ]] || [[ "$norm1" == "$pattern" ]]; then
            is_approval1=true
        fi
        if [[ "$norm2" == *"$pattern"* ]] || [[ "$norm2" == "$pattern" ]]; then
            is_approval2=true
        fi
    done
    
    # If both are approval messages, consider them duplicates
    if [[ "$is_approval1" == "true" ]] && [[ "$is_approval2" == "true" ]]; then
        echo "true"
        return 0
    fi
    
    echo "false"
    return 1
}

# Calculate similarity score between two strings (0-1)
calculate_similarity() {
    local str1="$1"
    local str2="$2"
    
    # Normalize strings
    local norm1=$(normalize_text "$str1")
    local norm2=$(normalize_text "$str2")
    
    # If strings are identical
    if [[ "$norm1" == "$norm2" ]]; then
        echo "1.0"
        return
    fi
    
    # Simple word-based similarity
    # Count common words
    local words1=($norm1)
    local words2=($norm2)
    local common=0
    local total=${#words1[@]}
    
    if [[ ${#words2[@]} -gt $total ]]; then
        total=${#words2[@]}
    fi
    
    for word1 in "${words1[@]}"; do
        for word2 in "${words2[@]}"; do
            if [[ "$word1" == "$word2" ]]; then
                ((common++))
                break
            fi
        done
    done
    
    if [[ $total -eq 0 ]]; then
        echo "0.0"
    else
        # Calculate similarity as ratio of common words
        echo "scale=2; $common / $total" | bc
    fi
}

# Find groups of duplicate comments in JSON array
find_duplicate_groups() {
    local comments_json="$1"
    
    # Extract comment bodies and IDs
    local num_comments=$(echo "$comments_json" | jq 'length')
    
    # Create JSON object to store duplicate groups
    local groups="{}"
    local group_id=1
    
    for ((i=0; i<$num_comments; i++)); do
        local comment_i=$(echo "$comments_json" | jq -r ".[$i]")
        local id_i=$(echo "$comment_i" | jq -r '.id')
        local body_i=$(echo "$comment_i" | jq -r '.body')
        
        # Skip if already assigned to a group
        local already_grouped=false
        for group_key in $(echo "$groups" | jq -r 'keys[]'); do
            if echo "$groups" | jq -e ".\"$group_key\" | contains([\"$id_i\"])" >/dev/null 2>&1; then
                already_grouped=true
                break
            fi
        done
        
        if [[ "$already_grouped" == "true" ]]; then
            continue
        fi
        
        # Start new group with this comment
        local current_group="[\"$id_i\"]"
        
        # Find all duplicates of this comment
        for ((j=i+1; j<$num_comments; j++)); do
            local comment_j=$(echo "$comments_json" | jq -r ".[$j]")
            local id_j=$(echo "$comment_j" | jq -r '.id')
            local body_j=$(echo "$comment_j" | jq -r '.body')
            
            if [[ $(are_duplicates "$body_i" "$body_j") == "true" ]]; then
                current_group=$(echo "$current_group" | jq ". + [\"$id_j\"]")
            fi
        done
        
        # Add group if it has more than one member
        if [[ $(echo "$current_group" | jq 'length') -gt 1 ]]; then
            groups=$(echo "$groups" | jq ".\"group_$group_id\" = $current_group")
            ((group_id++))
        fi
    done
    
    echo "$groups"
}