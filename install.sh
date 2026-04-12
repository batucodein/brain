#!/bin/bash
set -e

SKILL_DIR="$HOME/.claude/skills/brain"
HOOKS_DIR="$HOME/.claude/hooks"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SETTINGS="$HOME/.claude/settings.json"
REPO_URL="https://raw.githubusercontent.com/batucodein/brain/main"

echo "Installing brain..."

# Create directories
mkdir -p "$SKILL_DIR/templates" "$SKILL_DIR/hooks" "$HOOKS_DIR"

# Detect install mode: local (cloned repo) or remote (curl one-liner)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/skill/SKILL.md" ]; then
    echo "Installing from local repo..."
    cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DIR/"
    cp "$SCRIPT_DIR/skill/SCHEMA.md" "$SKILL_DIR/"
    cp "$SCRIPT_DIR/skill/templates/"*.md "$SKILL_DIR/templates/" 2>/dev/null || true
    cp "$SCRIPT_DIR/skill/templates/"*.html "$SKILL_DIR/templates/" 2>/dev/null || true
    cp "$SCRIPT_DIR/skill/hooks/"*.sh "$HOOKS_DIR/" 2>/dev/null || true
else
    echo "Downloading from GitHub..."
    curl -fsSL "$REPO_URL/skill/SKILL.md" -o "$SKILL_DIR/SKILL.md"
    curl -fsSL "$REPO_URL/skill/SCHEMA.md" -o "$SKILL_DIR/SCHEMA.md"
    for page in index architecture decisions patterns history bugs; do
        curl -fsSL "$REPO_URL/skill/templates/${page}.md" -o "$SKILL_DIR/templates/${page}.md"
    done
    curl -fsSL "$REPO_URL/skill/templates/dashboard.html" -o "$SKILL_DIR/templates/dashboard.html"
    curl -fsSL "$REPO_URL/skill/hooks/post-commit-brain.sh" -o "$HOOKS_DIR/post-commit-brain.sh"
    curl -fsSL "$REPO_URL/skill/hooks/session-start-brain.sh" -o "$HOOKS_DIR/session-start-brain.sh"
fi

# Make hooks executable
chmod +x "$HOOKS_DIR/post-commit-brain.sh" 2>/dev/null || true
chmod +x "$HOOKS_DIR/session-start-brain.sh" 2>/dev/null || true

# Ensure CLAUDE.md exists and add brain trigger
mkdir -p "$(dirname "$CLAUDE_MD")"
touch "$CLAUDE_MD"

BRAIN_BLOCK='# brain
- **brain** (`~/.claude/skills/brain/SKILL.md`) - per-repo project memory. Trigger: `/brain`
When the user types `/brain`, invoke the Skill tool with `skill: "brain"` before doing anything else.
When a repo has `.brain/` directory, read `.brain/SCHEMA.md` for instructions and `.brain/index.md` for project context.'

if grep -q "# brain" "$CLAUDE_MD" 2>/dev/null; then
    echo "brain entry already exists in $CLAUDE_MD"
else
    echo "" >> "$CLAUDE_MD"
    echo "$BRAIN_BLOCK" >> "$CLAUDE_MD"
    echo "Added brain trigger to $CLAUDE_MD"
fi

# Install Claude Code hooks in settings.json
if [ -f "$SETTINGS" ]; then
    # Check if hooks already exist
    if grep -q "post-commit-brain" "$SETTINGS" 2>/dev/null; then
        echo "brain hooks already in settings.json"
    else
        echo "Adding brain hooks to settings.json..."
        # Use a temp file to merge hooks into existing settings
        TEMP=$(mktemp)
        jq --arg postcommit "$HOOKS_DIR/post-commit-brain.sh" \
           --arg sessionstart "$HOOKS_DIR/session-start-brain.sh" '
          .hooks //= {} |
          .hooks.PostToolUse //= [] |
          .hooks.PostToolUse += [{
            "matcher": "Bash",
            "hooks": [{
              "type": "command",
              "if": "Bash(git commit*)",
              "command": $postcommit,
              "timeout": 30
            }]
          }] |
          .hooks.SessionStart //= [] |
          .hooks.SessionStart += [{
            "matcher": "",
            "hooks": [{
              "type": "command",
              "command": $sessionstart,
              "timeout": 10
            }]
          }]
        ' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"
        echo "brain hooks added to settings.json"
    fi
else
    # Create settings.json with hooks
    jq -n --arg postcommit "$HOOKS_DIR/post-commit-brain.sh" \
       --arg sessionstart "$HOOKS_DIR/session-start-brain.sh" '{
      hooks: {
        PostToolUse: [{
          matcher: "Bash",
          hooks: [{
            type: "command",
            if: "Bash(git commit*)",
            command: $postcommit,
            timeout: 30
          }]
        }],
        SessionStart: [{
          matcher: "",
          hooks: [{
            type: "command",
            command: $sessionstart,
            timeout: 10
          }]
        }]
      }
    }' > "$SETTINGS"
    echo "Created settings.json with brain hooks"
fi

echo ""
echo "brain installed:"
echo "  Skill:  $SKILL_DIR"
echo "  Hooks:  $HOOKS_DIR"
echo ""
echo "Three ways to use brain:"
echo ""
echo "  1. Zero install (any repo with .brain/)"
echo "     Just clone — CLAUDE.md + SCHEMA.md handle everything."
echo ""
echo "  2. Power commands (/brain skill)"
echo "     /brain init       Bootstrap .brain/ in a new repo"
echo "     /brain query      Search across all brain pages"
echo "     /brain dashboard  Generate visual dashboard"
echo "     /brain health     Check for stale pages and gaps"
echo ""
echo "  3. Auto-update (hooks — just installed)"
echo "     Session start:  Reads .brain/ automatically"
echo "     After commit:   Checks for brain-worthy changes"
echo ""
echo "Restart your Claude Code session to activate."
