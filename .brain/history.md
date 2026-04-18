---
type: history
updated: 2026-04-18
---

# History

## README scoped down — Claude Code only, format stays tool-agnostic
**Date:** 2026-04-19
Removed unverified multi-tool claims from README. Cursor and Codex were listed in Platform Support and the Tier 1 description, but brain has only ever been tested on Claude Code. Now: explicit status banner ("Supported on Claude Code only"), Prerequisites lists Claude Code first, Platform Support section labels `.cursor/rules` and `AGENTS.md` paths as "speculative hooks for future multi-tool support, untested." The `/brain init` code still writes to those files if they exist — the hook remains, just no longer claimed as a supported feature. See [[decisions.md#scoped-support-to-claude-code-only-format-stays-tool-agnostic]].

## Closed organic-archive-discovery gap via SCHEMA guidance
**Date:** 2026-04-18
Added one bullet to SCHEMA § At Session Start telling the LLM to check `.brain/archive/*.md` when a question touches events older than active pages' date range. Closes the gap where organic conversation (no `/brain query`) wasn't guided to archive. Picked SCHEMA-side (per-update cost) over session-start listing (per-session cost) — better trade for a rare use case. See [[decisions.md#organic-archive-discovery-via-schema-guidance-not-session-start-listing]].

## Prompting pass — sharpened LLM judgment without formalizing it
**Date:** 2026-04-18
Added 9 prompting changes across SCHEMA.md and SKILL.md (~1150 combined token growth, ~5% each). Closes issue #3 (session-compaction WHY loss) via proactive-flush guidance. SCHEMA now has: confidence-gated categorization in Step 3 with reasoning examples (ORM swap = decision; middleware scope change = architecture), partial-WHY marker `[partial — ...]` as an explicit option alongside ask/placeholder, conditional richer reads on topic-scope matching (only read recent Timeline if Overview is abstract), wikilink target disambiguation (prefer newest anchor on multi-match), stricter topic-creation threshold (across multiple sessions), Timeline caption quality guidance ("name the lever that moved"). SKILL.md /brain decide/bug/history now run both duplicate and category-mismatch checks, merged into ONE y/N prompt instead of two. See [[decisions.md#sharpen-judgment-via-prompting-dont-formalize-it]].

## Fixed 7 issues + hardened install/hooks/doctor/dogfood
**Date:** 2026-04-18
Major cleanup pass on top of v2 (topic pages). Closed #6, #7, #8, #9, #11, #12, #13, #14, #15, #16, #17, #18, #19, #20, #21, #22, #23, #24, #25, #26, #27, #28, #29. SCHEMA gains formal slug algorithm with reference impl, merge Case 4 for add+add on topic pages, archive sub-split guidance, decision supersession rule, feature removal rule, types decision tree. Install.sh hardens with jq-structural idempotency and CLAUDE.md drift detection. Post-commit hook skips amend/merge/rebase/cherry-pick/revert. Doctor gains compaction-threshold + updated-vs-date + type-vs-filename invariants plus write-time wikilink validation in /brain update Step 6. Dashboard renders custom/*.md. graph.html orphan deleted. brain now dogfoods itself (this .brain/ directory).

## Shipped jq preflight + graceful degradation
**Date:** 2026-04-18
Closed #15 (original backlog). Install.sh now preflight-checks for jq; offers to install via detected package manager (brew / apt / dnf / pacman). Hooks have a static-JSON fallback that shows a visible WARNING when jq is missing. Doctor flags missing jq as an Installation ERROR. README gains Prerequisites section.

## Shipped topic pages v1
**Date:** 2026-04-17
Added `topics/*.md` — cross-cutting narrative synthesis inspired by Karpathy's LLM Wiki. New `/brain topic <name>` command for explicit creation. /brain update Step 6 maintains topic Timelines automatically on matching events. /brain query ranks topics alongside features. Dashboard renders topics as one-card-per-page. Session-start hook lists topic names. Post-commit nudge mentions topic maintenance. See [[features/topic-pages.md]] and [[topics/slugging.md]] for details. First architectural documentation shipped at ARCHITECTURE.md (~1250 lines).

## Shipped v2.0 — three-tier architecture
**Date:** 2026-04-12
Rewrote brain around the zero-install → skill → hooks tiered model. SCHEMA.md became self-contained (any LLM that reads it can maintain brain). install.sh + settings.json registration automate the skill + hooks tier. See [[decisions.md#adopted-three-tier-architecture]].

## Initial release
**Date:** 2026-04-11
Per-repo `.brain/` directory tracked in git. Core pages: index, architecture, decisions, patterns, history, bugs, features/. Wikilink cross-referencing. `/brain` command surface. Inspired by Karpathy's LLM Wiki pattern.
