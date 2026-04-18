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

# Check if this is the first commit (no parent) — skip
cd "$CWD"
if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
  exit 0
fi

# Check if commit has any non-.brain/ files — if not, this is a brain-only commit, skip
if ! git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -qv '^\.brain/'; then
  exit 0
fi

# Diagnostic: warn if SCHEMA.md is missing
if [ ! -f "$CWD/.brain/SCHEMA.md" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": "brain: WARNING — .brain/SCHEMA.md is missing. Brain updates will fail or corrupt without it. Restore it: cp ~/.claude/skills/brain/SCHEMA.md .brain/SCHEMA.md (if skill installed) or copy from another repo that has brain."
    }
  }'
  exit 0
fi

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "brain: IMMEDIATELY check this session for brain-worthy changes before doing anything else. Look for: choices made, bugs understood, constraints, rejected approaches, structural changes. If significant, read .brain/SCHEMA.md, update pages (event-type pages AND any related .brain/topics/*.md Timelines), and commit: git add .brain/ && git commit -m \"brain: <summary>\". Then continue with the developer'"'"'s work. If nothing brain-worthy, skip silently."
  }
}'
