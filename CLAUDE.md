# Sidekick Project Context

## Overview

Sidekick is a modular command-line tool for development workflows, designed with a kubectl-like plugin architecture. It provides a unified interface for various development tasks, with automatic plugin discovery and environment-based configuration.

## Project Philosophy

1. **Modularity First**: Everything is a plugin, even core functionality
2. **Zero Configuration**: Plugins are discovered automatically from the `plugins/` folder
3. **Environment Aware**: Set defaults once via environment variables, override when needed
4. **Language Agnostic**: Plugins can be written in any executable language
5. **Test Driven**: All components should have corresponding tests

## Key Components

### Main Dispatcher (`sidekick`)
- Entry point for all commands
- Automatically discovers plugins from multiple locations
- Handles verb-noun command structure (e.g., `get pr-comments`)
- Searches in: current directory, `plugins/` folder, `~/.local/bin`, `/usr/local/bin`

### Plugin System
- Plugins follow naming convention: `sidekick-<verb>-<noun>` or `sidekick-<command>`
- Located in `plugins/` folder
- Automatically discovered - no registration needed
- Can access shared libraries from `lib/` folder

### Shared Libraries (`lib/`)
- `config.sh`: Environment variable management and validation
- `output_helpers.sh`: Consistent output formatting functions
- `gh_api.sh`: GitHub API interactions
- `url_parser.sh`: URL parsing utilities
- `duplicate_detector.sh`: Semantic duplicate detection
- `output_formatter.sh`: JSON/YAML formatting

## Environment Variables

The following environment variables configure default behavior:

- `SIDEKICK_GITHUB_ORG`: Default GitHub organization/owner
- `SIDEKICK_GITHUB_REPO`: Default GitHub repository
- `SIDEKICK_GITHUB_USER`: Default GitHub user (fallback for org)
- `SIDEKICK_OUTPUT_FORMAT`: Default output format (json/yaml)
- `SIDEKICK_VERBOSE`: Enable verbose output by default
- `SIDEKICK_JSON_ONLY`: Output JSON only by default

## Development Guidelines

### Creating New Plugins

1. Create executable script in `plugins/` folder
2. Follow naming convention: `sidekick-<verb>-<noun>`
3. Source shared libraries if needed:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
   source "$SCRIPT_DIR/lib/config.sh"
   ```
4. Handle `--help` flag
5. Use environment defaults where appropriate
6. Return appropriate exit codes

### Error Handling

- Use `set -e` in bash scripts for fail-fast behavior
- Helper functions should always return 0 to avoid premature exit
- Use `output_error_tracked` for error messages that should be included in JSON output
- Validate inputs early and fail with clear error messages

### Output Guidelines

- Support both human-readable and JSON output
- Use `output_*` functions from `output_helpers.sh` for consistency
- In JSON-only mode (`-j` flag), suppress all decorative output
- Always provide `--help` with clear usage examples

## Testing

### Manual Testing
```bash
# List all available commands
./sidekick --list

# Test a specific plugin
./sidekick get pr-comments --help
./sidekick get pr-comments https://github.com/org/repo/pull/123

# Test with environment variables
export SIDEKICK_GITHUB_ORG=facebook
export SIDEKICK_GITHUB_REPO=react
./sidekick get pr-comments 1
```

### Automated Testing
```bash
# Run all tests
./run_tests.sh

# Run specific test suite
bash tests/test_url_parsing.sh
```

## Common Tasks

### Adding GitHub API Functionality
1. Add new functions to `lib/gh_api.sh`
2. Follow existing patterns for error handling
3. Return valid JSON even on error (empty array/object)

### Adding Output Formats
1. Modify `lib/output_formatter.sh`
2. Add new format option to command-line parsing
3. Update help text and documentation

### Debugging Issues
1. Use `-v` flag for verbose output
2. Check `bash -x` for execution trace
3. Verify environment variables are set correctly
4. Check GitHub authentication with `gh auth status`

## Known Issues & Solutions

### Issue: Script exits silently
**Cause**: `set -e` with functions returning non-zero
**Solution**: Ensure helper functions return 0

### Issue: Plugin not found
**Cause**: Not executable or wrong location
**Solution**: `chmod +x plugins/sidekick-*` and ensure in `plugins/` folder

### Issue: Environment variables not working
**Cause**: Invalid format or not exported
**Solution**: Check validation regex in `lib/config.sh`

## Future Enhancements

- [ ] Add caching for API responses
- [ ] Support for GitLab and Bitbucket
- [ ] Plugin dependency management
- [ ] Interactive mode for complex operations
- [ ] Plugin marketplace/registry
- [ ] Automated plugin testing framework

## Contributing

When contributing to this project:

1. Follow existing code style and patterns
2. Add tests for new functionality
3. Update documentation (README.md and help text)
4. Ensure all existing tests pass
5. Use meaningful commit messages
6. Keep plugins focused on a single responsibility

## Project Maintainer Notes

- Always test with both `set -e` enabled and disabled
- Maintain backward compatibility when updating shared libraries
- Document environment variables in both README and help text
- Keep plugin dependencies minimal for portability
- Regular testing on macOS and Linux environments