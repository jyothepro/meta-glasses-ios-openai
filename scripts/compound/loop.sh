#!/bin/bash

# scripts/compound/loop.sh
# Execution loop that runs tasks iteratively until complete or max iterations hit

set -e

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
MAX_ITERATIONS="${1:-25}"
TASKS_FILE="$PROJECT_DIR/scripts/compound/prd.json"
LOG_FILE="$PROJECT_DIR/logs/loop-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting execution loop (max iterations: $MAX_ITERATIONS)"

if [ ! -f "$TASKS_FILE" ]; then
    log "ERROR: Tasks file not found at $TASKS_FILE"
    exit 1
fi

cd "$PROJECT_DIR"

ITERATION=0
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    log "=== Iteration $ITERATION of $MAX_ITERATIONS ==="

    # Check if all tasks are complete
    PENDING_TASKS=$(jq -r '.tasks[] | select(.status != "completed") | .id' "$TASKS_FILE" 2>/dev/null | wc -l)

    if [ "$PENDING_TASKS" -eq 0 ]; then
        log "All tasks completed!"
        break
    fi

    log "Remaining tasks: $PENDING_TASKS"

    # Get the next incomplete task
    NEXT_TASK=$(jq -r '.tasks[] | select(.status != "completed") | .description' "$TASKS_FILE" 2>/dev/null | head -1)
    NEXT_TASK_ID=$(jq -r '.tasks[] | select(.status != "completed") | .id' "$TASKS_FILE" 2>/dev/null | head -1)

    if [ -z "$NEXT_TASK" ]; then
        log "No more tasks to process"
        break
    fi

    log "Working on task: $NEXT_TASK"

    # Execute the task with Claude
    claude -p "You are running as part of an automated execution loop.

CURRENT TASK: $NEXT_TASK

INSTRUCTIONS:
1. Implement the task described above
2. Make sure to follow patterns in CLAUDE.md
3. Write tests if appropriate
4. Commit your changes with a descriptive message
5. If you encounter blockers, document them clearly

After completing, confirm whether the task is done or needs more work." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

    CLAUDE_EXIT_CODE=${PIPESTATUS[0]}

    if [ $CLAUDE_EXIT_CODE -eq 0 ]; then
        log "Task iteration completed, marking task as done"
        # Update task status to completed
        jq --arg id "$NEXT_TASK_ID" '(.tasks[] | select(.id == $id)).status = "completed"' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"
    else
        log "WARNING: Claude exited with code $CLAUDE_EXIT_CODE, continuing..."
    fi

    # Brief pause between iterations
    sleep 2
done

if [ $ITERATION -ge $MAX_ITERATIONS ]; then
    log "WARNING: Reached maximum iterations ($MAX_ITERATIONS)"
fi

log "Execution loop finished after $ITERATION iterations"

# Final status
COMPLETED=$(jq -r '[.tasks[] | select(.status == "completed")] | length' "$TASKS_FILE" 2>/dev/null || echo "0")
TOTAL=$(jq -r '.tasks | length' "$TASKS_FILE" 2>/dev/null || echo "0")
log "Final status: $COMPLETED/$TOTAL tasks completed"
