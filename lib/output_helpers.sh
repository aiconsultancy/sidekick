#!/bin/bash

# Output helper functions that respect JSON_ONLY and VERBOSE modes

# Check if output should be shown
should_output() {
    if [[ "$JSON_ONLY" != "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if verbose output should be shown
should_output_verbose() {
    if [[ "$VERBOSE" == "true" ]] && [[ "$JSON_ONLY" != "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Print formatted output
output_print() {
    local message="$1"
    if [[ "$JSON_ONLY" != "true" ]]; then
        echo -e "$message"
    fi
}

# Print raw output
output_raw() {
    local message="$1"
    if [[ "$JSON_ONLY" != "true" ]]; then
        echo "$message"
    fi
}

# Print to stderr
output_error() {
    local message="$1"
    if [[ "$JSON_ONLY" != "true" ]]; then
        echo -e "$message" >&2
    fi
}

# Print header
output_header() {
    output_print "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}"
    output_print "${BOLD}${CYAN}║     PR Comment Extractor & Analyzer    ║${NC}"
    output_print "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}"
    output_print ""
}

# Print step
output_step() {
    local step="$1"
    local description="$2"
    output_print "${BOLD}${BLUE}[$step]${NC} $description"
}

# Print success
output_success() {
    local message="$1"
    output_print "${GREEN}✓${NC} $message"
}

# Print error and add to error list
output_error_tracked() {
    local message="$1"
    output_error "${RED}✗${NC} $message"
    
    # Add to errors list
    local error_obj=$(jq -n --arg msg "$message" --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{message: $msg, timestamp: $timestamp}')
    ERRORS_LIST=$(echo "$ERRORS_LIST" | jq --argjson err "$error_obj" '. + [$err]')
}

# Print warning
output_warning() {
    local message="$1"
    output_print "${YELLOW}⚠${NC} $message"
}

# Print info
output_info() {
    local label="$1"
    local value="$2"
    output_print "  ${PURPLE}$label:${NC} $value"
}

# Print verbose/debug
output_verbose() {
    local message="$1"
    if [[ "$VERBOSE" == "true" ]] && [[ "$JSON_ONLY" != "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $message" >&2
    fi
    return 0
}

# Print section header
output_section() {
    local title="$1"
    output_print ""
    output_print "${BOLD}${CYAN}$title:${NC}"
}

# Conditional newline
output_newline() {
    output_print ""
}

# Output final result
output_result() {
    local output="$1"
    local output_file="$2"
    
    if [[ -n "$output_file" ]]; then
        echo "$output" > "$output_file"
        output_success "Output written to: $output_file"
        output_verbose "Output saved to file: $output_file"
    else
        if [[ "$JSON_ONLY" == "true" ]]; then
            # JSON-only mode: just output the JSON
            echo "$output"
        else
            # Regular mode: show decorated output
            output_section "Output"
            echo "$output"
        fi
    fi
}

# Progress indicator
output_progress() {
    local message="$1"
    if [[ "$JSON_ONLY" != "true" ]]; then
        echo -n "$message"
    fi
}