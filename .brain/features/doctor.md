---
type: feature
updated: 2026-04-18
---

# /brain doctor

## Overview

`/brain doctor` diagnoses a `.brain/` directory against the rules in SCHEMA.md. Rewritten from a 360-line phased script into a ~75-line reasoning spec that reads SCHEMA.md + DIAGNOSTICS.md at runtime and builds findings based on invariant violations.

## Timeline

- **2026-04-16** — Rewrote from phased script to reasoning spec. DIAGNOSTICS.md created as the skill-local playbook (loaded only when doctor runs). Auto-fix whitelist pinned to exactly 2 items (restore SCHEMA.md, re-register hooks). See [[decisions.md#reasoning-based-doctor-not-a-script]].
- **2026-04-17** — Added invariants for topic pages (empty Timeline WARNING) and archive-slug wikilink recovery hint. Added jq-missing Installation invariant.
- **2026-04-18** — Added three more content invariants: compaction threshold warning (≥30 entries / ≥150 lines), updated: vs max entry-date check, type: vs filename match (strict ERROR). Also added structural invariant mapping each path to its canonical type.

## Current State

Active. Doctor runs as a reasoning task, not a script. Invariants cite SCHEMA sections rather than duplicating rules. Auto-fix whitelist remains intentionally tiny. Never auto-edits brain content.

## Key Files

- `skill/SKILL.md` § Command: doctor (~75-line reasoning spec)
- `skill/DIAGNOSTICS.md` — the playbook: Phase 0 env probe, invariants, recovery table, auto-fix whitelist

## Related

- Features: [[features/topic-pages.md]], [[features/dashboard.md]]
- Topics: [[topics/hooks.md]]
