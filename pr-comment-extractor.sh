#!/bin/bash

# PR Comment Extractor
# Extracts and analyzes GitHub PR comments for task generation

set -e

# Source all library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/url_parser.sh"
source "$SCRIPT_DIR/lib/gh_api.sh"
source "$SCRIPT_DIR/lib/duplicate_detector.sh"
source "$SCRIPT_DIR/lib/output_formatter.sh"
source "$SCRIPT_DIR/lib/output_helpers.sh"

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FORMAT="json"
OUTPUT_FILE=""
VERBOSE=false
JSON_ONLY=false
ERRORS_LIST="[]"

# Progress indicators
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# No longer needed - using output_helpers.sh functions

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <PR_URL|org repo pr_number>

Extract and analyze GitHub PR comments for task generation.

OPTIONS:
    -f, --format FORMAT    Output format: json (default) or yaml
    -o, --output FILE      Write output to file instead of stdout
    -j, --json-only        Output JSON only, no decorative text
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

EXAMPLES:
    # Using PR URL
    $(basename "$0") https://github.com/org/repo/pull/123
    
    # Using separate arguments
    $(basename "$0") org repo 123
    
    # Output to file in YAML format
    $(basename "$0") -f yaml -o comments.yaml https://github.com/org/repo/pull/123

ENVIRONMENT:
    GITHUB_TOKEN    GitHub personal access token (required for private repos)

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                OUTPUT_FORMAT="$2"
                if [[ "$OUTPUT_FORMAT" != "json" ]] && [[ "$OUTPUT_FORMAT" != "yaml" ]]; then
                    output_error_tracked "Invalid format: $OUTPUT_FORMAT. Use 'json' or 'yaml'"
                    exit 1
                fi
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -j|--json-only)
                JSON_ONLY=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                output_error_tracked "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # Positional arguments
                if [[ -z "$PR_INPUT" ]]; then
                    PR_INPUT="$1"
                elif [[ -z "$REPO_INPUT" ]]; then
                    REPO_INPUT="$1"
                elif [[ -z "$PR_NUM_INPUT" ]]; then
                    PR_NUM_INPUT="$1"
                else
                    output_error_tracked "Too many arguments"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Main execution
main() {
    # Parse arguments first to determine mode
    parse_arguments "$@"
    
    output_header
    
    # Check for required input
    if [[ -z "$PR_INPUT" ]]; then
        output_error_tracked "No PR URL or arguments provided"
        usage
        exit 1
    fi
    
    # Parse PR information
    output_step "1/6" "Parsing PR information"
    output_verbose "Input: PR_INPUT=$PR_INPUT, REPO_INPUT=$REPO_INPUT, PR_NUM_INPUT=$PR_NUM_INPUT"
    
    if [[ "$PR_INPUT" =~ ^https://github\.com/ ]]; then
        # URL provided
        output_verbose "Detected URL format: $PR_INPUT"
        parse_pr_url "$PR_INPUT"
        if [[ -z "$PR_ORG" ]] || [[ -z "$PR_REPO" ]] || [[ -z "$PR_NUMBER" ]]; then
            output_error_tracked "Failed to parse PR URL: $PR_INPUT"
            
            # Output error JSON if in JSON-only mode
            if [[ "$JSON_ONLY" == "true" ]]; then
                local error_output=$(jq -n \
                    --arg url "$PR_INPUT" \
                    --argjson errors "$ERRORS_LIST" \
                    '{
                        pr_info: {url: $url, valid: false},
                        pr_comments: [],
                        metadata: {},
                        errors: $errors
                    }')
                echo "$error_output"
            fi
            exit 1
        fi
        PR_URL="$PR_INPUT"
        output_success "Parsed PR URL"
    else
        # Separate arguments provided
        PR_ORG="$PR_INPUT"
        PR_REPO="$REPO_INPUT"
        PR_NUMBER="$PR_NUM_INPUT"
        
        output_verbose "Parsed args: org=$PR_ORG, repo=$PR_REPO, number=$PR_NUMBER"
        
        if [[ -z "$PR_ORG" ]] || [[ -z "$PR_REPO" ]] || [[ -z "$PR_NUMBER" ]]; then
            output_error_tracked "Missing required arguments: org, repo, and pr_number"
            
            if [[ "$JSON_ONLY" == "true" ]]; then
                local error_output=$(jq -n \
                    --argjson errors "$ERRORS_LIST" \
                    '{
                        pr_info: {valid: false},
                        pr_comments: [],
                        metadata: {},
                        errors: $errors
                    }')
                echo "$error_output"
            else
                usage
            fi
            exit 1
        fi
        PR_URL="https://github.com/$PR_ORG/$PR_REPO/pull/$PR_NUMBER"
        output_success "Parsed PR arguments"
    fi
    
    output_info "Organization" "$PR_ORG"
    output_info "Repository" "$PR_REPO"
    output_info "PR Number" "#$PR_NUMBER"
    output_newline
    
    # Check gh CLI authentication
    output_step "2/6" "Checking GitHub authentication"
    output_verbose "Checking gh auth status"
    if ! gh auth status >/dev/null 2>&1; then
        output_warning "Not authenticated with GitHub"
        output_print "  Run: gh auth login"
        output_print "  Or set GITHUB_TOKEN environment variable"
        output_error_tracked "GitHub authentication required"
        
        if [[ "$JSON_ONLY" == "true" ]]; then
            local error_output=$(jq -n \
                --arg org "$PR_ORG" \
                --arg repo "$PR_REPO" \
                --arg number "$PR_NUMBER" \
                --arg url "$PR_URL" \
                --argjson errors "$ERRORS_LIST" \
                '{
                    pr_info: {
                        organization: $org,
                        repository: $repo,
                        pr_number: $number,
                        url: $url,
                        valid: false
                    },
                    pr_comments: [],
                    metadata: {},
                    errors: $errors
                }')
            echo "$error_output"
        fi
        exit 1
    fi
    output_success "GitHub authentication verified"
    output_newline
    
    # Validate PR exists
    output_step "3/6" "Validating PR exists"
    output_verbose "Checking if PR exists: repos/$PR_ORG/$PR_REPO/pulls/$PR_NUMBER"
    
    pr_info=$(gh api "repos/$PR_ORG/$PR_REPO/pulls/$PR_NUMBER" 2>/dev/null || echo "")
    
    # Check if we got an error response or empty response
    if [[ -z "$pr_info" ]] || [[ $(echo "$pr_info" | jq -r '.message // ""' 2>/dev/null) == "Not Found" ]]; then
        output_error_tracked "PR not found: $PR_URL"
        
        if [[ "$JSON_ONLY" == "true" ]]; then
            local error_output=$(jq -n \
                --arg org "$PR_ORG" \
                --arg repo "$PR_REPO" \
                --arg number "$PR_NUMBER" \
                --arg url "$PR_URL" \
                --argjson errors "$ERRORS_LIST" \
                '{
                    pr_info: {
                        organization: $org,
                        repository: $repo,
                        pr_number: $number,
                        url: $url,
                        valid: false
                    },
                    pr_comments: [],
                    metadata: {},
                    errors: $errors
                }')
            echo "$error_output"
        fi
        exit 1
    fi
    
    # Extract PR metadata
    PR_TITLE=$(echo "$pr_info" | jq -r '.title // ""')
    PR_STATE=$(echo "$pr_info" | jq -r '.state // ""')
    PR_AUTHOR=$(echo "$pr_info" | jq -r '.user.login // ""')
    PR_CREATED=$(echo "$pr_info" | jq -r '.created_at // ""')
    
    # Handle empty title
    if [[ -z "$PR_TITLE" ]]; then
        PR_TITLE="(No title)"
    fi
    
    output_success "PR validated: #$PR_NUMBER - $PR_TITLE"
    output_verbose "PR state: $PR_STATE, author: $PR_AUTHOR"
    output_newline
    
    # Fetch PR data
    output_step "4/6" "Fetching PR comments"
    output_progress "  Fetching issue comments..."
    output_verbose "Fetching issue comments from API"
    issue_comments=$(fetch_pr_comments "$PR_ORG" "$PR_REPO" "$PR_NUMBER")
    if [[ -z "$issue_comments" ]] || [[ "$issue_comments" == "null" ]]; then
        issue_comments="[]"
    fi
    issue_count=$(echo "$issue_comments" | jq 'length // 0')
    output_success "Found $issue_count issue comments"
    output_verbose "Issue comments: $issue_count"
    
    output_progress "  Fetching review comments..."
    output_verbose "Fetching review comments from API"
    review_comments=$(fetch_pr_review_comments "$PR_ORG" "$PR_REPO" "$PR_NUMBER")
    if [[ -z "$review_comments" ]] || [[ "$review_comments" == "null" ]]; then
        review_comments="[]"
    fi
    review_count=$(echo "$review_comments" | jq 'length // 0')
    output_success "Found $review_count review comments"
    output_verbose "Review comments: $review_count"
    
    output_progress "  Fetching reviews..."
    output_verbose "Fetching reviews from API"
    reviews=$(fetch_pr_reviews "$PR_ORG" "$PR_REPO" "$PR_NUMBER")
    if [[ -z "$reviews" ]] || [[ "$reviews" == "null" ]]; then
        reviews="[]"
    fi
    reviews_count=$(echo "$reviews" | jq 'length // 0')
    output_success "Found $reviews_count reviews"
    output_verbose "Reviews: $reviews_count"
    output_newline
    
    # Combine all data
    # Ensure all variables are valid JSON
    if ! echo "$issue_comments" | jq empty 2>/dev/null; then
        issue_comments="[]"
    fi
    if ! echo "$review_comments" | jq empty 2>/dev/null; then
        review_comments="[]"
    fi
    if ! echo "$reviews" | jq empty 2>/dev/null; then
        reviews="[]"
    fi
    
    all_data=$(jq -n \
        --argjson issue_comments "$issue_comments" \
        --argjson review_comments "$review_comments" \
        --argjson reviews "$reviews" \
        '{
            issue_comments: $issue_comments,
            review_comments: $review_comments,
            reviews: $reviews
        }')
    
    # Detect duplicates
    output_step "5/6" "Analyzing comments for duplicates"
    output_verbose "Starting duplicate detection"
    
    # Combine all comments for duplicate detection
    all_comments=$(echo "$all_data" | jq '[.issue_comments[], .review_comments[]]')
    duplicate_groups=$(find_duplicate_groups "$all_comments")
    
    duplicate_count=0
    if [[ "$duplicate_groups" != "{}" ]]; then
        duplicate_count=$(echo "$duplicate_groups" | jq '[.[] | length] | add // 0')
    fi
    
    if [[ $duplicate_count -gt 0 ]]; then
        output_warning "Found $duplicate_count comments in duplicate groups"
        if [[ "$VERBOSE" == "true" ]] && [[ "$JSON_ONLY" != "true" ]]; then
            echo "$duplicate_groups" | jq -r 'to_entries[] | "  Group \(.key): \(.value | join(", "))"'
        fi
        output_verbose "Duplicate groups: $(echo "$duplicate_groups" | jq -c .)"
    else
        output_success "No duplicate comments detected"
    fi
    output_newline
    
    # Create PR metadata JSON
    pr_metadata=$(jq -n \
        --arg org "$PR_ORG" \
        --arg repo "$PR_REPO" \
        --arg number "$PR_NUMBER" \
        --arg url "$PR_URL" \
        --arg title "$PR_TITLE" \
        --arg state "$PR_STATE" \
        --arg author "$PR_AUTHOR" \
        --arg created "$PR_CREATED" \
        '{
            organization: $org,
            repository: $repo,
            pr_number: ($number | tonumber),
            url: $url,
            title: $title,
            state: $state,
            author: $author,
            created_at: $created,
            valid: true
        }')
    
    # Format output
    output_step "6/6" "Generating output"
    output_verbose "Formatting output as $OUTPUT_FORMAT"
    output=$(format_complete_output "$all_data" "$duplicate_groups" "$OUTPUT_FORMAT" "$pr_metadata" "$ERRORS_LIST")
    
    # Write output
    output_result "$output" "$OUTPUT_FILE"
    
    # Show summary if output to file and not in JSON-only mode
    if [[ -n "$OUTPUT_FILE" ]] && [[ "$JSON_ONLY" != "true" ]]; then
        output_section "Summary"
        total_comments=$((issue_count + review_count))
        output_info "PR" "#$PR_NUMBER - $PR_TITLE"
        output_info "Total Comments" "$total_comments"
        output_info "Duplicate Groups" "$(echo "$duplicate_groups" | jq 'keys | length')"
        output_info "Output Format" "$(echo $OUTPUT_FORMAT | tr '[:lower:]' '[:upper:]')"
        output_info "Output File" "$OUTPUT_FILE"
    fi
    
    output_newline
    output_success "${BOLD}${GREEN}PR comment extraction complete!${NC}"
}

# Run main function
main "$@"