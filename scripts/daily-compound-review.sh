#!/bin/bash

# scripts/daily-compound-review.sh
# Runs BEFORE auto-compound.sh to update CLAUDE.md with learnings
# Reviews all Claude threads from the last 24 hours and extracts missed learnings

set -e

# Configuration
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_FILE="$PROJECT_DIR/logs/compound-review-$(date +%Y%m%d).log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting daily compound review..."

cd "$PROJECT_DIR"

# Ensure we're on main and up to date
log "Checking out main branch and pulling latest..."
git checkout main
git pull origin main

# Run Claude Code to review threads and compound learnings
log "Running Claude Code to review threads and extract learnings..."

claude -p "You are running as part of a nightly automation job. Your task is to review recent work and compound learnings.

INSTRUCTIONS:
1. Review any recent changes to the codebase (check git log from last 24 hours)
2. Look for patterns, lessons learned, and improvements that should be documented
3. Update CLAUDE.md with any relevant learnings:
   - New patterns discovered
   - Gotchas or pitfalls to avoid
   - Architectural decisions and their rationale
   - Testing approaches that worked well
   - Performance considerations
4. If there are no meaningful learnings to add, that's fine - don't add noise
5. If you do make changes, commit them with message 'chore: compound learnings from $(date +%Y-%m-%d)'
6. Push changes to main

Focus on extracting actionable knowledge that will help future development sessions.
Be concise and practical - only document things that will genuinely help." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

CLAUDE_EXIT_CODE=${PIPESTATUS[0]}

if [ $CLAUDE_EXIT_CODE -eq 0 ]; then
    log "Compound review completed successfully"
else
    log "ERROR: Compound review failed with exit code $CLAUDE_EXIT_CODE"
    exit $CLAUDE_EXIT_CODE
fi

log "Daily compound review finished"
