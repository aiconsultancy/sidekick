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

# Detect GitHub org and repo from current git repository
detect_git_repo() {
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
        local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Extract org/user and repo from various Git URL formats
            # https://github.com/org/repo.git
            # git@github.com:org/repo.git
            # git://github.com/org/repo.git
            local org=""
            local repo=""
            
            if [[ "$remote_url" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
                org="${BASH_REMATCH[1]}"
                repo="${BASH_REMATCH[2]}"
            elif [[ "$remote_url" =~ git@github.com:([^/]+)/([^/.]+)(\.git)?$ ]]; then
                org="${BASH_REMATCH[1]}"
                repo="${BASH_REMATCH[2]}"
            fi
            
            if [[ -n "$org" ]] && [[ -n "$repo" ]]; then
                echo "$org $repo"
                return 0
            fi
        fi
    fi
    return 1
}

# Get GitHub org with fallback to user, then to git detection
get_github_org_or_user() {
    if [[ -n "$DEFAULT_GITHUB_ORG" ]]; then
        echo "$DEFAULT_GITHUB_ORG"
    elif [[ -n "$DEFAULT_GITHUB_USER" ]]; then
        echo "$DEFAULT_GITHUB_USER"
    else
        # Try to detect from current git repo
        local git_info=$(detect_git_repo)
        if [[ -n "$git_info" ]]; then
            echo "$git_info" | cut -d' ' -f1
        else
            echo ""
        fi
    fi
}

# Get GitHub repo with fallback to git detection
get_github_repo() {
    if [[ -n "$DEFAULT_GITHUB_REPO" ]]; then
        echo "$DEFAULT_GITHUB_REPO"
    else
        # Try to detect from current git repo
        local git_info=$(detect_git_repo)
        if [[ -n "$git_info" ]]; then
            echo "$git_info" | cut -d' ' -f2
        else
            echo ""
        fi
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