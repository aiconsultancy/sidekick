#!/usr/bin/env bash

# Module ID validation and extraction functions

# Validate module ID format
validate_module_id() {
    local module_id="$1"
    if [[ "$module_id" =~ ^M[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Extract module from PR description using AI
extract_module_from_description() {
    local description="$1"
    local ai_agent="${2:-claude}"
    local claude_model="${3:-claude-3-5-haiku-20241022}"
    
    # Try to extract module pattern from description
    if [[ "$description" =~ [Mm]odule[[:space:]]+([0-9]+)\.([0-9]+).*[Tt]ask[[:space:]]+([0-9]+) ]]; then
        echo "M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        return 0
    fi
    
    # Try alternate patterns
    if [[ "$description" =~ M([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        return 0
    fi
    
    # If no pattern found, could use AI here but for now return empty
    echo ""
    return 1
}

# Extract module ID from branch name
extract_module_from_branch() {
    local branch="$1"
    if [[ "$branch" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        return 0
    fi
    echo ""
    return 1
}

# Check if PR title has module ID
title_has_module() {
    local title="$1"
    if [[ "$title" =~ M[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        return 0
    else
        return 1
    fi
}

# Extract existing module ID from title
extract_module_from_title() {
    local title="$1"
    if [[ "$title" =~ (M[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    echo ""
    return 1
}

# Remove module ID from title
remove_module_from_title() {
    local title="$1"
    # Remove module ID with or without parentheses
    echo "$title" | sed -E 's/[[:space:]]*\(?M[0-9]+\.[0-9]+\.[0-9]+\)?//g' | sed 's/[[:space:]]*$//'
}

# Add module ID to title
add_module_to_title() {
    local title="$1"
    local module_id="$2"
    
    # Remove any existing module ID first
    local clean_title=$(remove_module_from_title "$title")
    
    # Add new module ID at the end in parentheses
    echo "$clean_title ($module_id)"
}