#!/bin/bash

# Sidekick Installer Script
# This script can be run with:
#   curl -sSL https://github.com/OWNER/REPO/releases/download/VERSION/install.sh | bash
# Or downloaded and run locally:
#   ./install.sh

set -e

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/usr/local}"
REPO_OWNER="${REPO_OWNER:-}"
REPO_NAME="${REPO_NAME:-}"
VERSION="${VERSION:-latest}"

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
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        if command -v git &> /dev/null && git remote get-url origin &> /dev/null; then
            local remote_url=$(git remote get-url origin)
            REPO_OWNER=$(echo "$remote_url" | sed -E 's/.*[:/]([^/]+)\/[^/]+\.git/\1/')
            REPO_NAME=$(echo "$remote_url" | sed -E 's/.*\/([^/]+)\.git/\1/')
            print_info "Detected repository: $REPO_OWNER/$REPO_NAME"
        else
            print_error "Could not detect repository. Please set REPO_OWNER and REPO_NAME environment variables."
            print_info "Example: REPO_OWNER=myorg REPO_NAME=sidekick ./install.sh"
            exit 1
        fi
    fi
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
    
    # Check if we need sudo
    if [ -w "$INSTALL_DIR" ]; then
        SUDO=""
    else
        SUDO="sudo"
        print_warning "Installation requires sudo access"
    fi
    
    # Create installation directories
    $SUDO mkdir -p "$INSTALL_DIR/share/sidekick"
    $SUDO mkdir -p "$INSTALL_DIR/bin"
    
    # Copy files
    $SUDO cp -r "$extract_dir"/{sidekick,plugins,lib} "$INSTALL_DIR/share/sidekick/" 2>/dev/null || {
        print_error "Failed to copy sidekick files"
        exit 1
    }
    
    # Copy schema if it exists
    if [ -d "$extract_dir/schema" ]; then
        $SUDO cp -r "$extract_dir/schema" "$INSTALL_DIR/share/sidekick/"
    fi
    
    # Make scripts executable
    $SUDO chmod +x "$INSTALL_DIR/share/sidekick/sidekick"
    $SUDO find "$INSTALL_DIR/share/sidekick/plugins" -type f -exec chmod +x {} \;
    
    # Create symlink
    $SUDO ln -sf "$INSTALL_DIR/share/sidekick/sidekick" "$INSTALL_DIR/bin/sidekick"
    
    # Store version
    echo "$version" | $SUDO tee "$INSTALL_DIR/share/sidekick/VERSION" > /dev/null
    
    print_success "Sidekick $version installed successfully!"
}

# Verify installation
verify_installation() {
    if command -v sidekick &> /dev/null; then
        print_success "Sidekick is available in PATH"
        print_info "Run 'sidekick --help' to get started"
        return 0
    elif [ -x "$INSTALL_DIR/bin/sidekick" ]; then
        print_warning "Sidekick installed but not in PATH"
        print_info "Add $INSTALL_DIR/bin to your PATH:"
        print_info "  export PATH=\"$INSTALL_DIR/bin:\$PATH\""
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
    echo "1. Ensure GitHub CLI is authenticated: gh auth login"
    echo "2. Try it out: sidekick --help"
    echo "3. Extract PR comments: sidekick get pr-comments https://github.com/org/repo/pull/123"
    echo
    echo "For more information, visit: https://github.com/$REPO_OWNER/$REPO_NAME"
}

# Run main function
main "$@"