#!/bin/bash
# brain: session start hook for Claude Code
# If .brain/ exists, nudges the LLM to read project context.

# jq fallback: if jq is missing, emit a static warning via heredoc
# (no jq, no dynamic content) and exit cleanly. Prevents silent failure.
if ! command -v jq >/dev/null 2>&1; then
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"brain: WARNING — jq is not installed. brain hooks are degraded (no project-context injection, no topic discovery). Install jq: brew install jq (macOS) / sudo apt install jq (Debian) / sudo dnf install jq (Fedora), then restart your session."}}
EOF
    exit 0
fi

read -r input_json

CWD=$(echo "$input_json" | jq -r '.cwd // empty')
[ -z "$CWD" ] && exit 0

# Check if .brain/ directory exists at all
if [ ! -d "$CWD/.brain" ]; then
  exit 0
fi

cd "$CWD"

# Build diagnostic warnings
WARNINGS=""

# Diagnostic D1: .brain/ exists but index.md missing — broken brain
if [ ! -f "$CWD/.brain/index.md" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": "brain: WARNING — .brain/ exists but .brain/index.md is missing. Brain is broken. Restore index.md or run /brain init to rebuild."
    }
  }'
  exit 0
fi

# Diagnostic: SCHEMA.md missing
if [ ! -f "$CWD/.brain/SCHEMA.md" ]; then
  WARNINGS="$WARNINGS WARNING: .brain/SCHEMA.md is missing — brain updates will fail or corrupt. Restore: cp ~/.claude/skills/brain/SCHEMA.md .brain/SCHEMA.md or copy from another brain repo."
fi

# Diagnostic D7: staleness check with date validation
LAST_BRAIN=$(git log -1 --format=%ct -- .brain/ 2>/dev/null || echo "")
LAST_CODE=$(git log -1 --format=%ct -- ':(exclude).brain/' 2>/dev/null || echo "")

if [ -n "$LAST_BRAIN" ] && [ -n "$LAST_CODE" ] && [ "$LAST_CODE" -gt "$LAST_BRAIN" ]; then
  BRAIN_DATE=$(git log -1 --format=%ci -- .brain/ 2>/dev/null | cut -d' ' -f1)
  CODE_DATE=$(git log -1 --format=%ci -- ':(exclude).brain/' 2>/dev/null | cut -d' ' -f1)

  # Validate YYYY-MM-DD format before using
  if ! echo "$BRAIN_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    BRAIN_DATE="(date unavailable)"
  fi
  if ! echo "$CODE_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    CODE_DATE="(date unavailable)"
  fi

  WARNINGS="$WARNINGS brain may be stale — last updated $BRAIN_DATE but code committed $CODE_DATE. Consider /brain update."
fi

# Topic discovery: list topic page names only (content NOT loaded — stays cheap at session start).
# Names let the LLM know which topics exist so it can read them on demand via wikilinks or /brain query.
TOPIC_NAMES=""
if [ -d "$CWD/.brain/topics" ]; then
  TOPIC_NAMES=$(ls "$CWD/.brain/topics"/*.md 2>/dev/null \
    | xargs -n1 basename -s .md 2>/dev/null \
    | paste -sd ',' - \
    | sed 's/,/, /g')
fi

jq -n --arg warnings "$WARNINGS" --arg topics "$TOPIC_NAMES" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": (
      "brain: This repo has .brain/ project memory. Read .brain/index.md for project context. Read additional pages as needed based on the task. When you need to update brain pages, read .brain/SCHEMA.md for format rules and instructions."
      + (if $topics != "" then " Topic pages available (read on demand): " + $topics + "." else "" end)
      + $warnings
    )
  }
}'
