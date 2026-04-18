#!/bin/bash
# brain: post-commit hook for Claude Code
# Fires after git commit via Bash tool. If .brain/ exists but wasn't updated
# in this commit, nudges the LLM to check for brain-worthy changes.

# jq fallback: if jq is missing, emit a static warning via heredoc
# (no jq, no dynamic content) and exit cleanly. Prevents silent failure.
if ! command -v jq >/dev/null 2>&1; then
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"brain: WARNING — jq is not installed. brain post-commit hook is degraded (no update nudge). Install jq: brew install jq (macOS) / sudo apt install jq (Debian) / sudo dnf install jq (Fedora), then restart your session."}}
EOF
    exit 0
fi

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

# Skip nudge for non-user-originated commits. In each of these cases the commit
# wasn't a normal "user wrote code" commit, so there's no session context about
# WHY anything was decided — nudging the LLM to capture WHY would at best be
# noise, at worst cause it to invent reasoning about work it didn't do.
#
# - Merge commit in progress        → MERGE_HEAD exists until the merge commits cleanly
# - Cherry-pick in progress         → CHERRY_PICK_HEAD exists
# - Revert in progress              → REVERT_HEAD exists
# - Rebase in progress (either form)→ .git/rebase-merge or .git/rebase-apply dir exists
# - Amend                           → HEAD and previous-HEAD share a parent; they're different shas
#                                     but describe "the same conceptual commit" — skip to avoid
#                                     duplicate nudges for the same body of work
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")
if [ -n "$GIT_DIR" ] && [ -f "$GIT_DIR/MERGE_HEAD" ]; then exit 0; fi
if [ -n "$GIT_DIR" ] && [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then exit 0; fi
if [ -n "$GIT_DIR" ] && [ -f "$GIT_DIR/REVERT_HEAD" ]; then exit 0; fi
if [ -n "$GIT_DIR" ] && { [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; }; then exit 0; fi

# Also treat merge COMMITS (not just in-progress merges) as non-user-originated:
# commits with multiple parents are the record of a merge, no session context.
if [ "$(git rev-list --parents -n 1 HEAD 2>/dev/null | awk '{print NF-1}')" -gt 1 ]; then exit 0; fi

# Amend detection: HEAD and HEAD@{1} (reflog previous) share a parent, but are
# different commits. The amend replaced the prior HEAD in-place.
if PREV=$(git rev-parse HEAD@{1} 2>/dev/null); then
  if [ "$(git rev-parse HEAD^ 2>/dev/null)" = "$(git rev-parse "$PREV^" 2>/dev/null)" ] && \
     [ "$(git rev-parse HEAD)" != "$PREV" ]; then
    exit 0
  fi
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
