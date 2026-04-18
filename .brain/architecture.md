---
type: architecture
updated: 2026-04-18
---

# Architecture

brain is a three-tier system that gives any LLM coding tool project context via a `.brain/` directory shipped in git. Tiers build on each other; users can stop at any tier.

## Overview

```
 Tier 1 — Zero install (just git clone)
   repo has .brain/ + CLAUDE.md → any LLM reads SCHEMA.md, maintains brain

 Tier 2 — Power commands (/brain skill)
   ~/.claude/skills/brain/ → /brain init, update, query, doctor, topic, etc.

 Tier 3 — Auto-update (hooks)
   SessionStart hook: reads .brain/ on every session
   PostToolUse hook: nudges LLM after git commits
```

The key design idea: **the LLM is the maintainer**, the **schema is the spec**, and **git is the substrate**. The system deliberately avoids mechanical enforcement so it works across any LLM tool that reads the repo.

See [[decisions.md#adopted-three-tier-architecture]] and [[ARCHITECTURE.md]] for the full rationale.

## System Components

### install.sh
Bootstrap script. Places skill files at `~/.claude/skills/brain/`, hook scripts at `~/.claude/hooks/`, registers hooks in `~/.claude/settings.json` via jq, appends a block to `~/.claude/CLAUDE.md`. Preflight-checks jq; offers to install it per platform if missing.

### skill/ (shipped to `~/.claude/skills/brain/`)
- **SKILL.md** — command specs. Claude Code reads this when the user types `/brain`.
- **SCHEMA.md** — authoritative format rules (frontmatter, slug algorithm, merge guidance, compaction, page types). Copied into each repo on `/brain init`.
- **DIAGNOSTICS.md** — doctor playbook; only loaded when `/brain doctor` runs.
- **templates/** — starter pages: index, architecture, decisions, patterns, history, bugs, topic + dashboard.html.

### skill/hooks/
- **session-start-brain.sh** — on every Claude Code session in a `.brain/` repo, emits JSON to tell the LLM brain exists + lists topic names.
- **post-commit-brain.sh** — after `git commit*`, nudges LLM to check session for brain-worthy changes. Skips amend/merge/rebase/cherry-pick/revert commits.

### .brain/ (per-repo)
- 7 core pages (index, architecture, decisions, patterns, history, bugs + features/) created by `/brain init`.
- `topics/` (user-created, cross-cutting narrative).
- `archive/` (compacted old entries).
- `custom/` (team-defined reference docs).
- `SCHEMA.md` (copied from skill on init).

## Data Flow

```
 User writes code
      │
      ▼
 git commit
      │
      ▼
 PostToolUse hook fires ────────► nudge to LLM
      │
      ▼
 LLM runs /brain update:
   1. Read git diff (code changes)
   2. Filter for significance
   3. Categorize (feature/bug/decision/pattern/architecture)
   4. Extract WHY from session conversation (5 event types)
   5. Write to event-type pages + relevant feature pages
   6. Update topic page Timelines (with write-time wikilink validation)
   7. git add .brain/ && git commit
      │
      ▼
 Next session: SessionStart hook reads .brain/ again
```

## Infrastructure

- **Hosting:** none — brain is client-side only. `.brain/` lives in whatever git remote the repo uses.
- **Dependencies:** bash, git, jq, Claude Code (or another LLM tool).
- **No services, no databases, no servers.** Plain markdown files + shell scripts.

## External Integrations

- **Claude Code** — primary target. Skill + hooks mechanism.
- **Cursor** — works via `.cursor/rules` pointing at `.brain/SCHEMA.md`.
- **Codex** — works via `AGENTS.md` pointing at `.brain/SCHEMA.md`.
- **GitHub Actions** — optional auto-review PR hook (user-configured, not bundled).

See [[topics/hooks.md]] for how hooks wire into the reliability story.
