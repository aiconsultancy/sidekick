# Sidekick - Extensible Development Workflow Tool

**Sidekick** is a modular command-line tool for development workflows, following a kubectl-like plugin architecture. It provides a unified interface for various development tasks with automatic plugin discovery and environment-based configuration.

## Core Features

🔌 **Plugin Architecture**
- Automatic discovery of plugins from `plugins/` folder
- Support for any executable language (bash, python, node.js, etc.)
- kubectl-like command structure (`sidekick <verb> <noun>`)
- No configuration needed - just drop in executable scripts

🔧 **Environment Configuration**
- Set defaults once, use everywhere
- Support for GitHub org, repo, and user defaults
- Override defaults with command-line arguments
- Validation of environment variables

## Available Plugins

### `sidekick get pr-comments`
**PR Comment Extraction & Analysis**
- Extracts all comments from GitHub pull requests
- Detects semantic duplicates and groups similar comments
- Fetches CI/check status and PR metadata
- Outputs structured JSON/YAML for LLM processing
- Skips closed PRs by default (use `--show-closed` to override)

### `sidekick run dedupe-issues`
**GitHub Issue Deduplicator**
- Identifies duplicate GitHub issues using semantic similarity
- Keeps only the newest issue in each duplicate group
- Safe by default with dry-run mode
- Configurable similarity threshold (0-100%)
- Adds comments and labels before closing duplicates
- Built-in rate limiting and retry logic

### `sidekick list-prs`
**List GitHub Pull Requests**
- Lists PRs from any GitHub repository
- Supports filtering by state (open, closed, all)
- Respects environment variable defaults
- Configurable limit for number of PRs shown

### `sidekick hello`
**Example Plugin**
- Simple greeting plugin demonstrating plugin basics
- Shows how to access environment configuration
- Template for creating new plugins

## Quick Start

```bash
# List available commands
./sidekick --help

# Extract PR comments
./sidekick get pr-comments https://github.com/org/repo/pull/123

# Set defaults for your project (optional)
export SIDEKICK_GITHUB_ORG=myorg
export SIDEKICK_GITHUB_REPO=myrepo

# Now you only need the PR number
./sidekick get pr-comments 456

# Preview duplicate issues (dry-run)
./sidekick run dedupe-issues myorg myrepo

# Actually close duplicate issues
./sidekick run dedupe-issues --confirm myorg myrepo

# Get help for a specific command
./sidekick get pr-comments --help
./sidekick run dedupe-issues --help
```

## Installation

### Prerequisites

1. **GitHub CLI (gh)**: Required for API access
   ```bash
   # macOS
   brew install gh
   
   # Ubuntu/Debian
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   ```

2. **jq**: JSON processor (usually pre-installed)
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   ```

3. **Authentication**: Login to GitHub CLI
   ```bash
   gh auth login
   ```

### Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd pr-comment-extractor
   ```

2. Make the scripts executable:
   ```bash
   chmod +x sidekick sidekick-*
   ```

3. (Optional) Add to PATH:
   ```bash
   sudo ln -s $(pwd)/sidekick /usr/local/bin/sidekick
   # This will make 'sidekick' available globally
   ```

## Usage

### Basic Usage

Extract comments from a PR using its URL:
```bash
./sidekick get pr-comments https://github.com/org/repo/pull/123
```

Or using separate arguments:
```bash
./sidekick get pr-comments org repo 123
```

### Issue Deduplication

Find and remove duplicate GitHub issues:

```bash
# Preview duplicates (dry-run mode - default)
./sidekick run dedupe-issues myorg myrepo

# Actually close duplicate issues
./sidekick run dedupe-issues --confirm myorg myrepo

# Use a stricter threshold (90% similarity)
./sidekick run dedupe-issues --threshold 90 myorg myrepo

# Process only first 100 issues
./sidekick run dedupe-issues --limit 100 myorg myrepo

# Enable verbose output
./sidekick run dedupe-issues -v myorg myrepo
```

**Safety Features:**
- Runs in dry-run mode by default (no issues closed)
- Requires `--confirm` flag to actually close issues
- Adds explanatory comments before closing
- Keeps the newest issue in each duplicate group
- Includes retry logic and rate limit handling

### Advanced Options

```bash
# Output to file in YAML format
./sidekick get pr-comments -f yaml -o comments.yaml https://github.com/org/repo/pull/123

# JSON-only mode for clean output (no decorative text)
./sidekick get pr-comments -j https://github.com/org/repo/pull/123

# Enable verbose output for debugging
./sidekick get pr-comments -v https://github.com/org/repo/pull/123

# Fetch comments for closed PRs (by default, closed PRs return minimal info)
./sidekick get pr-comments -s https://github.com/org/repo/pull/123

# Get the JSON schema for the output format
./sidekick get pr-comments --schema

# Combine multiple options
./sidekick get pr-comments -v -j -o output.json org repo 456
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-f, --format FORMAT` | Output format: `json` (default) or `yaml` |
| `-o, --output FILE` | Write output to file instead of stdout |
| `-j, --json-only` | Output clean JSON only, no decorative text |
| `-v, --verbose` | Enable verbose output for debugging |
| `-s, --show-closed` | Fetch comments for closed PRs (default: skip for better performance) |
| `--schema` | Output the JSON schema for the output format and exit |
| `-h, --help` | Show help message |

## Output Structure

The tool outputs structured JSON (or YAML) data. A complete JSON schema is available by running:
```bash
./sidekick get pr-comments --schema
```

### JSON Format

```json
{
  "pr_info": {
    "organization": "org",
    "repository": "repo",
    "pr_number": 123,
    "url": "https://github.com/org/repo/pull/123",
    "title": "feat: Add new feature",
    "description": "This PR adds a new feature to improve...",
    "state": "open",
    "author": "username",
    "created_at": "2024-01-01T10:00:00Z",
    "updated_at": "2024-01-01T11:00:00Z",
    "draft": false,
    "mergeable": true,
    "merged": false,
    "base_branch": "main",
    "head_branch": "feature-branch",
    "head_sha": "abc123def456",
    "checks": {
      "total": 3,
      "passed": 2,
      "failed": 1,
      "pending": 0,
      "runs": [
        {
          "name": "Build",
          "status": "completed",
          "conclusion": "success"
        },
        {
          "name": "Tests",
          "status": "completed",
          "conclusion": "failure"
        }
      ]
    },
    "valid": true
  },
  "pr_comments": [
    {
      "comment_id": "123456",
      "author": "reviewer1",
      "body": "Please fix the typo on line 10",
      "created_at": "2024-01-01T10:00:00Z",
      "updated_at": "2024-01-01T10:30:00Z",
      "url": "https://github.com/org/repo/pull/1#issuecomment-123456",
      "reactions": {},
      "status": "pending",
      "duplicate_group": null,
      "type": "issue_comment"
    }
  ],
  "metadata": {
    "statistics": {
      "total_comments": 15,
      "issue_comments": 10,
      "review_comments": 5,
      "reviews": 3,
      "duplicate_count": 4
    },
    "duplicate_groups": {
      "group_1": ["123456", "789012"],
      "group_2": ["345678", "901234"]
    },
    "extraction_timestamp": "2024-01-01T12:00:00Z"
  },
  "errors": []
}
```

### Comment Status

Comments are automatically tagged with status based on keywords:
- **resolved**: Contains `[RESOLVED]` or `[FIXED]`
- **ignored**: Contains `[IGNORE]` or `[WONTFIX]`
- **pending**: Default status

## Testing

Run the comprehensive test suite:
```bash
./run_tests.sh
```

Run individual test categories:
```bash
# Unit tests
bash tests/test_url_parsing.sh
bash tests/test_gh_api.sh
bash tests/test_duplicate_detection.sh
bash tests/test_output_formatter.sh

# Integration tests
bash tests/test_integration.sh
```

## Architecture

The project follows a modular, plugin-based architecture:

```
code-review/
├── sidekick                    # Main entry point (kubectl-like dispatcher)
├── plugins/                    # Plugin directory (auto-discovered)
│   ├── sidekick-get-pr-comments  # PR comment extraction
│   ├── sidekick-run-dedupe-issues # GitHub issue deduplicator
│   ├── sidekick-list-prs         # List GitHub PRs
│   ├── sidekick-hello            # Example plugin
│   └── lib/                      # Plugin-specific libraries
│       └── sidekick-run-dedupe-issues/
│           └── issue_deduplicator.sh  # Deduplication logic
├── lib/                        # Shared libraries
│   ├── config.sh              # Environment configuration management
│   ├── url_parser.sh          # URL parsing logic
│   ├── gh_api.sh              # GitHub API interactions
│   ├── duplicate_detector.sh  # Duplicate detection algorithms
│   ├── output_formatter.sh    # Output formatting (JSON/YAML)
│   └── output_helpers.sh      # Output utility functions
├── schema/
│   └── pr-comments-output.schema.json  # JSON schema
├── tests/
│   ├── test_*.sh              # Test files
│   └── run_tests.sh           # Test runner
├── CLAUDE.md                   # Project context for AI assistants
└── README.md                   # This file
```

### Adding New Plugins

To add a new plugin to sidekick:

1. Create an executable script in the `plugins/` folder
2. Follow the naming convention: `sidekick-<verb>-<noun>` or `sidekick-<command>`
3. Make it executable: `chmod +x plugins/sidekick-your-plugin`
4. It will be automatically discovered

#### Plugin Template:
```bash
#!/bin/bash

# Source shared libraries (optional)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/config.sh" 2>/dev/null || true

# Your plugin logic here
echo "Hello from my plugin!"

# Access environment defaults
echo "Org: ${DEFAULT_GITHUB_ORG:-not set}"
echo "Repo: ${DEFAULT_GITHUB_REPO:-not set}"
```

Plugins can be written in any language (bash, python, node.js, etc.) as long as they're executable.

### Configuration

Sidekick supports environment variables for common configuration:

| Variable | Description |
|----------|-------------|
| `SIDEKICK_GITHUB_ORG` | Default GitHub organization/owner |
| `SIDEKICK_GITHUB_REPO` | Default GitHub repository |
| `SIDEKICK_GITHUB_USER` | Default GitHub user (fallback for org) |
| `SIDEKICK_OUTPUT_FORMAT` | Default output format (json/yaml) |
| `SIDEKICK_VERBOSE` | Enable verbose output by default |
| `SIDEKICK_JSON_ONLY` | Output JSON only by default |

Set these in your shell profile for persistent configuration:
```bash
# ~/.bashrc or ~/.zshrc
export SIDEKICK_GITHUB_ORG=myorg
export SIDEKICK_GITHUB_REPO=myrepo
```

Commands can use the shared configuration by sourcing `lib/config.sh`.

## Implementation Concerns & Notes

### Development Approach
- **Test-Driven Development (TDD)**: All components were built using TDD methodology
- **Modular Design**: Each component is isolated in its own library for maintainability
- **DRY Principle**: Common functionality is extracted into reusable functions

### Known Limitations

1. **API Rate Limits**: The GitHub API has rate limits. For large PRs with many comments, you might hit these limits. Consider using authentication and implementing rate limit handling.

2. **Duplicate Detection Accuracy**: The semantic duplicate detection uses simple pattern matching and word comparison. More sophisticated NLP techniques could improve accuracy.

3. **YAML Conversion**: YAML output requires either `yq` or `python3` to be installed. The script falls back to a simple conversion if neither is available.

4. **Comment Threading**: The current implementation doesn't preserve comment threading or reply relationships.

### Future Improvements

- [ ] Add support for filtering comments by author or date range
- [ ] Implement caching to avoid redundant API calls
- [ ] Add support for GitLab and Bitbucket PRs
- [ ] Enhance duplicate detection with more sophisticated algorithms
- [ ] Add support for exporting to different task management tools
- [ ] Implement comment sentiment analysis
- [ ] Add support for processing multiple PRs in batch

### Security Considerations

1. **Authentication**: Always use `gh auth` instead of storing tokens in scripts
2. **Input Validation**: The script validates PR URLs and arguments to prevent injection
3. **File Permissions**: Output files are created with user permissions only

## Integration with LLM Workflows

The structured output from this tool is designed to be fed into Large Language Models for:
- Automated task extraction from PR comments
- Review summary generation
- Action item identification
- Code review trend analysis

Example workflow:
```bash
# Extract comments
./sidekick get pr-comments -o pr_data.json https://github.com/org/repo/pull/123

# Feed to LLM for task generation (example with a hypothetical LLM CLI)
cat pr_data.json | llm-cli "Extract actionable tasks from these PR comments"
```

## Contributing

Feel free to submit issues and enhancement requests!

For detailed development guidelines and project context, see [CLAUDE.md](CLAUDE.md).

## License

This project is provided as-is for educational and development purposes.

## Acknowledgments

Built with bash, leveraging the GitHub CLI (`gh`) for API access and `jq` for JSON processing.