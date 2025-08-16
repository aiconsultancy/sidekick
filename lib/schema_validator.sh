#!/bin/bash

# Schema validation functions using jq
# Can be sourced by other scripts to validate JSON output

# Validate PR comments output against schema structure
validate_pr_comments_schema() {
    local json="$1"
    
    # Check if valid JSON
    if ! echo "$json" | jq empty 2>/dev/null; then
        echo "Invalid JSON" >&2
        return 1
    fi
    
    # Define validation query that checks all required fields
    local validation_query='
    # Check top-level required fields
    if (has("pr_info") and has("pr_comments") and has("metadata") and has("errors")) then
        # Check pr_info required fields
        if (.pr_info | has("organization") and has("repository") and has("pr_number") and has("url") and has("valid")) then
            # Check types
            if (.pr_info.pr_number | type == "number") and
               (.pr_comments | type == "array") and
               (.errors | type == "array") and
               (.metadata | type == "object") then
                # Check metadata required fields
                if (.metadata | has("statistics") and has("duplicate_groups") and has("extraction_timestamp")) then
                    # Check statistics required field
                    if (.metadata.statistics | has("total_comments")) then
                        # Check if pr_comments items have required fields (if any exist)
                        if (.pr_comments | length == 0) or 
                           (.pr_comments | all(has("comment_id") and has("author") and has("body") and has("created_at") and has("type"))) then
                            "valid"
                        else
                            "invalid: pr_comments items missing required fields"
                        end
                    else
                        "invalid: metadata.statistics missing total_comments"
                    end
                else
                    "invalid: metadata missing required fields"
                end
            else
                "invalid: incorrect field types"
            end
        else
            "invalid: pr_info missing required fields"
        end
    else
        "invalid: missing required top-level fields"
    end'
    
    # Run validation
    local result=$(echo "$json" | jq -r "$validation_query" 2>/dev/null)
    
    if [[ "$result" == "valid" ]]; then
        return 0
    else
        echo "Schema validation failed: $result" >&2
        return 1
    fi
}

# Validate and report schema compliance
validate_with_report() {
    local json
    if [[ "$1" == "-" ]] || [[ -z "$1" ]]; then
        json=$(cat)
    else
        json="$1"
    fi
    local quiet="${2:-false}"
    
    if [[ "$quiet" != "true" ]]; then
        echo "Validating JSON schema compliance..." >&2
    fi
    
    # Detailed validation checks
    local errors=()
    
    # Check JSON validity
    if ! echo "$json" | jq empty 2>/dev/null; then
        errors+=("Not valid JSON")
    else
        # Check required fields
        for field in pr_info pr_comments metadata errors; do
            if ! echo "$json" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
                errors+=("Missing required field: $field")
            fi
        done
        
        # Check pr_info
        if echo "$json" | jq -e "has(\"pr_info\")" >/dev/null 2>&1; then
            for field in organization repository pr_number url valid; do
                if ! echo "$json" | jq -e ".pr_info | has(\"$field\")" >/dev/null 2>&1; then
                    errors+=("Missing required field: pr_info.$field")
                fi
            done
            
            # Check types
            if ! echo "$json" | jq -e '.pr_info.pr_number | type == "number"' >/dev/null 2>&1; then
                errors+=("pr_info.pr_number must be a number")
            fi
        fi
        
        # Check arrays
        if ! echo "$json" | jq -e '.pr_comments | type == "array"' >/dev/null 2>&1; then
            errors+=("pr_comments must be an array")
        fi
        
        if ! echo "$json" | jq -e '.errors | type == "array"' >/dev/null 2>&1; then
            errors+=("errors must be an array")
        fi
        
        # Check metadata
        if echo "$json" | jq -e "has(\"metadata\")" >/dev/null 2>&1; then
            for field in statistics duplicate_groups extraction_timestamp; do
                if ! echo "$json" | jq -e ".metadata | has(\"$field\")" >/dev/null 2>&1; then
                    errors+=("Missing required field: metadata.$field")
                fi
            done
            
            if ! echo "$json" | jq -e '.metadata.statistics | has("total_comments")' >/dev/null 2>&1; then
                errors+=("Missing required field: metadata.statistics.total_comments")
            fi
        fi
    fi
    
    # Report results
    if [[ ${#errors[@]} -eq 0 ]]; then
        if [[ "$quiet" != "true" ]]; then
            echo "✓ Schema validation passed" >&2
        fi
        return 0
    else
        if [[ "$quiet" != "true" ]]; then
            echo "✗ Schema validation failed:" >&2
            for error in "${errors[@]}"; do
                echo "  - $error" >&2
            done
        fi
        return 1
    fi
}

# Quick validation function for use in pipes
validate_schema() {
    local json
    if [[ -n "$1" ]]; then
        json="$1"
    else
        json=$(cat)
    fi
    
    validate_pr_comments_schema "$json"
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f validate_pr_comments_schema
    export -f validate_with_report
    export -f validate_schema
fi