# GitHub Issue Deduplicator Plugin - Implementation Tasks

## Task List

### Setup & Infrastructure (Size: S)
- [x] Create spec module structure
- [ ] Create plugin file: `plugins/sidekick-dedupe-issues`
- [ ] Set up basic command structure with help text
- [ ] Add argument parsing for options

### Core Functionality (Size: L)
- [ ] Implement issue fetcher using gh CLI
- [ ] Create title normalization function
- [ ] Implement Levenshtein distance calculator
- [ ] Implement token overlap calculator
- [ ] Create similarity scoring function
- [ ] Build duplicate group detection algorithm
- [ ] Implement group processing logic

### Output & Reporting (Size: M)
- [ ] Create dry-run output formatter
- [ ] Implement progress indicators
- [ ] Add summary statistics display
- [ ] Create verbose mode output

### Action Execution (Size: M)
- [ ] Implement issue closing function
- [ ] Add comment creation with references
- [ ] Implement duplicate label addition
- [ ] Create action rollback log

### Configuration & Environment (Size: S)
- [ ] Add environment variable support
- [ ] Implement threshold configuration
- [ ] Add default values and validation

### Error Handling (Size: S)
- [ ] Add API rate limit handling
- [ ] Implement network error retries
- [ ] Add input validation
- [ ] Create error messages

### Testing (Size: M)
- [ ] Write unit tests for similarity functions
- [ ] Create integration test with mock data
- [ ] Add edge case testing
- [ ] Perform manual testing with real repository

### Documentation (Size: S)
- [ ] Update README with plugin documentation
- [ ] Add usage examples
- [ ] Create troubleshooting guide
- [ ] Document similarity algorithm

## Task Details

### Task 1: Create plugin file
**File**: `plugins/sidekick-dedupe-issues`
**Requirements**: US-01, US-04
**Description**: Create the main plugin script with basic structure

### Task 2: Implement issue fetcher
**Function**: `fetch_all_issues()`
**Requirements**: US-01
**Description**: Fetch all open issues using gh CLI with proper JSON parsing

### Task 3: Create title normalization
**Function**: `normalize_title()`
**Requirements**: US-01, US-05
**Description**: Normalize titles for comparison (lowercase, remove special chars)

### Task 4: Implement Levenshtein distance
**Function**: `calculate_levenshtein()`
**Requirements**: US-01, US-05
**Description**: Calculate edit distance between two strings

### Task 5: Implement token overlap
**Function**: `calculate_token_overlap()`
**Requirements**: US-01, US-05
**Description**: Calculate Jaccard similarity for word tokens

### Task 6: Create similarity scoring
**Function**: `similarity_score()`
**Requirements**: US-01, US-05
**Description**: Combine Levenshtein and token scores with weighting

### Task 7: Build duplicate detection
**Function**: `find_duplicate_groups()`
**Requirements**: US-01, US-02
**Description**: Group issues by similarity threshold

### Task 8: Implement group processing
**Function**: `process_duplicate_group()`
**Requirements**: US-02, US-03
**Description**: Identify keeper and mark duplicates

### Task 9: Create dry-run formatter
**Function**: `display_dry_run()`
**Requirements**: US-04
**Description**: Show what would be done without changes

### Task 10: Implement issue closing
**Function**: `close_duplicate_issue()`
**Requirements**: US-03
**Description**: Close issue with comment and label

### Task 11: Add progress indicators
**Function**: `show_progress()`
**Requirements**: NFR-03
**Description**: Display progress during processing

### Task 12: Create summary statistics
**Function**: `display_summary()`
**Requirements**: NFR-03
**Description**: Show final statistics after completion

## Implementation Order

1. **Phase 1 - Basic Structure** (Tasks 1, 2)
   - Get plugin working with issue fetching
   - Verify gh CLI integration

2. **Phase 2 - Similarity Detection** (Tasks 3-7)
   - Build core duplicate detection logic
   - Test with known duplicates

3. **Phase 3 - Processing Logic** (Tasks 8-9)
   - Implement group processing
   - Add dry-run output

4. **Phase 4 - Action Execution** (Task 10)
   - Add actual issue closing capability
   - Implement safety checks

5. **Phase 5 - Polish** (Tasks 11-12)
   - Add progress and statistics
   - Improve user experience

6. **Phase 6 - Testing & Docs**
   - Comprehensive testing
   - Documentation

## Success Criteria

- [ ] Plugin successfully identifies duplicate issues
- [ ] Dry-run mode works without making changes
- [ ] Confirm mode closes duplicates correctly
- [ ] Similarity threshold is configurable
- [ ] Performance meets requirements (< 30s for 1000 issues)
- [ ] All edge cases handled gracefully
- [ ] Documentation is complete and clear

## Notes

- Start with dry-run mode only for safety
- Test thoroughly with mock data before real repositories
- Consider adding interactive mode for manual review in future
- May need to optimize similarity algorithm for large repositories