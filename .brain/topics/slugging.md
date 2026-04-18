---
type: topic
updated: 2026-04-18
---

# Slug Algorithm

## Overview

The rule that converts a `##`/`###` Markdown header to a wikilink anchor (e.g., `## Chose Redis` → `#chose-redis`). Foundational because every wikilink in brain relies on it producing the same output across every LLM session and every tool. Originally prose-only (2 examples); now formally specified with a Python reference implementation and 10 worked examples.

## Timeline

- **2026-04-11** — Initial informal rule in SCHEMA: "lowercase, spaces→hyphens, strip punctuation." Two examples.
- **2026-04-17** — Identified as issue #11 during architectural audit: LLMs could disagree on edge cases (em-dash, backticks, colons, unicode).
- **2026-04-18** — Full GitHub-compatible algorithm specified with Python reference implementation in SCHEMA.md § Anchor Slug Algorithm. 10 worked examples cover em-dash, colons, backticks, slashes, digits, unicode (Turkish chars), symbols. See [[decisions.md#github-style-slug-algorithm-one-canonical-rule-reference-implementation-in-schema]].

## Key Decisions

- [[decisions.md#github-style-slug-algorithm-one-canonical-rule-reference-implementation-in-schema]]

## Related

- Features: [[features/topic-pages.md]], [[features/doctor.md]]
- Topics: [[topics/zero-install.md]]

## Current Status

Active. Slug algorithm is one of the few rules in brain with a formal reference implementation in SCHEMA — because it HAS to be deterministic across tools for wikilinks to resolve. Doctor's wikilink invariant (SCHEMA.md § Linking) uses this algorithm; `/brain update` Step 6 validates wikilinks at write-time using it.
