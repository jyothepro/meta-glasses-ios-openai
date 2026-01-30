#!/bin/bash

# scripts/compound/auto-compound.sh
# Full pipeline: report -> PRD -> tasks -> implementation -> PR
# Runs after daily-compound-review.sh to benefit from fresh learnings

set -e

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_FILE="$PROJECT_DIR/logs/auto-compound-$(date +%Y%m%d).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

log "Starting auto-compound pipeline..."

cd "$PROJECT_DIR"

# Source environment if exists
if [ -f "$PROJECT_DIR/.env.local" ]; then
    source "$PROJECT_DIR/.env.local"
    log "Loaded environment from .env.local"
fi

# Fetch latest (including tonight's CLAUDE.md updates from compound review)
log "Fetching latest from origin/main..."
git fetch origin main
git checkout main
git reset --hard origin/main

# Find the latest prioritized report
log "Looking for prioritized reports..."
LATEST_REPORT=$(ls -t "$PROJECT_DIR/reports/"*.md 2>/dev/null | head -1)

if [ -z "$LATEST_REPORT" ]; then
    log "No report files found in reports/ directory"
    log "Creating a default priorities report..."

    # Generate priorities from code analysis
    claude -p "Analyze this codebase and create a prioritized report of improvements, features, or fixes needed.

Look at:
1. TODO comments in the code
2. Potential improvements based on code patterns
3. Missing tests or documentation
4. Performance opportunities
5. User experience improvements

Create a markdown report at reports/priorities-$(date +%Y%m%d).md with items ranked by priority.
Each item should have a clear description and rationale.

Format:
# Priorities Report - $(date +%Y-%m-%d)

## High Priority
1. **Item name**: Description and why it matters

## Medium Priority
...

## Low Priority
..." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

    LATEST_REPORT=$(ls -t "$PROJECT_DIR/reports/"*.md 2>/dev/null | head -1)

    if [ -z "$LATEST_REPORT" ]; then
        error_exit "Failed to create priorities report"
    fi
fi

log "Using report: $LATEST_REPORT"

# Analyze and pick #1 priority
log "Analyzing report to extract top priority..."
ANALYSIS=$("$PROJECT_DIR/scripts/compound/analyze-report.sh" "$LATEST_REPORT")

# Parse JSON response
PRIORITY_ITEM=$(echo "$ANALYSIS" | jq -r '.priority_item' 2>/dev/null)
BRANCH_NAME=$(echo "$ANALYSIS" | jq -r '.branch_name' 2>/dev/null)

if [ -z "$PRIORITY_ITEM" ] || [ "$PRIORITY_ITEM" == "null" ]; then
    error_exit "Failed to extract priority item from analysis"
fi

if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" == "null" ]; then
    # Generate a default branch name
    BRANCH_NAME="feature/auto-compound-$(date +%Y%m%d)"
fi

log "Priority item: $PRIORITY_ITEM"
log "Branch name: $BRANCH_NAME"

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    log "Branch $BRANCH_NAME already exists, adding timestamp suffix"
    BRANCH_NAME="${BRANCH_NAME}-$(date +%H%M%S)"
fi

# Create feature branch
log "Creating feature branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# Create PRD
log "Creating PRD for the priority item..."
PRD_FILE="$PROJECT_DIR/tasks/prd-$(basename "$BRANCH_NAME").md"

claude -p "Create a detailed Product Requirements Document (PRD) for this task:

TASK: $PRIORITY_ITEM

Create a PRD at: $PRD_FILE

The PRD should include:
1. **Overview**: What we're building and why
2. **Requirements**: Specific, testable requirements
3. **Technical Approach**: How to implement it
4. **Testing Strategy**: How to verify it works
5. **Acceptance Criteria**: Definition of done

Keep it concise but complete enough to guide implementation." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

if [ ! -f "$PRD_FILE" ]; then
    log "WARNING: PRD file not created at expected location, searching..."
    PRD_FILE=$(ls -t "$PROJECT_DIR/tasks/"prd-*.md 2>/dev/null | head -1)
fi

# Convert PRD to tasks JSON
log "Converting PRD to executable tasks..."
TASKS_FILE="$PROJECT_DIR/scripts/compound/prd.json"

claude -p "Convert this PRD into a structured JSON task list.

PRD FILE: $PRD_FILE
$(cat "$PRD_FILE" 2>/dev/null || echo "PRD file not found")

Create a JSON file at: $TASKS_FILE

Format:
{
  \"prd_source\": \"$PRD_FILE\",
  \"created_at\": \"$(date -Iseconds)\",
  \"tasks\": [
    {
      \"id\": \"1\",
      \"description\": \"Clear, actionable task description\",
      \"status\": \"pending\"
    },
    ...
  ]
}

Break down the PRD into 3-7 concrete, implementable tasks.
Each task should be completable in a single focused session.
Order tasks by dependency (prerequisites first)." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

if [ ! -f "$TASKS_FILE" ]; then
    error_exit "Failed to create tasks file"
fi

log "Tasks file created: $TASKS_FILE"
cat "$TASKS_FILE" | tee -a "$LOG_FILE"

# Run the execution loop
log "Starting execution loop..."
"$PROJECT_DIR/scripts/compound/loop.sh" 25

# Commit any remaining changes
log "Committing any final changes..."
git add -A
git diff --staged --quiet || git commit -m "chore: auto-compound implementation for $PRIORITY_ITEM"

# Push and create PR
log "Pushing branch and creating PR..."
git push -u origin "$BRANCH_NAME"

# Create draft PR using gh CLI
if command -v gh &> /dev/null; then
    PR_URL=$(gh pr create --draft \
        --title "Auto-compound: $PRIORITY_ITEM" \
        --body "$(cat <<EOF
## Summary
Automated implementation of: **$PRIORITY_ITEM**

## Source
- Report: \`$(basename "$LATEST_REPORT")\`
- PRD: \`$(basename "$PRD_FILE")\`

## Changes
This PR was created by the nightly auto-compound pipeline.

## Review Notes
- [ ] Review implementation matches PRD requirements
- [ ] Verify tests pass
- [ ] Check for any missed edge cases

---
*Generated by auto-compound at $(date)*
EOF
)" --base main 2>&1) || true

    if [ -n "$PR_URL" ]; then
        log "PR created: $PR_URL"
    else
        log "WARNING: Failed to create PR via gh CLI"
    fi
else
    log "WARNING: gh CLI not installed, skipping PR creation"
    log "Push completed. Create PR manually at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/$BRANCH_NAME"
fi

log "Auto-compound pipeline completed successfully!"
log "Branch: $BRANCH_NAME"
log "Priority implemented: $PRIORITY_ITEM"
