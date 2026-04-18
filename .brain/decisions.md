---
type: decisions
updated: 2026-04-18
---

# Decisions

## Organic-archive-discovery via SCHEMA guidance, not session-start listing
**Date:** 2026-04-18
**Context:** Archive-discovery guidance existed for 3 paths (`/brain query` ranking, wikilink resolution fallback, doctor invariant) but was absent for ORGANIC conversation — a user asking "what was the X thing years ago?" without typing `/brain query` had no trigger to make the LLM check archive. Gap surfaced during architecture walkthrough.
**Decision:** Add one bullet to SCHEMA § At Session Start telling the LLM to check `.brain/archive/*.md` when the user's question touches events older than active pages' date range. ~50 tokens in SCHEMA, paid per `/brain update` only — session-start hook unchanged.
**Alternatives considered:**
- A: accept the gap, document "use `/brain query` for old events" — rejected, user may not know to switch to the command
- B: list archive filenames in session-start hook — rejected, ~20-50 tokens per session is a permanent tax for a rare case
- D: strengthen the "> Older entries archived in..." pointer line in each active page — rejected, only works if LLM reads that specific page
**Constraint that shaped the choice:** session-start token budget is every-session; SCHEMA growth is per-update. C is cheaper over time for the same outcome.
**Status:** Active. Refinement of [[decisions.md#sharpen-judgment-via-prompting-dont-formalize-it]] — another case of "add judgment guidance, don't add a rule."

## Sharpen judgment via prompting, don't formalize it
**Date:** 2026-04-18
**Context:** After shipping the deterministic layer (slug algorithm, hook skip conditions, doctor invariants, idempotent install, etc.), the next natural step looked like "find more places to make deterministic." But continuing to formalize would cross into dumbing — replacing LLM judgment where judgment is the whole value (event categorization, WHY extraction, topic scope matching, Timeline caption writing).
**Decision:** Stop pushing deterministic rules. Instead invest in **prompting** — better context at decision points (conditional reads), reasoning examples (not verdicts to match), explicit partial-WHY option, confidence-gated prompts that merge instead of double-prompting. All additive to SCHEMA.md and SKILL.md; zero session-start cost change.
**Alternatives considered:** Keep mining for deterministic wins (rejected — remaining candidates all crossed into judgment territory); add a strict-mode pre-commit linter (rejected — breaks the zero-install tier).
**Rule that falls out:** judgment goes in the LLM, rules go in the substrate, examples teach reasoning. Test: "could a bash/jq/regex script produce the right answer from structural inputs alone?" → yes → rule. No → LLM. See [[features/doctor.md]] (deterministic substrate) and [[topics/zero-install.md]] (the constraint that forces this split).
**Status:** Active

## Adopted three-tier architecture
**Date:** 2026-04-12
**Context:** Needed to support users who range from "just clone a repo and read .brain/" all the way to "full auto-maintained brain." A single install mode would either over-install for casual users or under-deliver for power users.
**Decision:** Three tiers — zero install (just git clone), skill install (power commands), hooks install (auto-update). Each tier builds on the previous; users can stop at any tier.
**Alternatives considered:** Monolithic install (every user gets everything — rejected, too heavy); npm/brew package (ties brain to a package manager — rejected, raises install friction).
**Status:** Active

## Zero-install model as the foundation
**Date:** 2026-04-12
**Context:** Wanted brain to work across Claude Code, Cursor, Codex — any LLM tool that reads a platform instruction file. A Claude-Code-only solution would ghetto-ize the tool.
**Decision:** Ship `.brain/SCHEMA.md` inside every brain-enabled repo. Any LLM that reads CLAUDE.md / .cursor/rules / AGENTS.md finds the pointer to SCHEMA.md and can maintain brain with nothing installed on the user's machine. See [[topics/zero-install.md]].
**Alternatives considered:** Claude-Code-only skill (rejected, segregates users); cloud-hosted brain (rejected, privacy + always-online concerns).
**Status:** Active

## Topic pages as the "Karpathy wiki" layer
**Date:** 2026-04-17
**Context:** Brain's pages were sliced by event type (decisions/bugs/history). A domain's narrative (e.g., "the Redis subsystem") was scattered across 3+ files. Compaction made it worse — archived entries broke the thread. See [[features/topic-pages.md]].
**Decision:** Add `topics/<name>.md` — cross-cutting narrative synthesis inspired by Karpathy's LLM Wiki pattern. Creation is user-initiated (`/brain topic redis`) to prevent weak/sticky topics. Timeline bullets are wikilinks only (event pages stay authoritative). Topics aren't compacted — they span archive boundaries.
**Alternatives considered:** Layered back-pointers on archive (rejected — traversal beats synthesis); per-entry files (rejected — too much restructure).
**Status:** Active

## Reasoning-based doctor (not a script)
**Date:** 2026-04-16
**Context:** The first `/brain doctor` was a 360-line phased script with hard-coded buckets (AUTO/MANUAL/REVIEW). It grew quickly and became a maintenance liability.
**Decision:** Replace with a ~75-line reasoning spec that reads SCHEMA.md + DIAGNOSTICS.md at runtime. Doctor becomes an LLM task: walk invariants, build findings, render report, offer tiny auto-fix whitelist. The playbook moves to DIAGNOSTICS.md (skill-local, not shipped per-repo).
**Alternatives considered:** Keep growing the script (rejected); remove doctor entirely (rejected, drift needs a catcher).
**Status:** Active

## GitHub-style slug algorithm (one canonical rule, reference implementation in SCHEMA)
**Date:** 2026-04-18
**Context:** Wikilinks rely on anchor slugs (`## Header Text` → `#header-text`). The original SCHEMA had 2 informal examples — different LLMs could slug special characters (em-dash, backticks, colons, unicode) inconsistently, breaking links silently across sessions/tools.
**Decision:** Spec the slug algorithm formally in SCHEMA § Anchor Slug Algorithm, including a Python reference implementation and 10 worked examples. GitHub-compatible rules (lowercase, delete punctuation, preserve Unicode letters, whitespace→hyphen, collapse, trim). See [[topics/slugging.md]].
**Alternatives considered:** Leave prose-only (rejected — too permissive); write a stricter custom rule (rejected — predictability matters more than cleanliness).
**Status:** Active

## Hooks as the reliability layer
**Date:** 2026-04-13
**Context:** Brain maintenance couldn't rely on user memory ("remember to run /brain update after every commit"). Drift was inevitable without automation.
**Decision:** SessionStart hook tells LLM brain exists on every session (~150 tokens, discovery-not-loading). PostToolUse hook nudges LLM after every `git commit*` to check for brain-worthy changes. Hooks are tier 3 (optional) — without them, user can still run `/brain update` manually. See [[topics/hooks.md]].
**Alternatives considered:** Mandatory hooks (rejected, too invasive); IDE plugin (rejected, ties brain to one tool).
**Status:** Active

## jq as a hard dependency with graceful degradation
**Date:** 2026-04-18
**Context:** Hooks emit JSON to Claude Code; install.sh mutates ~/.claude/settings.json. Both need reliable JSON handling. Before the preflight fix, missing jq meant install silently produced a partial state and hooks silently failed.
**Decision:** Three-layer defense: install.sh preflight (offer to install jq via detected package manager, exit 1 if declined or unavailable); hooks have a static JSON fallback that shows a WARNING when jq is missing; doctor flags jq-missing as an Installation ERROR.
**Alternatives considered:** Replace jq with hand-rolled JSON (rejected — fragile escape handling); make jq optional (rejected — silent failures are worse).
**Status:** Active
