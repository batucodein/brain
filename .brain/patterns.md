---
type: patterns
updated: 2026-04-18
---

# Patterns

## Bash hooks — read stdin JSON, emit stdout JSON

Claude Code hooks communicate via JSON on stdin/stdout. All brain hooks follow this pattern:

1. `read -r input_json` → consume one line of input from Claude Code
2. Extract fields via `jq -r '.cwd // empty'`
3. Do work
4. Emit a single JSON object with `{"hookSpecificOutput": {"hookEventName": ..., "additionalContext": ...}}`

Graceful exit-without-output (`exit 0` with no stdout) is valid — Claude Code treats no output as "no context to inject."

## jq —arg, never string concat

Never construct JSON by concatenating shell variables. Always pass values to jq via `--arg`:

```bash
# ✓ SAFE
jq -n --arg topics "$TOPIC_NAMES" '{additionalContext: ("topics: " + $topics)}'

# ✗ FRAGILE (breaks on quotes/newlines in the variable)
echo "{\"additionalContext\": \"topics: $TOPIC_NAMES\"}"
```

## SCHEMA.md citation pattern (cite-don't-duplicate)

DIAGNOSTICS.md invariants cite SCHEMA sections rather than copying their text. Format:

```markdown
- Every `**Date:**` matches `^\d{4}-\d{2}-\d{2}$`. *(SCHEMA.md § Date Format)*
```

This means when SCHEMA evolves, DIAGNOSTICS doesn't need edits — it points at the rule rather than duplicating it.

## Heredoc for static JSON fallbacks

When jq isn't available (fallback path), emit JSON via heredoc with single-quoted delimiter so no shell interpolation happens:

```bash
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"brain: WARNING — jq missing..."}}
EOF
```

Single-quoted `'EOF'` prevents `$variable` expansion inside the block, so the JSON stays literal.

## Naming: kebab-case filenames, full-word directories

- `session-start-brain.sh` (kebab-case file)
- `hooks/` (plural directory, short)
- `skill/templates/` (full word, plural)

Matches GitHub repo conventions. Contrast: SCHEMA page types use lowercase singular (`feature`, `topic`, `decision`) because they're enum values, not directory names.

## Test pattern: temp dir + PATH manipulation

End-to-end shell tests create a temp dir, set `HOME=$TMPHOME` or `PATH=$TMPBIN`, run the script, assert on stdout + settings.json:

```bash
TMPHOME=$(mktemp -d)
export HOME="$TMPHOME"
./install.sh 2>&1 | grep -A5 "expected string"
rm -rf "$TMPHOME"
```

For "simulate jq missing," create a temp dir with symlinks to coreutils but NOT to jq, then `PATH=$TMPBIN`.
