#!/bin/bash

# Sidekick Installer Script
# This script can be run with:
#   curl -sSL https://github.com/OWNER/REPO/releases/download/VERSION/install.sh | bash
# Or downloaded and run locally:
#   ./install.sh

set -e

# Configuration
# Default to ~/.local if it exists or can be created, otherwise use ~/.sidekick
if [[ -d "$HOME/.local" ]] || mkdir -p "$HOME/.local" 2>/dev/null; then
    DEFAULT_INSTALL_DIR="$HOME/.local"
else
    DEFAULT_INSTALL_DIR="$HOME/.sidekick"
fi
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
REPO_OWNER="${REPO_OWNER:-}"
REPO_NAME="${REPO_NAME:-}"
VERSION="${VERSION:-latest}"
UPDATE_SHELL_RC="${UPDATE_SHELL_RC:-ask}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Detect shell
detect_shell() {
    if [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    else
        # Fallback to checking SHELL variable
        case "$SHELL" in
            */bash) echo "bash" ;;
            */zsh) echo "zsh" ;;
            *) echo "unknown" ;;
        esac
    fi
}

# Get shell RC file
get_shell_rc() {
    local shell_type="$1"
    case "$shell_type" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                echo "$HOME/.zshrc"
            else
                echo "$HOME/.zshrc"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in curl tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check for GitHub CLI (required for sidekick)
    if ! command -v gh &> /dev/null; then
        print_warning "GitHub CLI (gh) is not installed. Sidekick requires it for GitHub operations."
        print_info "Install it from: https://cli.github.com/"
    fi
    
    # Check for jq (required for sidekick)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Sidekick requires it for JSON processing."
        print_info "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Auto-detect GitHub repository from git remote if not provided
detect_repo() {
    # Default to the sidekick repository
    if [ -z "$REPO_OWNER" ]; then
        REPO_OWNER="aiconsultancy"
    fi
    if [ -z "$REPO_NAME" ]; then
        REPO_NAME="sidekick"
    fi
    
    # Only try to detect from git if we're in a git repo and both are still empty
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if command -v git &> /dev/null && git remote get-url origin &> /dev/null; then
            local remote_url=$(git remote get-url origin)
            REPO_OWNER=$(echo "$remote_url" | sed -E 's/.*[:/]([^/]+)\/[^/]+\.git/\1/')
            REPO_NAME=$(echo "$remote_url" | sed -E 's/.*\/([^/]+)\.git/\1/')
            print_info "Detected repository: $REPO_OWNER/$REPO_NAME"
        fi
    fi
    
    print_info "Installing from repository: $REPO_OWNER/$REPO_NAME"
}

# Get the latest release version
get_latest_version() {
    local api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    local version=$(curl -s "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$version" ]; then
        print_error "Could not fetch latest version from GitHub"
        exit 1
    fi
    
    echo "$version"
}

# Download and install Sidekick
install_sidekick() {
    local version="$1"
    local os=$(detect_os)
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    print_info "Downloading Sidekick $version..."
    
    # Construct download URL
    local download_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/sidekick-$version.tar.gz"
    
    # Download tarball
    if ! curl -L -o "$temp_dir/sidekick.tar.gz" "$download_url" 2>/dev/null; then
        print_error "Failed to download Sidekick from $download_url"
        exit 1
    fi
    
    # Extract tarball
    print_info "Extracting files..."
    if ! tar -xzf "$temp_dir/sidekick.tar.gz" -C "$temp_dir"; then
        print_error "Failed to extract tarball"
        exit 1
    fi
    
    # Find extracted directory
    local extract_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "sidekick-*" | head -1)
    if [ -z "$extract_dir" ]; then
        print_error "Could not find extracted directory"
        exit 1
    fi
    
    # Install files
    print_info "Installing Sidekick to $INSTALL_DIR..."
    
    # No sudo needed for user installation
    # Create installation directories
    mkdir -p "$INSTALL_DIR/share/sidekick"
    mkdir -p "$INSTALL_DIR/bin"
    
    # Copy files
    cp -r "$extract_dir"/{sidekick,plugins,lib} "$INSTALL_DIR/share/sidekick/" 2>/dev/null || {
        print_error "Failed to copy sidekick files"
        exit 1
    }
    
    # Copy schema if it exists
    if [ -d "$extract_dir/schema" ]; then
        cp -r "$extract_dir/schema" "$INSTALL_DIR/share/sidekick/"
    fi
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/share/sidekick/sidekick"
    find "$INSTALL_DIR/share/sidekick/plugins" -type f -exec chmod +x {} \;
    
    # Create symlink
    ln -sf "$INSTALL_DIR/share/sidekick/sidekick" "$INSTALL_DIR/bin/sidekick"
    
    # Store version
    echo "$version" > "$INSTALL_DIR/share/sidekick/VERSION"
    
    print_success "Sidekick $version installed successfully!"
}

# Check and update PATH
check_and_update_path() {
    local bin_dir="$INSTALL_DIR/bin"
    local shell_type=$(detect_shell)
    local shell_rc=$(get_shell_rc "$shell_type")
    
    # Check if bin directory is in PATH
    if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
        print_success "$bin_dir is already in PATH"
        return 0
    fi
    
    print_warning "$bin_dir is not in your PATH"
    
    # If we can't detect the shell or RC file, just show manual instructions
    if [ -z "$shell_rc" ] || [ "$shell_type" = "unknown" ]; then
        print_info "Add this line to your shell configuration file:"
        print_info "  export PATH=\"$bin_dir:\$PATH\""
        return 1
    fi
    
    # Ask user if they want to update their shell RC file
    if [ "$UPDATE_SHELL_RC" = "ask" ]; then
        echo
        read -p "Would you like to add $bin_dir to your PATH in $shell_rc? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            UPDATE_SHELL_RC="yes"
        else
            UPDATE_SHELL_RC="no"
        fi
    fi
    
    if [ "$UPDATE_SHELL_RC" = "yes" ]; then
        # Check if PATH export already exists for our directory
        if grep -q "$bin_dir" "$shell_rc" 2>/dev/null; then
            print_info "PATH configuration already exists in $shell_rc"
        else
            # Add PATH export to shell RC file
            {
                echo ""
                echo "# Added by Sidekick installer on $(date)"
                echo "export PATH=\"$bin_dir:\$PATH\""
            } >> "$shell_rc"
            
            print_success "Added PATH configuration to $shell_rc"
            print_info "Run this command to update your current session:"
            print_info "  export PATH=\"$bin_dir:\$PATH\""
            print_info "Or start a new terminal session"
        fi
    else
        print_info "To add sidekick to your PATH, add this line to $shell_rc:"
        print_info "  export PATH=\"$bin_dir:\$PATH\""
    fi
    
    # Export for current session if not in PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        export PATH="$bin_dir:$PATH"
    fi
}

# Verify installation
verify_installation() {
    if [ -x "$INSTALL_DIR/bin/sidekick" ]; then
        print_success "Sidekick installed successfully!"
        check_and_update_path
        return 0
    else
        print_error "Installation verification failed"
        return 1
    fi
}

# Main installation flow
main() {
    echo "======================================"
    echo "     Sidekick Installation Script     "
    echo "======================================"
    echo
    
    # Check dependencies
    print_info "Checking dependencies..."
    check_dependencies
    print_success "Dependencies satisfied"
    
    # Detect repository if needed
    detect_repo
    
    # Get version to install
    if [ "$VERSION" == "latest" ]; then
        print_info "Fetching latest version..."
        VERSION=$(get_latest_version)
    fi
    print_info "Installing version: $VERSION"
    
    # Install Sidekick
    install_sidekick "$VERSION"
    
    # Verify installation
    echo
    verify_installation
    
    echo
    echo "======================================"
    echo "     Installation Complete!           "
    echo "======================================"
    echo
    
    # Show next steps
    echo "Next steps:"
    if [[ ":$PATH:" != *":$INSTALL_DIR/bin:"* ]]; then
        echo "1. Add sidekick to your PATH (see instructions above)"
        echo "2. Ensure GitHub CLI is authenticated: gh auth login"
        echo "3. Try it out: sidekick --help"
    else
        echo "1. Ensure GitHub CLI is authenticated: gh auth login"
        echo "2. Try it out: sidekick --help"
        echo "3. Extract PR comments: sidekick get pr-comments https://github.com/org/repo/pull/123"
    fi
    echo
    echo "For more information, visit: https://github.com/$REPO_OWNER/$REPO_NAME"
}

# Run main function
main "$@"