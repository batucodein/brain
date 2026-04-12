#!/bin/bash
# brain: session start hook for Claude Code
# If .brain/ exists, nudges the LLM to read project context.

read -r input_json

CWD=$(echo "$input_json" | jq -r '.cwd // empty')
[ -z "$CWD" ] && exit 0

if [ -f "$CWD/.brain/index.md" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": "brain: This repo has .brain/ project memory. Read .brain/index.md for project context. Read additional pages as needed based on the task. When you need to update brain pages, read .brain/SCHEMA.md for format rules and instructions."
    }
  }'
fi
