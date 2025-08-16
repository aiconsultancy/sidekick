#!/bin/bash

# Sidekick Configuration Library
# Provides environment variable defaults and configuration management
# that can be reused across all sidekick commands

# GitHub Configuration - Environment variable defaults
DEFAULT_GITHUB_ORG="${SIDEKICK_GITHUB_ORG:-}"
DEFAULT_GITHUB_REPO="${SIDEKICK_GITHUB_REPO:-}"
DEFAULT_GITHUB_USER="${SIDEKICK_GITHUB_USER:-}"

# Additional configuration options
DEFAULT_OUTPUT_FORMAT="${SIDEKICK_OUTPUT_FORMAT:-json}"
DEFAULT_VERBOSE="${SIDEKICK_VERBOSE:-false}"
DEFAULT_JSON_ONLY="${SIDEKICK_JSON_ONLY:-false}"

# Validate GitHub organization/user name
validate_github_org() {
    local org="$1"
    if [[ -z "$org" ]]; then
        return 0  # Empty is valid (not set)
    fi
    if [[ "$org" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-])*[a-zA-Z0-9]?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate GitHub repository name
validate_github_repo() {
    local repo="$1"
    if [[ -z "$repo" ]]; then
        return 0  # Empty is valid (not set)
    fi
    if [[ "$repo" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate and load environment configuration
load_sidekick_config() {
    local silent="${1:-false}"
    
    # Validate GitHub org
    if [[ -n "$DEFAULT_GITHUB_ORG" ]]; then
        if validate_github_org "$DEFAULT_GITHUB_ORG"; then
            [[ "$silent" != "true" ]] && [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] Environment: SIDEKICK_GITHUB_ORG=$DEFAULT_GITHUB_ORG" >&2
        else
            [[ "$silent" != "true" ]] && echo "⚠ Invalid SIDEKICK_GITHUB_ORG format: $DEFAULT_GITHUB_ORG" >&2
            DEFAULT_GITHUB_ORG=""
        fi
    fi
    
    # Validate GitHub repo
    if [[ -n "$DEFAULT_GITHUB_REPO" ]]; then
        if validate_github_repo "$DEFAULT_GITHUB_REPO"; then
            [[ "$silent" != "true" ]] && [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] Environment: SIDEKICK_GITHUB_REPO=$DEFAULT_GITHUB_REPO" >&2
        else
            [[ "$silent" != "true" ]] && echo "⚠ Invalid SIDEKICK_GITHUB_REPO format: $DEFAULT_GITHUB_REPO" >&2
            DEFAULT_GITHUB_REPO=""
        fi
    fi
    
    # Validate GitHub user
    if [[ -n "$DEFAULT_GITHUB_USER" ]]; then
        if validate_github_org "$DEFAULT_GITHUB_USER"; then  # Same validation as org
            [[ "$silent" != "true" ]] && [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] Environment: SIDEKICK_GITHUB_USER=$DEFAULT_GITHUB_USER" >&2
        else
            [[ "$silent" != "true" ]] && echo "⚠ Invalid SIDEKICK_GITHUB_USER format: $DEFAULT_GITHUB_USER" >&2
            DEFAULT_GITHUB_USER=""
        fi
    fi
    
    # Load additional config
    if [[ -n "$DEFAULT_OUTPUT_FORMAT" ]]; then
        [[ "$silent" != "true" ]] && [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] Environment: SIDEKICK_OUTPUT_FORMAT=$DEFAULT_OUTPUT_FORMAT" >&2
    fi
    
    return 0
}

# Get GitHub org with fallback to user
get_github_org_or_user() {
    if [[ -n "$DEFAULT_GITHUB_ORG" ]]; then
        echo "$DEFAULT_GITHUB_ORG"
    elif [[ -n "$DEFAULT_GITHUB_USER" ]]; then
        echo "$DEFAULT_GITHUB_USER"
    else
        echo ""
    fi
}

# Check if we have minimal GitHub config
has_github_defaults() {
    local org_or_user=$(get_github_org_or_user)
    if [[ -n "$org_or_user" ]] && [[ -n "$DEFAULT_GITHUB_REPO" ]]; then
        return 0
    else
        return 1
    fi
}

# Note: These functions are available after sourcing this file
# No need to export them as they're sourced directly