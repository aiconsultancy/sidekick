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

print_header() {
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║     PR Comment Extractor & Analyzer    ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local step="$1"
    local description="$2"
    echo -e "${BOLD}${BLUE}[$step]${NC} $description"
}

print_success() {
    local message="$1"
    echo -e "${GREEN}✓${NC} $message"
}

print_error() {
    local message="$1"
    echo -e "${RED}✗${NC} $message" >&2
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠${NC} $message"
}

print_info() {
    local label="$1"
    local value="$2"
    echo -e "  ${PURPLE}$label:${NC} $value"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <PR_URL|org repo pr_number>

Extract and analyze GitHub PR comments for task generation.

OPTIONS:
    -f, --format FORMAT    Output format: json (default) or yaml
    -o, --output FILE      Write output to file instead of stdout
    -v, --verbose          Enable verbose output
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
                    print_error "Invalid format: $OUTPUT_FORMAT. Use 'json' or 'yaml'"
                    exit 1
                fi
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
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
                print_error "Unknown option: $1"
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
                    print_error "Too many arguments"
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
    print_header
    
    # Parse arguments
    parse_arguments "$@"
    
    # Check for required input
    if [[ -z "$PR_INPUT" ]]; then
        print_error "No PR URL or arguments provided"
        usage
        exit 1
    fi
    
    # Parse PR information
    print_step "1/5" "Parsing PR information"
    
    if [[ "$PR_INPUT" =~ ^https://github\.com/ ]]; then
        # URL provided
        parse_pr_url "$PR_INPUT"
        if [[ -z "$PR_ORG" ]] || [[ -z "$PR_REPO" ]] || [[ -z "$PR_NUMBER" ]]; then
            print_error "Failed to parse PR URL: $PR_INPUT"
            exit 1
        fi
        print_success "Parsed PR URL"
    else
        # Separate arguments provided
        PR_ORG="$PR_INPUT"
        PR_REPO="$REPO_INPUT"
        PR_NUMBER="$PR_NUM_INPUT"
        
        if [[ -z "$PR_ORG" ]] || [[ -z "$PR_REPO" ]] || [[ -z "$PR_NUMBER" ]]; then
            print_error "Missing required arguments: org, repo, and pr_number"
            usage
            exit 1
        fi
        print_success "Parsed PR arguments"
    fi
    
    print_info "Organization" "$PR_ORG"
    print_info "Repository" "$PR_REPO"
    print_info "PR Number" "#$PR_NUMBER"
    echo ""
    
    # Check gh CLI authentication
    print_step "2/5" "Checking GitHub authentication"
    if ! gh auth status >/dev/null 2>&1; then
        print_warning "Not authenticated with GitHub"
        echo "  Run: gh auth login"
        echo "  Or set GITHUB_TOKEN environment variable"
        exit 1
    fi
    print_success "GitHub authentication verified"
    echo ""
    
    # Fetch PR data
    print_step "3/5" "Fetching PR comments"
    echo -n "  Fetching issue comments..."
    issue_comments=$(fetch_pr_comments "$PR_ORG" "$PR_REPO" "$PR_NUMBER") &
    pid=$!
    if [[ "$VERBOSE" == "false" ]]; then
        show_spinner $pid
    fi
    wait $pid
    issue_count=$(echo "$issue_comments" | jq 'length')
    print_success "Found $issue_count issue comments"
    
    echo -n "  Fetching review comments..."
    review_comments=$(fetch_pr_review_comments "$PR_ORG" "$PR_REPO" "$PR_NUMBER") &
    pid=$!
    if [[ "$VERBOSE" == "false" ]]; then
        show_spinner $pid
    fi
    wait $pid
    review_count=$(echo "$review_comments" | jq 'length')
    print_success "Found $review_count review comments"
    
    echo -n "  Fetching reviews..."
    reviews=$(fetch_pr_reviews "$PR_ORG" "$PR_REPO" "$PR_NUMBER") &
    pid=$!
    if [[ "$VERBOSE" == "false" ]]; then
        show_spinner $pid
    fi
    wait $pid
    reviews_count=$(echo "$reviews" | jq 'length')
    print_success "Found $reviews_count reviews"
    echo ""
    
    # Combine all data
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
    print_step "4/5" "Analyzing comments for duplicates"
    
    # Combine all comments for duplicate detection
    all_comments=$(echo "$all_data" | jq '[.issue_comments[], .review_comments[]]')
    duplicate_groups=$(find_duplicate_groups "$all_comments")
    
    duplicate_count=0
    if [[ "$duplicate_groups" != "{}" ]]; then
        duplicate_count=$(echo "$duplicate_groups" | jq '[.[] | length] | add // 0')
    fi
    
    if [[ $duplicate_count -gt 0 ]]; then
        print_warning "Found $duplicate_count comments in duplicate groups"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$duplicate_groups" | jq -r 'to_entries[] | "  Group \(.key): \(.value | join(", "))"'
        fi
    else
        print_success "No duplicate comments detected"
    fi
    echo ""
    
    # Format output
    print_step "5/5" "Generating output"
    output=$(format_complete_output "$all_data" "$duplicate_groups" "$OUTPUT_FORMAT")
    
    # Write output
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$output" > "$OUTPUT_FILE"
        print_success "Output written to: $OUTPUT_FILE"
        
        # Show summary
        echo ""
        echo -e "${BOLD}${CYAN}Summary:${NC}"
        total_comments=$((issue_count + review_count))
        print_info "Total Comments" "$total_comments"
        print_info "Duplicate Groups" "$(echo "$duplicate_groups" | jq 'keys | length')"
        print_info "Output Format" "${OUTPUT_FORMAT^^}"
        print_info "Output File" "$OUTPUT_FILE"
    else
        echo ""
        echo -e "${BOLD}${CYAN}Output:${NC}"
        echo "$output"
    fi
    
    echo ""
    print_success "${BOLD}${GREEN}PR comment extraction complete!${NC}"
}

# Run main function
main "$@"