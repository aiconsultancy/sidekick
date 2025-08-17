#!/usr/bin/env bash

# Extract module ID from PR description using AI
extract_module_from_description() {
    local description="$1"
    local ai_agent="${2:-claude}"
    local model="${3:-claude-3-5-haiku-20241022}"
    
    local prompt="Extract the Module, Submodule and Task numbers from the text below and return ONLY the formatted string like: M{module}.{submodule}.{task} (e.g., M2.2.13). If you cannot find all three numbers, return nothing. Do not include any other text in your response.

---
$description"
    
    local result=""
    
    case "$ai_agent" in
        claude)
            result=$(extract_with_claude "$prompt" "$model")
            ;;
        opencode)
            result=$(extract_with_opencode "$prompt")
            ;;
        *)
            warning "Unknown AI agent: $ai_agent, falling back to claude"
            result=$(extract_with_claude "$prompt" "$model")
            ;;
    esac
    
    # Validate the result matches expected format
    if [[ "$result" =~ ^M[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$result"
    else
        # Try to extract if AI returned extra text
        if [[ "$result" =~ M([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
            echo "M${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        fi
    fi
}

# Extract using Claude
extract_with_claude() {
    local prompt="$1"
    local model="${2:-claude-3-5-haiku-20241022}"
    
    # Check if claude command exists
    if ! command -v claude &> /dev/null; then
        warning "Claude CLI not found, skipping AI extraction"
        return
    fi
    
    # Use claude with the specified model
    local result=$(echo "$prompt" | claude -p "$model" 2>/dev/null || echo "")
    
    # Clean up the result
    result=$(echo "$result" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$result"
}

# Extract using OpenCode
extract_with_opencode() {
    local prompt="$1"
    
    # Check if opencode command exists
    if ! command -v opencode &> /dev/null; then
        warning "OpenCode CLI not found, skipping AI extraction"
        return
    fi
    
    # Use opencode in non-interactive mode
    local result=$(opencode run "$prompt" 2>/dev/null || echo "")
    
    # Clean up the result
    result=$(echo "$result" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$result"
}

# Extract using generic AI command
extract_with_custom() {
    local prompt="$1"
    local command="$2"
    
    # Check if command exists
    if ! command -v "$command" &> /dev/null; then
        warning "Command '$command' not found, skipping AI extraction"
        return
    fi
    
    # Execute the custom command with the prompt
    local result=$(echo "$prompt" | "$command" 2>/dev/null || echo "")
    
    # Clean up the result
    result=$(echo "$result" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$result"
}

# Validate module ID format
validate_module_id() {
    local module_id="$1"
    
    if [[ "$module_id" =~ ^M[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Parse module components from ID
parse_module_id() {
    local module_id="$1"
    
    if [[ "$module_id" =~ ^M([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "Module: ${BASH_REMATCH[1]}"
        echo "Submodule: ${BASH_REMATCH[2]}"
        echo "Task: ${BASH_REMATCH[3]}"
    else
        return 1
    fi
}