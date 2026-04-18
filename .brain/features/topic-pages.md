---
type: feature
updated: 2026-04-18
---

# Topic Pages

## Overview

`topics/*.md` is a cross-cutting narrative page type — one page per domain (subsystem, concept, recurring concern). Synthesizes events from decisions/bugs/history/features into a single Timeline ordered newest-first. Solves "the Redis story is scattered across 4 files and compaction broke the thread."

Inspired by Karpathy's LLM Wiki pattern. See [[decisions.md#topic-pages-as-the-karpathy-wiki-layer]] and [[topics/slugging.md]].

## Timeline

- **2026-04-17** — Initial implementation. New page type, `/brain topic <name>` command with create + `--sync` modes, `/brain update` Step 6 topic maintenance, dashboard rendering, session-start hook topic-name listing, post-commit nudge extension. See [[decisions.md#topic-pages-as-the-karpathy-wiki-layer]].
- **2026-04-18** — Hardened: `/brain topic` arg validation (rejects empty name, path separators, control chars); `--keywords "a,b,c"` flag for explicit synonym control; `--sync` dedupes against existing Timeline; write-time wikilink validation before appending bullets. See [[decisions.md#github-style-slug-algorithm-one-canonical-rule-reference-implementation-in-schema]].

## Current State

Active. Topic pages work end-to-end. Users create via `/brain topic <name>`, brain maintains Timelines automatically. Not compacted (they serve as canonical narrative across archive boundaries). Rendered in dashboard as one-card-per-page.

## Key Files

- `skill/SCHEMA.md` § `topics/*.md` content guidelines + decision tree
- `skill/SKILL.md` § Command: topic (create + --sync + --keywords)
- `skill/SKILL.md` § Command: update Step 6 (topic maintenance)
- `skill/templates/topic.md` — starter template
- `skill/templates/dashboard.html` — renderTopicCards() function
- `skill/hooks/session-start-brain.sh` — lists topic names in additionalContext

## Related

- Features: [[features/doctor.md]], [[features/dashboard.md]]
- Topics: [[topics/slugging.md]], [[topics/zero-install.md]]
