# GitHub Issue Deduplicator Plugin - Requirements

## Overview
A sidekick plugin that identifies and removes duplicate GitHub issues, keeping only the newest instance of each duplicate group.

## User Stories

### US-01: Detect Duplicate Issues
**As a** repository maintainer  
**I want to** identify duplicate issues automatically  
**So that** I can reduce clutter and focus on unique problems  

**Acceptance Criteria:**
- GIVEN a repository with multiple open issues
- WHEN I run the deduplicator plugin
- THEN it identifies groups of duplicate issues based on title similarity
- AND shows me which issues are duplicates of each other

### US-02: Keep Newest Issue
**As a** repository maintainer  
**I want to** keep the newest duplicate issue  
**So that** the most recent context and discussion is preserved  

**Acceptance Criteria:**
- GIVEN a group of duplicate issues
- WHEN the plugin processes duplicates
- THEN it identifies the newest issue by creation date
- AND marks older duplicates for closure

### US-03: Close Duplicate Issues
**As a** repository maintainer  
**I want to** close older duplicate issues with a reference to the newest one  
**So that** users can find the active discussion  

**Acceptance Criteria:**
- GIVEN identified duplicate issues
- WHEN I confirm the deduplication
- THEN older issues are closed with a comment referencing the newest issue
- AND a "duplicate" label is added to closed issues

### US-04: Dry Run Mode
**As a** repository maintainer  
**I want to** preview what would be closed without making changes  
**So that** I can verify the deduplication logic before applying it  

**Acceptance Criteria:**
- GIVEN the deduplicator plugin
- WHEN I run it with --dry-run flag
- THEN it shows what would be closed without making changes
- AND displays duplicate groups with similarity scores

### US-05: Similarity Threshold Configuration
**As a** repository maintainer  
**I want to** configure the similarity threshold  
**So that** I can control how strict the duplicate detection is  

**Acceptance Criteria:**
- GIVEN the deduplicator plugin
- WHEN I specify a --threshold parameter (0-100)
- THEN it only considers issues duplicates if similarity exceeds threshold
- AND defaults to 85% similarity if not specified

## Non-Functional Requirements

### NFR-01: Performance
- Must handle repositories with 1000+ issues
- Should complete analysis within 30 seconds for 1000 issues
- API calls should respect GitHub rate limits

### NFR-02: Safety
- Must always run in dry-run mode by default
- Requires explicit --confirm flag to make changes
- Should create a rollback log of actions taken

### NFR-03: Usability
- Clear output showing duplicate groups
- Progress indicators during processing
- Summary statistics after completion

## Constraints

1. Uses GitHub CLI (`gh`) for API access
2. Respects SIDEKICK_GITHUB_ORG and SIDEKICK_GITHUB_REPO environment variables
3. Only processes open issues (closed issues are ignored)
4. Maximum 1000 issues per run (GitHub API limitation)

## Edge Cases

1. **Empty Repository**: Handle gracefully with appropriate message
2. **No Duplicates Found**: Report that no duplicates were detected
3. **All Issues Similar**: Warn if threshold might be too low
4. **Rate Limiting**: Handle GitHub API rate limits gracefully
5. **Network Failures**: Retry with exponential backoff
6. **Partial Matches**: Issues with similar but not identical titles

## Success Metrics

- Reduces open issue count by identifying duplicates
- Saves maintainer time by automating duplicate detection
- Improves issue tracker organization
- Zero false positives in production use