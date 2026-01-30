# Agent Automation Setup Guide

This guide explains how to set up the nightly automation loop that reviews work, compounds learnings, and implements priorities while you sleep.

## Overview

The system runs two jobs every night:

| Time | Job | Purpose |
|------|-----|---------|
| 10:30 PM | Compound Review | Reviews threads, extracts learnings, updates CLAUDE.md |
| 11:00 PM | Auto-Compound | Picks #1 priority, implements it, creates PR |

The order matters: the review job updates CLAUDE.md with learnings, then the implementation job benefits from those learnings.

## Prerequisites

- **Claude Code CLI** installed and authenticated (`claude` command available)
- **GitHub CLI** installed and authenticated (`gh` command available)
- **jq** installed for JSON parsing (`brew install jq`)
- **macOS** for launchd scheduling (or adapt for cron on Linux)

## Quick Start

### 1. Make scripts executable

```bash
chmod +x scripts/daily-compound-review.sh
chmod +x scripts/compound/auto-compound.sh
chmod +x scripts/compound/analyze-report.sh
chmod +x scripts/compound/loop.sh
```

### 2. Create environment file (optional)

```bash
cp .env.example .env.local
# Edit .env.local with your API keys
```

### 3. Update launchd plist paths

Edit each file in `launchd/` and replace `YOUR_USERNAME` with your actual username and correct project path:

```bash
# Example: Replace paths in plist files
sed -i '' 's|/Users/YOUR_USERNAME/projects/meta-glasses-ios-openai|/Users/$(whoami)/path/to/your/project|g' launchd/*.plist
```

### 4. Install launchd jobs

```bash
# Copy plist files to LaunchAgents
cp launchd/*.plist ~/Library/LaunchAgents/

# Load the jobs
launchctl load ~/Library/LaunchAgents/com.meta-glasses.daily-compound-review.plist
launchctl load ~/Library/LaunchAgents/com.meta-glasses.auto-compound.plist
launchctl load ~/Library/LaunchAgents/com.meta-glasses.caffeinate.plist
```

### 5. Verify installation

```bash
launchctl list | grep meta-glasses
```

## Directory Structure

```
meta-glasses-ios-openai/
├── scripts/
│   ├── daily-compound-review.sh    # Nightly learning extraction
│   └── compound/
│       ├── auto-compound.sh        # Main implementation pipeline
│       ├── analyze-report.sh       # Extracts priority from reports
│       └── loop.sh                 # Task execution loop
├── launchd/
│   ├── com.meta-glasses.daily-compound-review.plist
│   ├── com.meta-glasses.auto-compound.plist
│   └── com.meta-glasses.caffeinate.plist
├── reports/
│   └── priorities-example.md       # Priority backlog
├── tasks/
│   └── (PRDs generated here)
├── logs/
│   └── (Log files)
└── CLAUDE.md                       # Agent instructions + learnings
```

## Creating Priority Reports

Create markdown files in `reports/` with this format:

```markdown
# Priorities Report - 2025-01-30

## High Priority

1. **Task name**: Description of what needs to be done and why it matters.

2. **Another task**: More details here.

## Medium Priority

3. **Lower priority task**: Description.

## Low Priority

4. **Nice to have**: Description.

## Done

- ~~Completed task~~
```

The auto-compound job picks the first item from "High Priority" and implements it.

## Manual Testing

### Test compound review
```bash
./scripts/daily-compound-review.sh
```

### Test auto-compound (creates a real PR!)
```bash
./scripts/compound/auto-compound.sh
```

### Trigger via launchd
```bash
launchctl start com.meta-glasses.daily-compound-review
```

## Viewing Logs

```bash
# Watch compound review logs
tail -f logs/compound-review-*.log

# Watch auto-compound logs
tail -f logs/auto-compound-*.log

# Watch execution loop logs
tail -f logs/loop-*.log
```

## Troubleshooting

### Jobs not running

1. Check if loaded: `launchctl list | grep meta-glasses`
2. Check for errors: `launchctl error`
3. Verify paths in plist files are correct
4. Ensure Mac is awake (caffeinate job should handle this)

### Claude CLI errors

1. Verify Claude is installed: `which claude`
2. Check authentication: `claude --version`
3. Ensure API key is set or in `.env.local`

### Git/GitHub errors

1. Verify gh CLI: `gh auth status`
2. Check git remote: `git remote -v`
3. Ensure you have push access to the repository

## Customization

### Change schedule times

Edit the `StartCalendarInterval` in the plist files:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>22</integer>  <!-- 10 PM -->
    <key>Minute</key>
    <integer>30</integer>
</dict>
```

### Adjust iteration limit

The loop.sh script accepts a max iterations argument:

```bash
./scripts/compound/loop.sh 50  # Run up to 50 iterations
```

### Add Slack notifications

Add to auto-compound.sh after PR creation:

```bash
curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"Auto-compound created PR: $PR_URL\"}" \
    "$SLACK_WEBHOOK_URL"
```

## Uninstalling

```bash
# Unload jobs
launchctl unload ~/Library/LaunchAgents/com.meta-glasses.daily-compound-review.plist
launchctl unload ~/Library/LaunchAgents/com.meta-glasses.auto-compound.plist
launchctl unload ~/Library/LaunchAgents/com.meta-glasses.caffeinate.plist

# Remove plist files
rm ~/Library/LaunchAgents/com.meta-glasses.*.plist
```

## How It Works

### Compound Review (10:30 PM)

1. Checks out main and pulls latest
2. Runs Claude Code to review recent git commits
3. Extracts patterns, gotchas, and learnings
4. Updates CLAUDE.md with new knowledge
5. Commits and pushes to main

### Auto-Compound (11:00 PM)

1. Pulls main (now with fresh CLAUDE.md updates)
2. Reads the latest report from `reports/`
3. Uses Claude to identify the #1 priority item
4. Creates a feature branch
5. Generates a PRD (Product Requirements Document)
6. Breaks the PRD into executable tasks
7. Runs the execution loop (up to 25 iterations)
8. Pushes branch and creates a draft PR

### Execution Loop

1. Reads tasks from `prd.json`
2. Picks the next incomplete task
3. Runs Claude Code to implement it
4. Marks task as complete
5. Repeats until all tasks done or max iterations hit

## Security Notes

- The `--dangerously-skip-permissions` flag allows Claude to execute without prompts
- Review all PRs before merging - automated code should be treated as untrusted
- Keep API keys in `.env.local` (gitignored) rather than plist files
- Consider running on a dedicated machine or VM for isolation
