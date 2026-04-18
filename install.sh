#!/bin/bash
set -e

SKILL_DIR="$HOME/.claude/skills/brain"
HOOKS_DIR="$HOME/.claude/hooks"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SETTINGS="$HOME/.claude/settings.json"
REPO_URL="https://raw.githubusercontent.com/batucodein/brain/main"

# Preflight: jq is required for hook registration (modifies settings.json)
# and at runtime by both hook scripts. Check BEFORE any mkdir/cp so a
# partial install never happens.
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not installed."
    echo ""
    echo "jq is a command-line JSON processor used to register brain's"
    echo "hooks in ~/.claude/settings.json and to produce JSON output"
    echo "from the hook scripts at runtime."
    echo ""
    echo "Install jq:"
    echo "  macOS:   brew install jq"
    echo "  Debian:  sudo apt install jq"
    echo "  Fedora:  sudo dnf install jq"
    echo "  Arch:    sudo pacman -S jq"
    echo ""
    echo "Then re-run this installer."
    exit 1
fi

# Parse args
MODE="full"
while [ $# -gt 0 ]; do
    case "$1" in
        --hooks-only)
            MODE="hooks-only"
            shift
            ;;
        --help|-h)
            echo "Usage: install.sh [--hooks-only]"
            echo "  (no flags)    Full install: skill files, hooks, CLAUDE.md, settings.json"
            echo "  --hooks-only  Reinstall only hook scripts + re-register in settings.json"
            echo "                Use when /brain doctor reports hooks missing or unregistered."
            exit 0
            ;;
        *)
            echo "Unknown arg: $1 (see --help)"
            exit 1
            ;;
    esac
done

if [ "$MODE" = "hooks-only" ]; then
    echo "Reinstalling brain hooks only..."
else
    echo "Installing brain..."
fi

# Create directories
mkdir -p "$SKILL_DIR/templates" "$SKILL_DIR/hooks" "$HOOKS_DIR"

# Detect install mode: local (cloned repo) or remote (curl one-liner)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/skill/SKILL.md" ]; then
    if [ "$MODE" = "hooks-only" ]; then
        echo "Copying hook scripts from local repo..."
        cp "$SCRIPT_DIR/skill/hooks/"*.sh "$HOOKS_DIR/" 2>/dev/null || true
    else
        echo "Installing from local repo..."
        cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DIR/"
        cp "$SCRIPT_DIR/skill/SCHEMA.md" "$SKILL_DIR/"
        cp "$SCRIPT_DIR/skill/DIAGNOSTICS.md" "$SKILL_DIR/"
        cp "$SCRIPT_DIR/skill/templates/"*.md "$SKILL_DIR/templates/" 2>/dev/null || true
        cp "$SCRIPT_DIR/skill/templates/"*.html "$SKILL_DIR/templates/" 2>/dev/null || true
        cp "$SCRIPT_DIR/skill/hooks/"*.sh "$HOOKS_DIR/" 2>/dev/null || true
    fi
else
    if [ "$MODE" = "hooks-only" ]; then
        echo "Downloading hook scripts from GitHub..."
        curl -fsSL "$REPO_URL/skill/hooks/post-commit-brain.sh" -o "$HOOKS_DIR/post-commit-brain.sh"
        curl -fsSL "$REPO_URL/skill/hooks/session-start-brain.sh" -o "$HOOKS_DIR/session-start-brain.sh"
    else
        echo "Downloading from GitHub..."
        curl -fsSL "$REPO_URL/skill/SKILL.md" -o "$SKILL_DIR/SKILL.md"
        curl -fsSL "$REPO_URL/skill/SCHEMA.md" -o "$SKILL_DIR/SCHEMA.md"
        curl -fsSL "$REPO_URL/skill/DIAGNOSTICS.md" -o "$SKILL_DIR/DIAGNOSTICS.md"
        for page in index architecture decisions patterns history bugs topic; do
            curl -fsSL "$REPO_URL/skill/templates/${page}.md" -o "$SKILL_DIR/templates/${page}.md"
        done
        curl -fsSL "$REPO_URL/skill/templates/dashboard.html" -o "$SKILL_DIR/templates/dashboard.html"
        curl -fsSL "$REPO_URL/skill/hooks/post-commit-brain.sh" -o "$HOOKS_DIR/post-commit-brain.sh"
        curl -fsSL "$REPO_URL/skill/hooks/session-start-brain.sh" -o "$HOOKS_DIR/session-start-brain.sh"
    fi
fi

# Make hooks executable
chmod +x "$HOOKS_DIR/post-commit-brain.sh" 2>/dev/null || true
chmod +x "$HOOKS_DIR/session-start-brain.sh" 2>/dev/null || true

# CLAUDE.md only in full-install mode — hooks-only should not touch user's CLAUDE.md
if [ "$MODE" != "hooks-only" ]; then
    mkdir -p "$(dirname "$CLAUDE_MD")"
    touch "$CLAUDE_MD"

    BRAIN_BLOCK='# brain
- **brain** (`~/.claude/skills/brain/SKILL.md`) - per-repo project memory. Trigger: `/brain`
When the user types `/brain`, invoke the Skill tool with `skill: "brain"` before doing anything else.
When a repo has `.brain/` directory, read `.brain/index.md` for project context. When updating brain pages, read `.brain/SCHEMA.md` for format rules.'

    if grep -q "# brain" "$CLAUDE_MD" 2>/dev/null; then
        echo "brain entry already exists in $CLAUDE_MD"
    else
        echo "" >> "$CLAUDE_MD"
        echo "$BRAIN_BLOCK" >> "$CLAUDE_MD"
        echo "Added brain trigger to $CLAUDE_MD"
    fi
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
if [ "$MODE" = "hooks-only" ]; then
    echo "brain hooks reinstalled:"
    echo "  Hooks:    $HOOKS_DIR"
    echo "  Settings: $SETTINGS"
    echo ""
    echo "Restart your Claude Code session to activate."
else
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
    echo "     /brain doctor     Full diagnostic (integrity, format, content, sync)"
    echo ""
    echo "  3. Auto-update (hooks — just installed)"
    echo "     Session start:  Reads .brain/ automatically"
    echo "     After commit:   Checks for brain-worthy changes"
    echo ""
    echo "Restart your Claude Code session to activate."
fi
