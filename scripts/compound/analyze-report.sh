#!/bin/bash

# scripts/compound/analyze-report.sh
# Analyzes a prioritized report and extracts the #1 priority item

set -e

REPORT_FILE="$1"

if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
    echo "Usage: $0 <report-file>" >&2
    exit 1
fi

# Extract priority item and generate branch name using Claude
# Output is JSON with priority_item and branch_name

claude -p "Analyze this prioritized report and extract the #1 highest priority item.

REPORT CONTENT:
$(cat "$REPORT_FILE")

OUTPUT FORMAT (JSON only, no other text):
{
  \"priority_item\": \"Brief description of the #1 priority task\",
  \"branch_name\": \"feature/short-kebab-case-name\"
}

Rules for branch_name:
- Start with feature/, fix/, or chore/ as appropriate
- Use kebab-case
- Keep it short (max 50 chars total)
- Make it descriptive of the task

Return ONLY the JSON object, no markdown code blocks or other text." --dangerously-skip-permissions --print 2>/dev/null
