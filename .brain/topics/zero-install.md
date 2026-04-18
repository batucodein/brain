---
type: topic
updated: 2026-04-18
---

# Zero-Install

## Overview

The foundational design principle that makes brain work across any LLM tool: a repo with `.brain/` plus a pointer in `CLAUDE.md`/`.cursor/rules`/`AGENTS.md` is self-sufficient. Any LLM that reads the instruction file finds the pointer to `.brain/SCHEMA.md` and can maintain brain with nothing installed on the user's machine. Skill + hooks are optional polish layers.

## Timeline

- **2026-04-11** — Initial release establishes the zero-install model as the core constraint. See [[decisions.md#zero-install-model-as-the-foundation]].
- **2026-04-12** — Three-tier architecture formalizes zero-install as Tier 1, with skill + hooks as optional Tier 2 and Tier 3. See [[decisions.md#adopted-three-tier-architecture]].
- **2026-04-18** — Accepted "LLM-as-enforcer drift" as a design trade-off. Strict mechanical enforcement would break zero-install (would require every LLM tool to agree on a linter). Documented in ARCHITECTURE.md §8.2.

## Key Decisions

- [[decisions.md#zero-install-model-as-the-foundation]]
- [[decisions.md#adopted-three-tier-architecture]]
- [[decisions.md#reasoning-based-doctor-not-a-script]]

## Related

- Features: [[features/topic-pages.md]], [[features/doctor.md]], [[features/dashboard.md]]
- Topics: [[topics/slugging.md]], [[topics/hooks.md]]

## Current Status

Active and foundational. Every design decision for brain is tested against "does this preserve zero-install?" If a proposed change would require machine-side installation to work, it's rejected or moved to Tier 2/3.
