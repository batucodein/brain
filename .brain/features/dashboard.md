---
type: feature
updated: 2026-04-18
---

# /brain dashboard

## Overview

`/brain dashboard` generates an interactive HTML dashboard at `.brain/dashboard.html` — standalone HTML with embedded JSON (no server needed), showing all brain entries organized by category with search and date sorting.

## Timeline

- **2026-04-11** — Initial dashboard implementation with History, Decisions, Features, Bugs, Patterns, Architecture categories.
- **2026-04-17** — Added Topics category with `renderTopicCards()` — one card per topic (not flattened per Timeline bullet). Topic-specific color and sidebar nav.
- **2026-04-18** — Added Custom category with `renderCustomCards()`. Deleted orphan `graph.html` template (associated `/brain graph` command was removed). COUNT_KEYS lookup generalized.

## Current State

Active. Dashboard renders 7 sections: Overview, History, Decisions, Features, Topics, Custom, Bugs, Patterns, Architecture. Standalone HTML file, gitignored (regenerated on demand).

## Key Files

- `skill/SKILL.md` § Command: dashboard (parsing rules + JSON shape + render instructions)
- `skill/templates/dashboard.html` — the template with `{{BRAIN_JSON}}` placeholder

## Related

- Features: [[features/topic-pages.md]], [[features/doctor.md]]
- Topics: [[topics/zero-install.md]]
