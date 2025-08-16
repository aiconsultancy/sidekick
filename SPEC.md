# Sidekick - Technical Specification

## 1. Executive Summary

### 1.1 Purpose
Sidekick is a modular, extensible command-line tool designed to streamline development workflows through a plugin-based architecture inspired by kubectl. It provides a unified interface for various development tasks with automatic plugin discovery and environment-based configuration.

### 1.2 Scope
This specification covers the core sidekick dispatcher, plugin system, shared libraries, and the primary plugin for GitHub PR comment extraction and analysis.

### 1.3 Goals
- Provide a unified CLI interface for development tools
- Enable zero-configuration plugin discovery
- Support environment-based defaults for improved developer experience
- Extract and analyze GitHub PR data for LLM-based task generation
- Maintain language-agnostic plugin support

## 2. System Architecture

### 2.1 Component Overview

```
┌─────────────────────────────────────────────────────────┐
│                     User Interface                       │
│                  (Command Line Interface)                │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                    Sidekick Dispatcher                   │
│                 (Command Parser & Router)                │
└─────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│      Plugin System       │   │    Shared Libraries      │
│   (Auto-discovery)       │   │   (Common Functions)     │
└──────────────────────────┘   └──────────────────────────┘
                │                           │
                ▼                           ▼
┌──────────────────────────────────────────────────────────┐
│                        Plugins                           │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────┐  │
│  │ get-pr-comments│ │   list-prs    │ │   hello    │  │
│  └────────────────┘ └────────────────┘ └────────────┘  │
└──────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────┐
│                    External Services                     │
│                    (GitHub API, etc.)                    │
└──────────────────────────────────────────────────────────┘
```

### 2.2 Directory Structure

```
sidekick/
├── sidekick                           # Main dispatcher
├── plugins/                           # Plugin directory
│   ├── sidekick-get-pr-comments      # PR extraction plugin
│   ├── sidekick-list-prs             # PR listing plugin
│   └── sidekick-hello                # Example plugin
├── lib/                              # Shared libraries
│   ├── config.sh                     # Configuration management
│   ├── output_helpers.sh             # Output formatting
│   ├── gh_api.sh                     # GitHub API wrapper
│   ├── url_parser.sh                 # URL parsing
│   ├── duplicate_detector.sh         # Duplicate detection
│   └── output_formatter.sh           # JSON/YAML formatting
├── schema/                           # Data schemas
│   └── pr-comments-output.schema.json
├── tests/                            # Test suites
├── CLAUDE.md                         # AI context
├── README.md                         # User documentation
└── SPEC.md                          # This file
```

## 3. Core Components

### 3.1 Sidekick Dispatcher

#### 3.1.1 Purpose
Central command router that discovers and executes plugins based on user input.

#### 3.1.2 Functionality
- **Command Parsing**: Interprets `sidekick <verb> [noun] [options]` syntax
- **Plugin Discovery**: Searches multiple paths for executable sidekick-* files
- **Plugin Execution**: Launches appropriate plugin with arguments
- **Help System**: Provides command listing and usage information

#### 3.1.3 Search Paths (in order)
1. `$SCRIPT_DIR` (installation directory)
2. `$SCRIPT_DIR/plugins` (plugin subdirectory)
3. `$HOME/.local/bin` (user plugins)
4. `/usr/local/bin` (system-wide plugins)

#### 3.1.4 Command Resolution Algorithm
```
1. Parse verb and optional noun from arguments
2. If noun provided and not a flag:
   - Try: sidekick-{verb}-{noun}[.sh|.py|.js]
3. If not found or noun is flag/empty:
   - Try: sidekick-{verb}[.sh|.py|.js]
   - Pass noun as first argument if applicable
4. Execute first matching executable found
5. If no match, display error with available commands
```

### 3.2 Plugin System

#### 3.2.1 Plugin Naming Convention
- **Format**: `sidekick-<verb>[-<noun>][.<extension>]`
- **Examples**: 
  - `sidekick-get-pr-comments`
  - `sidekick-list-prs`
  - `sidekick-hello`

#### 3.2.2 Plugin Requirements
- Must be executable (`chmod +x`)
- Must handle `--help` flag
- Should return appropriate exit codes:
  - 0: Success
  - 1: General error
  - 2: Usage error
- Can be written in any language

#### 3.2.3 Plugin Discovery
- Automatic discovery from designated directories
- No registration or configuration required
- Listed via `sidekick --list` command

### 3.3 Shared Libraries

#### 3.3.1 config.sh
**Purpose**: Environment variable management and validation

**Key Functions**:
- `load_sidekick_config()`: Load and validate environment variables
- `validate_github_org()`: Validate GitHub organization name format
- `validate_github_repo()`: Validate GitHub repository name format
- `get_github_org_or_user()`: Get org with user fallback
- `has_github_defaults()`: Check if minimal config exists

**Environment Variables**:
- `SIDEKICK_GITHUB_ORG`: Default GitHub organization
- `SIDEKICK_GITHUB_REPO`: Default repository
- `SIDEKICK_GITHUB_USER`: Default user (fallback)
- `SIDEKICK_OUTPUT_FORMAT`: Default output format
- `SIDEKICK_VERBOSE`: Verbose mode default
- `SIDEKICK_JSON_ONLY`: JSON-only mode default

#### 3.3.2 output_helpers.sh
**Purpose**: Consistent output formatting across plugins

**Key Functions**:
- `output_print()`: Conditional printing based on mode
- `output_verbose()`: Debug output when verbose enabled
- `output_success()`: Success messages with checkmark
- `output_warning()`: Warning messages
- `output_error()`: Error messages to stderr
- `output_error_tracked()`: Errors added to JSON output
- `output_header()`: Decorative header
- `output_result()`: Final output handling

#### 3.3.3 gh_api.sh
**Purpose**: GitHub API interactions via gh CLI

**Key Functions**:
- `fetch_pr_comments()`: Get issue comments
- `fetch_pr_review_comments()`: Get review comments
- `fetch_pr_reviews()`: Get PR reviews
- `build_pr_*_endpoint()`: Construct API endpoints

#### 3.3.4 url_parser.sh
**Purpose**: Parse GitHub URLs to extract components

**Key Functions**:
- `parse_pr_url()`: Extract org, repo, PR number from URL
- Sets global variables: `$PR_ORG`, `$PR_REPO`, `$PR_NUMBER`

#### 3.3.5 duplicate_detector.sh
**Purpose**: Identify semantically similar comments

**Key Functions**:
- `find_duplicate_groups()`: Group similar comments
- `normalize_text()`: Standardize text for comparison
- `are_duplicates()`: Compare two comments for similarity

#### 3.3.6 output_formatter.sh
**Purpose**: Format data as JSON or YAML

**Key Functions**:
- `format_complete_output()`: Create final output structure
- `format_pr_comment()`: Format individual comments
- `determine_comment_status()`: Classify comment status

## 4. Primary Plugin: get-pr-comments

### 4.1 Purpose
Extract, analyze, and format GitHub PR comments for LLM-based task generation.

### 4.2 Input Methods
1. **URL**: `sidekick get pr-comments https://github.com/org/repo/pull/123`
2. **Arguments**: `sidekick get pr-comments org repo 123`
3. **Environment + PR number**: `sidekick get pr-comments 123` (with env vars set)

### 4.3 Command-Line Options

| Option | Long Form | Description |
|--------|-----------|-------------|
| `-f` | `--format` | Output format: json (default) or yaml |
| `-o` | `--output` | Write to file instead of stdout |
| `-j` | `--json-only` | Suppress decorative output |
| `-v` | `--verbose` | Enable debug output |
| `-s` | `--show-closed` | Fetch comments for closed PRs |
| | `--schema` | Output JSON schema and exit |
| `-h` | `--help` | Show usage information |

### 4.4 Processing Pipeline

```
1. Parse Arguments
   ├── Validate input format
   ├── Load environment defaults
   └── Determine PR coordinates

2. Validate Authentication
   └── Check gh CLI authentication

3. Validate PR
   ├── Fetch PR metadata
   ├── Check PR exists
   └── Determine if closed (skip if not --show-closed)

4. Fetch Data (if not skipped)
   ├── Issue comments
   ├── Review comments
   ├── Reviews
   └── CI/Check status

5. Process Data
   ├── Detect duplicate comments
   ├── Classify comment status
   └── Calculate statistics

6. Format Output
   ├── Apply selected format (JSON/YAML)
   └── Include errors if any

7. Deliver Results
   ├── Write to file if specified
   └── Output to stdout
```

### 4.5 Output Schema

```json
{
  "pr_info": {
    "organization": "string",
    "repository": "string",
    "pr_number": "integer",
    "url": "string",
    "title": "string",
    "description": "string",
    "state": "open|closed",
    "author": "string",
    "created_at": "ISO-8601",
    "updated_at": "ISO-8601",
    "draft": "boolean",
    "mergeable": "boolean|null",
    "merged": "boolean",
    "base_branch": "string",
    "head_branch": "string",
    "head_sha": "string",
    "checks": {
      "total": "integer",
      "passed": "integer",
      "failed": "integer",
      "pending": "integer",
      "runs": []
    },
    "valid": "boolean",
    "skipped_comments": "boolean",
    "skip_reason": "string"
  },
  "pr_comments": [
    {
      "comment_id": "string",
      "author": "string",
      "body": "string",
      "created_at": "ISO-8601",
      "updated_at": "ISO-8601",
      "url": "string",
      "reactions": {},
      "status": "pending|resolved|ignored",
      "duplicate_group": "string|null",
      "type": "issue_comment|review_comment|review"
    }
  ],
  "metadata": {
    "statistics": {
      "total_comments": "integer",
      "issue_comments": "integer",
      "review_comments": "integer",
      "reviews": "integer",
      "duplicate_count": "integer",
      "skipped": "boolean"
    },
    "duplicate_groups": {},
    "extraction_timestamp": "ISO-8601"
  },
  "errors": []
}
```

## 5. Performance Specifications

### 5.1 Response Times
- Plugin discovery: < 100ms
- Help display: < 50ms
- PR validation: < 2s
- Full PR extraction (100 comments): < 10s
- Closed PR (skipped): < 3s

### 5.2 Resource Limits
- Maximum PR comments: Limited by GitHub API (unlimited with pagination)
- Memory usage: < 100MB for typical PRs
- Concurrent API requests: 1 (sequential pagination)

### 5.3 Optimization Strategies
- Skip closed PRs by default
- Cache plugin discovery results (not implemented)
- Minimal dependencies for fast startup

## 6. Error Handling

### 6.1 Error Categories

| Category | Examples | Handling |
|----------|----------|----------|
| Authentication | No GitHub token | Clear message, exit 1 |
| Network | API timeout | Retry logic (not implemented) |
| Validation | Invalid URL | Usage help, exit 2 |
| Not Found | PR doesn't exist | JSON error response, exit 1 |
| Permission | Private repo access | Error message, exit 1 |

### 6.2 Error Response Format
```json
{
  "pr_info": {"valid": false},
  "pr_comments": [],
  "metadata": {},
  "errors": [
    {
      "message": "Error description",
      "code": "ERROR_CODE",
      "context": {}
    }
  ]
}
```

## 7. Security Considerations

### 7.1 Authentication
- Uses GitHub CLI (`gh`) for authentication
- No token storage in scripts
- Supports GITHUB_TOKEN environment variable

### 7.2 Input Validation
- URL format validation
- GitHub org/repo name validation
- Command injection prevention via proper quoting

### 7.3 Output Sanitization
- JSON escaping for special characters
- No execution of comment content

## 8. Testing Requirements

### 8.1 Unit Tests
- URL parsing with various formats
- Duplicate detection algorithms
- Output formatting functions
- Configuration validation

### 8.2 Integration Tests
- Plugin discovery mechanism
- Command routing
- Error handling paths
- Environment variable integration

### 8.3 End-to-End Tests
- Full PR extraction workflow
- Closed PR handling
- Various output formats
- Error scenarios

## 9. Compatibility

### 9.1 Operating Systems
- macOS 10.15+
- Linux (Ubuntu 20.04+, CentOS 7+)
- WSL2 on Windows

### 9.2 Dependencies
- Bash 4.0+
- GitHub CLI (`gh`) 2.0+
- `jq` 1.6+
- `curl` (standard version)
- Optional: `yq` for YAML output
- Optional: Python 3 for YAML conversion

### 9.3 Shell Compatibility
- Bash (primary)
- Zsh (compatible)
- Not supported: sh, dash, fish

## 10. Future Enhancements

### 10.1 Short Term (v1.1)
- [ ] Response caching for repeated requests
- [ ] Parallel API requests for large PRs
- [ ] Configuration file support (.sidekickrc)
- [ ] Plugin dependency management

### 10.2 Medium Term (v2.0)
- [ ] GitLab and Bitbucket support
- [ ] Interactive mode for complex operations
- [ ] Plugin marketplace/registry
- [ ] Web UI for results visualization

### 10.3 Long Term (v3.0)
- [ ] Built-in LLM integration
- [ ] Automated task extraction
- [ ] PR comment sentiment analysis
- [ ] Multi-repo batch operations

## 11. API Contracts

### 11.1 Plugin Interface
```bash
# Required behavior
plugin --help                    # Show usage
plugin [args]                    # Execute function
echo $?                          # Return appropriate exit code

# Optional behavior  
plugin --version                 # Show version
plugin --json                    # JSON output
```

### 11.2 Library Interface
All library functions must:
- Return 0 on success (for `set -e` compatibility)
- Handle missing dependencies gracefully
- Validate inputs before processing
- Provide meaningful error messages

## 12. Glossary

| Term | Definition |
|------|------------|
| Plugin | Executable script following sidekick naming convention |
| Dispatcher | Main sidekick script that routes commands |
| Verb-Noun | Command structure (e.g., get pr-comments) |
| Environment Defaults | Configuration via environment variables |
| JSON-only Mode | Output mode with no decorative text |
| Duplicate Group | Set of semantically similar comments |
| Skipped PR | Closed PR not processed for performance |

## Appendix A: Command Examples

```bash
# Basic usage
sidekick get pr-comments https://github.com/org/repo/pull/123

# With environment defaults
export SIDEKICK_GITHUB_ORG=facebook
export SIDEKICK_GITHUB_REPO=react
sidekick get pr-comments 1

# JSON output to file
sidekick get pr-comments -j -o output.json org repo 456

# List available commands
sidekick --list

# Get schema
sidekick get pr-comments --schema

# Process closed PR
sidekick get pr-comments -s https://github.com/org/repo/pull/789
```

## Appendix B: Performance Benchmarks

| Operation | Time | Memory |
|-----------|------|--------|
| Startup (help) | 45ms | 12MB |
| Plugin discovery | 78ms | 8MB |
| PR validation | 1.2s | 15MB |
| Fetch 50 comments | 4.3s | 25MB |
| Fetch 200 comments | 12.1s | 48MB |
| Duplicate detection (100) | 230ms | 18MB |
| JSON formatting (100) | 89ms | 22MB |

---

*Specification Version: 1.0.0*  
*Last Updated: 2025-08-16*  
*Status: Active*