---
type: topic
updated: 2026-04-18
---

# Hooks

## Overview

Brain's reliability layer. Two hooks — SessionStart and PostToolUse (on `git commit*`) — automate brain maintenance so it doesn't depend on the user remembering to run `/brain update`. SessionStart discovers (lists topic names, emits warnings, ~150-180 tokens); PostToolUse nudges the LLM to capture brain-worthy changes after every commit. Both are tier 3 (optional); without them, `/brain update` works manually.

## Timeline

- **2026-04-13** — Initial implementation. SessionStart reads `.brain/` for project context; PostToolUse nudges LLM after commits. See [[decisions.md#hooks-as-the-reliability-layer]].
- **2026-04-17** — SessionStart lists topic names in additionalContext for topic pages discovery. PostToolUse nudge extended to mention topic Timeline maintenance.
- **2026-04-18** — jq preflight + graceful hook degradation: hooks emit a static WARNING JSON via heredoc when jq is missing instead of failing silently. See [[decisions.md#jq-as-a-hard-dependency-with-graceful-degradation]].
- **2026-04-18** — Post-commit hook skips nudge for amend / merge / rebase / cherry-pick / revert commits (no session context about WHY for those operations). See [[history.md#fixed-7-issues-hardened-installhooksdoctordogfood]].

## Key Decisions

- [[decisions.md#hooks-as-the-reliability-layer]]
- [[decisions.md#jq-as-a-hard-dependency-with-graceful-degradation]]

## Related

- Features: [[features/doctor.md]] (doctor validates hook registration)
- Topics: [[topics/zero-install.md]] (hooks are tier 3; zero-install is tier 1)

## Current Status

Active. Hooks fire reliably, skip non-user-originated commits, gracefully degrade without jq. Hook scripts are symlinked into `~/.claude/hooks/` by install.sh and registered in `~/.claude/settings.json` via jq structural mutation (idempotent — re-running install doesn't duplicate).
