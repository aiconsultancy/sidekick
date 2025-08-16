# GitHub Issue Deduplicator Plugin - Technical Design

## Architecture Overview

```
┌─────────────────────────────────────────┐
│           User Interface                 │
│     (sidekick dedupe-issues)            │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         Argument Parser                  │
│   (--dry-run, --confirm, --threshold)   │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│          Issue Fetcher                   │
│   (gh issue list with pagination)        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│       Duplicate Detector                 │
│   (Title similarity algorithm)           │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         Group Processor                  │
│   (Identify newest, mark old)            │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│          Action Executor                 │
│   (Close issues, add comments)           │
└─────────────────────────────────────────┘
```

## Component Design

### 1. Plugin Script: `sidekick-dedupe-issues`

**Location**: `plugins/sidekick-dedupe-issues`

**Responsibilities**:
- Parse command-line arguments
- Load environment configuration
- Orchestrate the deduplication workflow
- Handle dry-run vs. confirm modes

### 2. Issue Fetcher Module

**Function**: `fetch_all_issues()`

**Implementation**:
```bash
gh issue list --repo "$ORG/$REPO" \
    --limit 1000 \
    -s open \
    --json number,title,createdAt,author,url
```

**Output Format**:
```json
[
  {
    "number": 123,
    "title": "Bug: Application crashes on startup",
    "createdAt": "2024-01-15T10:30:00Z",
    "author": {"login": "user1"},
    "url": "https://github.com/org/repo/issues/123"
  }
]
```

### 3. Duplicate Detection Algorithm

**Function**: `find_duplicate_groups(issues, threshold)`

**Algorithm**:
1. Normalize titles (lowercase, remove special chars, stem words)
2. Calculate similarity matrix using:
   - Levenshtein distance for exact matching
   - Token-based similarity for word overlap
   - Weighted scoring: 70% exact match, 30% token similarity
3. Group issues with similarity > threshold
4. Sort groups by size (largest first)

**Similarity Calculation**:
```bash
similarity_score() {
    local title1="$1"
    local title2="$2"
    
    # Normalize
    norm1=$(normalize_title "$title1")
    norm2=$(normalize_title "$title2")
    
    # Calculate Levenshtein ratio
    lev_ratio=$(calculate_levenshtein "$norm1" "$norm2")
    
    # Calculate token overlap
    token_ratio=$(calculate_token_overlap "$norm1" "$norm2")
    
    # Weighted score
    score=$((lev_ratio * 70 + token_ratio * 30))
    echo $score
}
```

### 4. Group Processing Logic

**Function**: `process_duplicate_group(group)`

**Logic**:
1. Sort group by createdAt descending (newest first)
2. Mark first issue as "keeper"
3. Mark remaining issues as "duplicates"
4. Generate closure comment with reference

**Example Output**:
```json
{
  "keeper": {
    "number": 456,
    "title": "Bug: App crashes on startup"
  },
  "duplicates": [
    {
      "number": 123,
      "title": "Application crashes when starting",
      "action": "close",
      "comment": "Closing as duplicate of #456"
    }
  ]
}
```

### 5. Action Executor

**Function**: `execute_actions(actions, dry_run)`

**Dry Run Mode**:
- Display what would be done
- Show duplicate groups with similarity scores
- No API calls to modify issues

**Confirm Mode**:
- Close duplicate issues
- Add comment with reference to newest issue
- Add "duplicate" label
- Log all actions for rollback

## Data Flow

```
1. Fetch Issues
   └─> JSON array of open issues

2. Detect Duplicates
   ├─> Calculate similarity matrix
   └─> Group by threshold

3. Process Groups
   ├─> Identify keeper (newest)
   └─> Mark duplicates

4. Execute Actions
   ├─> [Dry Run] Display plan
   └─> [Confirm] Close issues
```

## Similarity Algorithm Details

### Title Normalization
1. Convert to lowercase
2. Remove special characters except spaces
3. Remove common words (the, a, an, is, etc.)
4. Trim whitespace
5. Sort tokens alphabetically (optional)

### Levenshtein Distance
- Use dynamic programming implementation
- Convert to ratio: `1 - (distance / max_length)`
- Range: 0 (completely different) to 100 (identical)

### Token Overlap
- Split into words
- Calculate Jaccard similarity
- Formula: `intersection / union * 100`

## Configuration

### Environment Variables
- `SIDEKICK_GITHUB_ORG`: Default organization
- `SIDEKICK_GITHUB_REPO`: Default repository
- `DEDUPE_THRESHOLD`: Default similarity threshold (85)
- `DEDUPE_DRY_RUN`: Default to dry-run mode (true)

### Command-Line Options
```bash
Options:
  -t, --threshold NUM   Similarity threshold (0-100, default: 85)
  -n, --dry-run        Preview without making changes (default)
  -c, --confirm        Execute the deduplication
  -l, --limit NUM      Maximum issues to process (default: 1000)
  -v, --verbose        Show detailed processing information
  -h, --help          Show help message
```

## Error Handling

1. **No Issues Found**: Exit gracefully with message
2. **API Rate Limit**: Wait and retry with exponential backoff
3. **Network Error**: Retry 3 times before failing
4. **Invalid Threshold**: Show error and valid range
5. **Permission Denied**: Check gh auth and repository access

## Performance Considerations

1. **Batch Processing**: Process in chunks of 100 for large repos
2. **Caching**: Cache similarity calculations during session
3. **Parallel Processing**: Calculate similarities in parallel where possible
4. **Early Termination**: Skip comparison if titles differ significantly in length

## Security Considerations

1. **Dry Run Default**: Prevent accidental closures
2. **Confirmation Required**: Explicit flag for modifications
3. **Audit Log**: Record all actions taken
4. **Rate Limiting**: Respect GitHub API limits
5. **Token Security**: Use gh CLI for authentication

## Testing Strategy

### Unit Tests
- Title normalization function
- Similarity calculation
- Group identification logic

### Integration Tests
- API interaction with mock data
- End-to-end workflow with test repository
- Edge cases (empty repo, no duplicates)

### Manual Testing
- Various similarity thresholds
- Different repository sizes
- Repositories with known duplicates