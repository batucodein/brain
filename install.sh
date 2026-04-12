#!/bin/bash
set -e

SKILL_DIR="$HOME/.claude/skills/brain"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
REPO_URL="https://raw.githubusercontent.com/batucodein/brain/main"

echo "Installing brain skill..."

# Create skill directory
mkdir -p "$SKILL_DIR/templates"

# Detect install mode: local (cloned repo) or remote (curl one-liner)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/skill/SKILL.md" ]; then
    echo "Installing from local repo..."
    cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DIR/"
    cp "$SCRIPT_DIR/skill/SCHEMA.md" "$SKILL_DIR/"
    cp "$SCRIPT_DIR/skill/templates/"*.md "$SKILL_DIR/templates/"
else
    echo "Downloading from GitHub..."
    curl -fsSL "$REPO_URL/skill/SKILL.md" -o "$SKILL_DIR/SKILL.md"
    curl -fsSL "$REPO_URL/skill/SCHEMA.md" -o "$SKILL_DIR/SCHEMA.md"
    for page in index architecture decisions patterns history bugs; do
        curl -fsSL "$REPO_URL/skill/templates/${page}.md" -o "$SKILL_DIR/templates/${page}.md"
    done
fi

# Ensure CLAUDE.md exists
mkdir -p "$(dirname "$CLAUDE_MD")"
touch "$CLAUDE_MD"

# Add brain trigger to CLAUDE.md
BRAIN_BLOCK='# brain
- **brain** (`~/.claude/skills/brain/SKILL.md`) - per-repo project memory. Trigger: `/brain`
When the user types `/brain`, invoke the Skill tool with `skill: "brain"` before doing anything else.
When a repo has `.brain/` directory, read `.brain/index.md` at session start for project context.'

if grep -q "# brain" "$CLAUDE_MD" 2>/dev/null; then
    echo "brain entry already exists in $CLAUDE_MD"
else
    echo "" >> "$CLAUDE_MD"
    echo "$BRAIN_BLOCK" >> "$CLAUDE_MD"
    echo "Added brain trigger to $CLAUDE_MD"
fi

echo ""
echo "brain skill installed at $SKILL_DIR"
echo ""
echo "Usage:"
echo "  /brain            Auto-detect: init if no .brain/, otherwise status"
echo "  /brain init       Bootstrap .brain/ in current repo"
echo "  /brain status     Show .brain/ status"
echo "  /brain update     Update pages after a work session"
echo "  /brain query      Ask questions about the project"
echo "  /brain health     Check brain health and find issues"
echo ""
echo "Restart your Claude Code session to activate."
