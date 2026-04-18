---
type: history
updated: 2026-04-18
---

# History

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
