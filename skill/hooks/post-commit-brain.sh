#!/bin/bash
# brain: post-commit hook for Claude Code
# Fires after git commit via Bash tool. If .brain/ exists, nudges the LLM
# to check conversation for brain-worthy changes.

read -r input_json

CWD=$(echo "$input_json" | jq -r '.cwd // empty')
[ -z "$CWD" ] && exit 0

# Check if .brain/ exists in the project
if [ ! -d "$CWD/.brain" ]; then
  exit 0
fi

# Check if .brain/index.md was part of this commit (brain-only commit — skip)
COMMAND=$(echo "$input_json" | jq -r '.tool_input.command // empty')
if echo "$COMMAND" | grep -q 'git add .brain'; then
  exit 0
fi

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "brain: Code committed. This repo has .brain/ — check the conversation since the last brain update for brain-worthy changes: choices made, bugs understood, constraints that shaped the work, rejected approaches, or structural changes. If anything significant happened, update the relevant .brain/ pages following .brain/SCHEMA.md. If nothing brain-worthy, skip silently."
  }
}'
