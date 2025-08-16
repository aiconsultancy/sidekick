# PR Comment Extractor & Analyzer

A powerful bash script that extracts and analyzes GitHub Pull Request comments to generate structured data for task management and automated PR review workflows.

## Features

✨ **Smart Comment Extraction**
- Fetches issue comments, review comments, and reviews from GitHub PRs
- Supports both public and private repositories (with authentication)
- Handles pagination automatically for large PRs
- Tracks comment status (resolved/ignored/pending) via keywords

🔍 **Semantic Duplicate Detection**
- Identifies semantically similar comments (e.g., "LGTM" and "Looks good to me")
- Groups duplicate comments to reduce noise
- Smart detection of approval patterns and emojis
- Reduces redundancy in task generation

📊 **Rich PR Metadata**
- Complete PR information: title, description, state, author, branches
- CI/Check status with detailed run information
- Mergeable status, draft state, timestamps
- Head commit SHA for precise status tracking

📈 **CI/Check Status Tracking**
- Fetches GitHub Actions and check runs status
- Shows pass/fail/pending counts
- Individual check run details with conclusions
- Real-time status for each CI workflow

🎨 **Beautiful CLI Interface**
- Progress indicators with spinners
- Color-coded output for better readability
- JSON-only mode for clean programmatic output
- Verbose mode for debugging

📁 **Flexible Output Options**
- JSON output for programmatic processing
- YAML output for human readability
- File output with summary display
- Comprehensive error tracking and reporting

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

2. Make the script executable:
   ```bash
   chmod +x pr-comment-extractor.sh
   ```

3. (Optional) Add to PATH:
   ```bash
   sudo ln -s $(pwd)/pr-comment-extractor.sh /usr/local/bin/pr-comment-extractor
   ```

## Usage

### Basic Usage

Extract comments from a PR using its URL:
```bash
./pr-comment-extractor.sh https://github.com/org/repo/pull/123
```

Or using separate arguments:
```bash
./pr-comment-extractor.sh org repo 123
```

### Advanced Options

```bash
# Output to file in YAML format
./pr-comment-extractor.sh -f yaml -o comments.yaml https://github.com/org/repo/pull/123

# JSON-only mode for clean output (no decorative text)
./pr-comment-extractor.sh -j https://github.com/org/repo/pull/123

# Enable verbose output for debugging
./pr-comment-extractor.sh -v https://github.com/org/repo/pull/123

# Combine multiple options
./pr-comment-extractor.sh -v -j -o output.json org repo 456
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-f, --format FORMAT` | Output format: `json` (default) or `yaml` |
| `-o, --output FILE` | Write output to file instead of stdout |
| `-j, --json-only` | Output clean JSON only, no decorative text |
| `-v, --verbose` | Enable verbose output for debugging |
| `-h, --help` | Show help message |

## Output Structure

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

The project follows a modular architecture with separate libraries for each functionality:

```
pr-comment-extractor/
├── pr-comment-extractor.sh    # Main script
├── lib/
│   ├── url_parser.sh          # URL parsing logic
│   ├── gh_api.sh              # GitHub API interactions
│   ├── duplicate_detector.sh  # Duplicate detection algorithms
│   └── output_formatter.sh    # Output formatting (JSON/YAML)
├── tests/
│   ├── test_*.sh              # Test files
│   └── run_tests.sh           # Test runner
└── README.md
```

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
./pr-comment-extractor.sh -o pr_data.json https://github.com/org/repo/pull/123

# Feed to LLM for task generation (example with a hypothetical LLM CLI)
cat pr_data.json | llm-cli "Extract actionable tasks from these PR comments"
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is provided as-is for educational and development purposes.

## Acknowledgments

Built with bash, leveraging the GitHub CLI (`gh`) for API access and `jq` for JSON processing.