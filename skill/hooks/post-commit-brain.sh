#!/bin/bash
# brain: post-commit hook for Claude Code
# Fires after git commit via Bash tool. If .brain/ exists but wasn't updated
# in this commit, nudges the LLM to check for brain-worthy changes.

read -r input_json

CWD=$(echo "$input_json" | jq -r '.cwd // empty')
[ -z "$CWD" ] && exit 0

# Check if .brain/ exists
if [ ! -d "$CWD/.brain" ]; then
  exit 0
fi

# Check if .brain/ files were already included in this commit — if so, skip
cd "$CWD"
if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -q '^\.brain/'; then
  exit 0
fi

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "brain: Code committed without .brain/ updates. When the current task is done, read .brain/SCHEMA.md and check the conversation for brain-worthy changes (choices made, bugs understood, constraints, rejected approaches, structural changes). If anything significant, update the relevant .brain/ pages and include them in the next commit. If nothing brain-worthy, skip silently."
  }
}'
