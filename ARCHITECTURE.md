# brain — Architecture

> **Status:** v1 (topic pages shipped 2026-04-17). First architectural documentation.
> **Audience:** contributors, integrators, and future-you trying to remember why it works this way.
> **Scope:** every flow, every file, every cross-cutting concern, and an honest audit of what's still broken.

---

## Table of Contents

0. [How to read this doc](#0-how-to-read-this-doc)
1. [The mental model](#1-the-mental-model)
2. [Three-tier architecture](#2-three-tier-architecture)
3. [File layout (everywhere)](#3-file-layout-everywhere)
4. [Data model](#4-data-model)
5. [Command flows (11)](#5-command-flows-11)
6. [Hook flows (2)](#6-hook-flows-2)
7. [Cross-cutting concerns](#7-cross-cutting-concerns)
8. [Integrity analysis](#8-integrity-analysis)
9. [Edge cases catalog](#9-edge-cases-catalog)
10. [Issues found (audit)](#10-issues-found-audit)
11. [Glossary](#11-glossary)

---

## 0. How to read this doc

Each major section follows a consistent shape:

- **Purpose** — why it exists in one sentence
- **Flow diagram** — ASCII, trigger → state changes
- **Invariants** — what must hold true
- **Risks** — what breaks this

If you're debugging, jump to §10 first — that's the issue punch list. If you're onboarding, read §1–4 sequentially. If you're implementing a new command, read §5 as a template.

ASCII diagrams use these conventions:

```
┌─────┐        box = file, state, or actor
│  X  │
└─────┘

  ─►            synchronous call / data flow
  ═►            persistent state change (write to disk)
  ┄►            asynchronous / hook-triggered

  ✓             succeeded
  ✗             failed (hard)
  ⚠             succeeded with caveat (soft)
```

---

## 1. The mental model

brain is **per-repo LLM project memory** that travels with git. It captures the **WHY** behind code decisions so that any developer (or LLM) who clones the repo inherits full project context.

```
          Without brain                           With brain
          ─────────────                           ──────────

   Three months later:                   Three months later:
   "Why is auth custom?"                 "Why is auth custom?"
             │                                     │
             ▼                                     ▼
   Slack archaeology. 🗑                     Read .brain/decisions.md
   Ask the one person                       Follow [[features/auth.md]]
   who remembers                            Follow [[bugs.md#...]]
   (if they're still here)                  Have full answer in 30s.
```

**Core idea:** the LLM maintains the wiki; humans direct it. The LLM doesn't get bored updating cross-references. Humans stay focused on the work.

**Three things brain is NOT:**
- Not a ticket system (no assignees, no open/closed states)
- Not a replacement for README (which explains *how to set up*; brain explains *why things are the way they are*)
- Not documentation (which must be comprehensive; brain is *just enough context* to answer common questions)

---

## 2. Three-tier architecture

Each tier builds on the previous. Users can stop at any tier.

```
┌─────────────────────────────────────────────────────────────────┐
│  Tier 1 — Zero install (just git clone)                          │
│                                                                  │
│    Repo has .brain/ directory + CLAUDE.md pointer to SCHEMA.md  │
│    Any LLM that reads CLAUDE.md can maintain brain via the      │
│    instructions inside SCHEMA.md. Nothing to install.           │
│                                                                  │
│    Works: reading brain, manual edits                            │
│    Does not work: /brain commands, auto-update                   │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │  user runs install.sh
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Tier 2 — Power commands (/brain skill)                          │
│                                                                  │
│    install.sh places the skill at ~/.claude/skills/brain/       │
│    User types /brain init, /brain update, /brain topic, etc.    │
│                                                                  │
│    Adds: 11 commands (init, status, update, decide, bug,        │
│           history, topic, query, dashboard, doctor, uninstall)  │
│    Still manual: user has to type the commands                   │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │  install.sh also registers hooks
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Tier 3 — Auto-update (hooks)                                    │
│                                                                  │
│    SessionStart hook: reads .brain/ on every Claude session     │
│    PostToolUse hook (on `git commit`): nudges LLM to update     │
│                                                                  │
│    Adds: zero-effort maintenance across sessions                │
│    brain self-maintains; developer just writes code             │
└─────────────────────────────────────────────────────────────────┘
```

### Why tiered?

- **Tier 1** means a repo with `.brain/` works everywhere (Cursor, Codex, Copilot) even if they've never heard of brain. The "skill" is optional polish for Claude Code users.
- **Tier 2** is the ergonomic layer. Users don't have to know SCHEMA.md by heart.
- **Tier 3** is the reliability layer. Without it, maintenance relies on user memory.

---

## 3. File layout (everywhere)

brain touches three distinct filesystem locations. Confusing these is the #1 source of debugging pain.

### 3.1 The repo (`./<repo>/.brain/`) — the data

Tracked in git. Travels with the code.

```
.brain/
├── SCHEMA.md          ← shipped in git; LLM instructions + format spec
├── index.md           ← project overview (description, tech stack, team)
├── architecture.md    ← system structure, components, data flow
├── decisions.md       ← append-only log of architectural decisions, newest first
├── patterns.md        ← coding conventions (error handling, naming, testing)
├── history.md         ← append-only timeline of significant changes
├── bugs.md            ← append-only notable bugs with root cause + fix
├── features/          ← one page per significant feature (lifecycle)
│   └── webhook-delivery.md
├── topics/            ← NEW (v1): cross-cutting narrative synthesis
│   └── redis.md
├── archive/           ← compacted old entries from history/decisions/bugs
│   └── history-2024.md
├── custom/            ← team-defined pages
│   └── onboarding.md
└── dashboard.html     ← generated by /brain dashboard (gitignored)
```

### 3.2 The skill (`~/.claude/skills/brain/`) — the intelligence

Installed per-user. Same content across all repos on a machine.

```
~/.claude/skills/brain/
├── SKILL.md          ← /brain command specs (invoked by Claude Code)
├── SCHEMA.md         ← source of truth for format rules (copied to .brain/ on init)
├── DIAGNOSTICS.md    ← /brain doctor playbook (skill-local, not shipped to repos)
└── templates/
    ├── index.md
    ├── architecture.md
    ├── decisions.md
    ├── patterns.md
    ├── history.md
    ├── bugs.md
    ├── topic.md       ← NEW (v1)
    └── dashboard.html
```

### 3.3 Hooks and config (`~/.claude/`)

```
~/.claude/
├── hooks/
│   ├── post-commit-brain.sh    ← fires after Bash("git commit*")
│   └── session-start-brain.sh  ← fires on SessionStart
├── settings.json               ← registers the two hooks above
└── CLAUDE.md                   ← global LLM instructions (install.sh appends a brain block)
```

### 3.4 The three locations, visually

```
 ┌────────────────────────────────────┐     ┌────────────────────────────────────┐
 │  REPO (tracked in git)             │     │  MACHINE (per-user, ~/.claude/)   │
 │                                    │     │                                    │
 │  .brain/                           │     │  skills/brain/                    │
 │    SCHEMA.md ─── copied from ─────────────┼── SCHEMA.md (authoritative)      │
 │    index.md ... etc.               │     │  hooks/*.sh (fire on events)     │
 │                                    │     │  settings.json (hook registry)   │
 │  CLAUDE.md ─── points to SCHEMA ───┘     │  CLAUDE.md (points to SKILL.md)  │
 │                                           │                                    │
 └────────────────────────────────────┘     └────────────────────────────────────┘
                │                                          ▲
                └── git push ──► teammates ──► git clone ──┘
                                                  │
                     (teammates get the REPO side; MACHINE side
                     is their own install — same skill, different hooks config)
```

---

## 4. Data model

### 4.1 Page types

Nine types total (after v1). Each page in `.brain/` declares its type in frontmatter.

| Type           | Location        | Ordering        | Compactable? |
|----------------|-----------------|-----------------|--------------|
| `index`        | `index.md`      | n/a (prose)     | no           |
| `architecture` | `architecture.md` | n/a (prose)   | no           |
| `decisions`    | `decisions.md`  | newest first    | **yes**      |
| `patterns`     | `patterns.md`   | n/a (prose)     | no           |
| `history`      | `history.md`    | newest first    | **yes**      |
| `bugs`         | `bugs.md`       | newest first    | **yes**      |
| `feature`      | `features/*.md` | Timeline newest first | no (usually) |
| `topic`        | `topics/*.md`   | Timeline newest first | **NO** — topic pages are the canonical narrative across archive boundaries |
| `custom`       | `custom/*.md`   | user's choice   | no           |
| `archive`      | `archive/*.md`  | (frozen)        | no (already archived) |

### 4.2 Frontmatter

Every `.brain/*.md` starts with:

```yaml
---
type: <one of the 9 page types>
updated: YYYY-MM-DD
---
```

Both fields are **required**. `updated:` must match `^\d{4}-\d{2}-\d{2}$` (zero-padded YYYY-MM-DD). Missing or malformed → doctor flags as ERROR.

### 4.3 Wikilinks

```
[[page.md]]                             # link to page
[[page.md#section-anchor]]              # link to section within page
[[features/webhook-delivery.md]]        # features subfolder
[[topics/redis.md]]                     # topics subfolder
[[archive/decisions-2024.md#anchor]]    # archived content
```

**Anchor slug algorithm** (specified in prose at SCHEMA.md § Anchor Format):

```
Input:   "## Chose Redis Queue for Webhooks"
Slug:    "chose-redis-queue-for-webhooks"

Rules:
  1. Take the header text (after ##/###)
  2. Lowercase everything
  3. Replace spaces with hyphens
  4. Strip punctuation (. , ? ! : ; etc.)

NOTE: Not formally defined for special chars like em-dash, em-dash,
     code backticks, forward slashes. Two LLMs may slug differently.
     See Issue #11 in §10.
```

Wikilinks are **one-way**. No backlink index today. Doctor validates forward resolution only.

### 4.4 The 5 event types (the WHY capture model)

The LLM watches conversation for these five moments. Each moment that actually happened is "brain-worthy":

```
 1. A CHOICE was made          — Multiple approaches existed, one picked.
 2. Something BROKE and was understood — Symptom → investigation → root cause → fix.
 3. Something was REJECTED     — Approach proposed, turned down or tried and failed.
 4. A CONSTRAINT shaped work   — Performance, cost, time, compat steered the impl.
 5. The system changed STRUCTURALLY — New component, integration, or dependency.
```

These feed into specific pages:

```
 Event type              → Page that captures it
 ──────────                 ─────────────────────
 1. CHOICE                 → decisions.md
 2. BROKE & understood     → bugs.md
 3. REJECTED               → decisions.md (as "alternatives considered")
 4. CONSTRAINT             → decisions.md (as context) or patterns.md
 5. STRUCTURAL             → architecture.md + history.md (+ maybe features/X.md)

 And ALL of the above, if they touch a domain with a topic page,
 also update topics/<name>.md Timeline with a wikilink pointer.
```

---

## 5. Command flows (11)

Each flow is documented as: **trigger → reads → decisions → writes → output**.

### 5.1 `/brain init` — bootstrap `.brain/`

**Purpose.** Create `.brain/` for an existing repo by analyzing the code.

```
 User: /brain init
       │
       ▼
 Step 1 — check existence
       │
       ├── .brain/index.md exists? → tell user "already init'd", stop.
       │
       ▼
 Step 2 — analyze repo (READ-ONLY, extensive)
       │
       ├── Read README, package.json/go.mod/etc., docker-compose
       ├── Read source tree (entry points → handlers → services → DB)
       ├── Read git log (tags, feature commits, bug-fix commits)
       └── Build mental model of the project
       │
       ▼
 Step 3 — generate pages
       │
       ├── mkdir -p .brain/custom .brain/features .brain/topics .brain/archive
       ├── cp ~/.claude/skills/brain/SCHEMA.md .brain/SCHEMA.md
       ├── Generate index.md         (from README + structure)
       ├── Generate architecture.md  (from actual code analysis, NOT folders)
       ├── Generate decisions.md     (extract from ADRs, README "chose" language)
       ├── Generate patterns.md      (infer from code: error handling, naming)
       ├── Generate history.md       (from git tags + significant commits)
       ├── Generate bugs.md          (from git log --grep=fix|bug|crash)
       ├── Generate features/*.md   (one per major feature, Timeline from git log)
       │
       └── DO NOT generate topics/*.md  ← topics are user-initiated only
       │
       ▼
 Step 4 — install platform integration
       │
       └── Create or append CLAUDE.md / .cursor/rules / AGENTS.md with pointer to SCHEMA.md
       │
       ▼
 Step 5 — offer auto-update hooks
       │
       └── Ask user: "want session-start and post-commit hooks?" (y/n)
       │
       ▼
 Step 6 — git commit
       │
       ├── git add .brain/ CLAUDE.md
       └── git commit -m "brain: initialize project memory"
       │
       ▼
 Step 7 — summary (tell user what was created)
```

**Invariants after init:**
- `.brain/` directory exists with 7 core pages + empty topics/, features/, archive/, custom/ dirs.
- `.brain/SCHEMA.md` is a copy of `~/.claude/skills/brain/SCHEMA.md`.
- `CLAUDE.md` (or equivalent) references `.brain/SCHEMA.md`.
- A single commit captures everything.

**Risks:**
- If `~/.claude/skills/brain/SCHEMA.md` is missing, init halts. User must reinstall.
- If the LLM misreads the code (e.g., guesses architecture from folder names), the generated pages will be wrong. Hence the repeated `NOT from folder names` guard in SKILL.md.
- **Issue #8**: install.sh also writes a brain block to `~/.claude/CLAUDE.md`. If `/brain init` separately writes to repo-local `CLAUDE.md`, the two blocks drift. Unresolved.

---

### 5.2 `/brain status` — snapshot of `.brain/`

**Purpose.** Quick read-only summary of what brain contains and how fresh it is.

```
 User: /brain status
       │
       ▼
 Read all .brain/ pages → extract frontmatter `updated:` dates
       │
       ▼
 Output:
   .brain/ exists (init'd 2026-01-15)
     index.md        updated 2026-04-16  ✓ fresh
     decisions.md    4 entries, last 2026-04-10
     bugs.md         2 entries, last 2026-04-12
     history.md      8 entries, last 2026-04-16
     features/       3 pages (webhook-delivery, auth, rate-limiting)
     topics/         2 pages (redis, auth)             ← NEW
     archive/        1 file (history-2024.md)
     Compaction:  decisions.md at 18 entries — safe (threshold 30)
     Brain vs code: brain is 2 commits older than code → /brain update
```

**No writes. Safe to run anytime.**

---

### 5.3 `/brain update` — capture the session's WHY

**Purpose.** Review what happened in the current session and write the reasoning to brain.

The biggest, most consequential command. Triggered by user explicitly or by the post-commit hook.

```
 Trigger: user runs /brain update OR post-commit hook fires
       │
       ▼
 Step 1 — Get WHAT (code changes)
       │
       ├── git diff HEAD (uncommitted)
       ├── git diff --cached (staged)
       └── git log since last .brain/ commit (already-committed but unwritten)
       │
       ▼
 Step 2 — Filter for significance
       │
       └── Skip: formatting, version bumps, renames, <3 trivial lines
       │
       ▼
 Step 3 — Categorize
       │
       └── Match changes against 6 categories:
           new feature | bug fix | decision | pattern change | stack change | architecture
       │
       ▼
 Step 4 — Extract WHY from conversation
       │
       ├── Match the 5 event types (choice, broke, rejected, constraint, structural)
       └── If no WHY found: placeholder "Context: To be filled — reasoning not captured"
       │
       ▼
 Step 5 — Write updates to event-type pages
       │
       ├── For each affected page:
       │     - Read current content
       │     - Verify/restore frontmatter
       │     - Update `updated:` to today
       │     - Append new entry at TOP (newest first) OR replace in place (for prose pages)
       │     - Add [[wikilinks]] to connect entries
       │     - Create features/X.md if a significant new feature exists
       │
       ▼
 Step 6 — Maintain topic Timelines  ← NEW (v1)
       │
       ├── ls .brain/topics/*.md  → list existing topics (none if no adoption)
       ├── For each topic:
       │     - Read its Overview to understand scope
       │     - If any new entry this session matches the topic's scope:
       │         append Timeline bullet `- **DATE** — caption [[page.md#anchor]]`
       │     - Re-sort Timeline newest-first
       │     - Update topic's `updated:` to today
       │
       └── If 3+ new entries touch the same undocumented domain:
             SUGGEST `/brain topic <domain>` to the user. DO NOT create the file.
       │
       ▼
 Step 7 — Commit
       │
       ├── If uncommitted: stage .brain/ with code in one commit
       └── If already committed (post-commit hook): make a separate `brain: ...` commit
       │
       ▼
 Output: summary of what changed
```

**Invariants after update:**
- Every affected page's `updated:` is today's date.
- Every new entry has a `**Date:**` line.
- Every topic whose scope matches a session event has a fresh Timeline bullet.
- A git commit exists that captures the brain changes (same commit as code, or `brain:` commit).

**Risks:**
- **No atomicity.** If the LLM writes bugs.md but crashes before writing topics/redis.md, brain ends up inconsistent. Doctor catches eventually.
- **Topic drift.** The LLM decides what matches a topic's scope. Different LLMs may disagree. No invariant enforces "every Redis-related entry has a topic link."
- **Session context loss.** If the session is compacted by Claude Code before `/brain update` runs, WHY is lost. See Issue #6.

---

### 5.4-5.6 `/brain decide` / `bug` / `history` — quick-adds

**Purpose.** Skip the whole analysis flow; just add one entry now.

```
 User: /brain decide "Chose Redis over Memcached — need pub/sub for invalidation"
       │
       ▼
 Parse user text → extract decision + context + alternatives (for `decide`)
                   extract symptom + root cause + fix (for `bug`)
                   extract what happened (for `history`)
       │
       ▼
 Read target page (decisions.md / bugs.md / history.md)
       │
       ▼
 Insert new entry AT TOP with today's date
       │
       ▼
 Update frontmatter `updated:` to today
       │
       ▼
 Write file
       │
       ▼
 Confirm: `Added to .brain/decisions.md: "Chose Redis over Memcached"`
```

**Does NOT update topic pages.** Quick-adds are intentionally minimal. The topic Timeline gets updated on the next `/brain update` (or via `/brain topic <name> --sync`).

**Risks:**
- Same race-condition risk as any other write.
- **No argument handling spec.** Empty or malformed input behavior is not defined. See audit §10.

---

### 5.7 `/brain topic` — NEW (v1): topic page lifecycle

**Purpose.** Create or sync a topic page (cross-cutting narrative).

```
 User: /brain topic redis
       │
       ▼
 Slugify "redis" → "redis"
       │
       ▼
 test -f .brain/topics/redis.md
       │
       ├── MISSING branch:
       │     Read ~/.claude/skills/brain/templates/topic.md
       │     Substitute {{TOPIC_NAME}} = "redis"
       │     Substitute {{DATE}} = today
       │     mkdir -p .brain/topics
       │     Write .brain/topics/redis.md
       │     Tell user: "Created. Fill in Overview. Run --sync to backfill."
       │     STOP (don't sync unless --sync was on the command)
       │
       └── EXISTS branch (requires --sync flag):
             Grep .brain/decisions.md bugs.md history.md features/*.md for keywords
             For each match, extract the enclosing ## header + **Date:**
             Propose Timeline bullets to user: "Add these N entries?"
             On confirm: append, sort newest-first, update updated:
             Confirm: "Synced N entries into topics/redis.md Timeline"
```

**Invariants:**
- No auto-creation from any other command.
- Timeline bullets are always wikilinks, never duplicated prose.
- User confirms every sync.

**Risks:**
- Slug collision: "Redis Cache" and "redis-cache" both become `redis-cache`. No validation.
- No argument validation: `/brain topic` with no name, `/brain topic "../../etc/passwd"`, `/brain topic "a/b"` all unspecified. See audit §10.
- `--sync` uses keyword grep, not semantic matching. Misses synonyms. LLM may suggest obvious synonyms, but this is prompt-dependent.

---

### 5.8 `/brain query` — cross-page search + synthesis

**Purpose.** Ask a question against `.brain/`; get an answer that follows wikilinks.

```
 User: /brain query "what happened with webhook delivery?"
       │
       ▼
 Step 1 — check .brain/ exists
       │
       ▼
 Step 2 — grep -ril "<keyword>" .brain/  ← all pages recursively, incl. archive
       │
       ▼
 Step 3 — RANK results
       │
       ├── Top tier: topics/*.md + features/*.md       ← lifecycle / synthesis hubs
       ├── Direct ## header matches                     ← high relevance
       ├── Pages with many body matches
       └── Archive pages (for questions about the past)
       │
       ▼
 Step 4 — read top 3-5 pages FULLY
       │
       ▼
 Step 5 — follow wikilinks (ONE LEVEL DEEP, no recursion)
       │
       ├── [[page.md#anchor]] → read that section
       └── If target missing but slug matches a header in archive/, follow archive
       │
       ▼
 Step 6 — synthesize chronological answer
       │
       └── Cite sources: "According to topics/redis.md and archive/decisions-2024.md..."
       │
       ▼
 Output: markdown synthesis with citations
```

**Read-only. No writes.**

**Risks:**
- Grep is literal. Question "session storage" won't match "caching" unless the LLM expands synonyms. Recall is LLM-quality dependent.
- One-level-deep link following may miss chained stories. If `bugs.md#x` links to `features/y.md` which links to `decisions.md#z`, the query stops at features/y.md.

---

### 5.9 `/brain dashboard` — render interactive HTML

**Purpose.** Generate a browseable HTML dashboard of everything in `.brain/`.

```
 User: /brain dashboard
       │
       ▼
 Step 1 — check .brain/ exists
       │
       ▼
 Step 2 — read all .brain/**/*.md
       │
       ▼
 Step 3 — parse into BRAIN_DATA JSON:
   {
     index: {...},
     history: [{title, date, content}, ...],
     decisions: [{title, date, content, context, status}, ...],
     features: [{title, date, content, links}, ...],
     bugs: [{title, date, content, symptom, rootCause, fix, lesson}, ...],
     topics: [{slug, title, updated, overview, timelineCount, relatedCount}, ...],  ← NEW
     patterns: [{title, content}, ...],
     architecture: {overview, components, infrastructure}
   }
       │
       ▼
 Step 4 — read template at ~/.claude/skills/brain/templates/dashboard.html
       │
       ▼
 Step 5 — replace {{BRAIN_JSON}}, {{PROJECT_NAME}}, {{TOTAL_ENTRIES}}, {{LAST_UPDATED}}
       │
       ▼
 Step 6 — write .brain/dashboard.html
       │
       ▼
 Step 7 — open in browser (macOS: `open`, Linux: `xdg-open`)
       │
       ▼
 Step 8 — add dashboard.html to .brain/.gitignore
       │
       ▼
 Output: entry counts by category
```

**Topic rendering** (distinct from entry cards):
- One card per topic (not per Timeline bullet).
- Card shows: title, overview, "N timeline entries · M related links" metadata tags, date badge.
- Title links to `topics/<slug>.md` on disk.

**Risks:**
- Generated `.brain/dashboard.html` is large (~20KB template + JSON). Gitignore prevents bloat, but if user forgets, it lands in git.
- If the template at `~/.claude/skills/brain/templates/dashboard.html` is missing, command stops with an error. No fallback.
- Custom pages are NOT rendered (they're user-shaped, so the dashboard doesn't know how). Separate issue.

---

### 5.10 `/brain doctor` — diagnostic

**Purpose.** Validate `.brain/` against SCHEMA.md; suggest/apply narrow fixes.

This is a **reasoning command**, not a script. Doctor reads two knowledge documents at runtime:

```
 User: /brain doctor
       │
       ▼
 Step 1 — Read .brain/SCHEMA.md
        (the repo's authoritative format spec)
       │
       ▼
 Step 2 — Read ~/.claude/skills/brain/DIAGNOSTICS.md
        (the skill's playbook: Phase 0 probe + invariants + recovery table)
       │
       │  ↑ If DIAGNOSTICS.md missing, tell user skill is incomplete.
       │    Do NOT try to diagnose without it.
       │
       ▼
 Step 3 — Phase 0: environment probe (9 ctx.* signals)
       │
       ├── ctx.is_git          (git repo?)
       ├── ctx.has_head         (any commits?)
       ├── ctx.detached         (HEAD on branch?)
       ├── ctx.gitignored       (.brain/ excluded?)
       ├── ctx.brain_tracked    (any .brain/ file in index?)
       ├── ctx.shallow          (shallow clone?)
       ├── ctx.dirty_files      (modified .brain/ paths)
       ├── ctx.merging          (merge in progress?)
       └── ctx.behind_main      (commits main is ahead by)
       │
       ▼
 Step 4 — Walk invariants (structural / content / git / installation)
       │
       ├── Structural: core pages exist, frontmatter valid, type enum
       ├── Content: dates valid, wikilinks resolve, no conflict markers, topics non-empty
       ├── Git: .brain/ not gitignored, at least one file tracked
       └── Installation: skill present, hooks registered in settings.json
       │
       ▼
 Step 5 — Build findings (one per violation)
       │
       └── {section, file, location, schema_ref, message, recovery, auto_fix_eligible}
       │
       ▼
 Step 6 — Render report grouped by section (CONTEXT / SYSTEM / FORMAT & CONTENT / SYNC / GAPS)
       │
       ▼
 Step 7 — Offer auto-fix whitelist (exactly 2 items):
       │
       ├── Restore missing .brain/SCHEMA.md from local skill (cp command)
       └── Re-register hooks (install.sh --hooks-only)
       │
       │  Single top-level [y/n] prompt. User consents or declines for all.
       │
       ▼
 Step 8 — Verify each applied fix
       │
       └── Re-run the specific invariant. If verify fails, print diagnosis block.
             Do NOT loop, retry, or fall back.
```

**Auto-fix whitelist is intentionally tiny.** Doctor NEVER auto-edits brain content (dates, wikilinks, prose). Those are user authorship. Everything else is printed for the user to act on.

**Risks:**
- Doctor's value depends on SCHEMA and DIAGNOSTICS staying in sync. If SCHEMA changes a rule and DIAGNOSTICS doesn't cite it, doctor has a gap.
- The archive-slug wikilink recovery is reasoning-based; if the LLM doesn't actually check archive/ for slug matches, the better error message never appears.

---

### 5.11 `/brain uninstall` — remove skill + hooks

**Purpose.** Clean removal from a machine. Does NOT touch repo-side `.brain/` directories.

```
 User: /brain uninstall
       │
       ▼
 Step 1 — confirm with user (destructive: shows what will be removed)
       │
       ▼
 Step 2 — rm ~/.claude/hooks/post-commit-brain.sh
         rm ~/.claude/hooks/session-start-brain.sh
       │
       ▼
 Step 3 — edit ~/.claude/settings.json to remove brain hooks
         (jq filter to drop matching entries)
       │
       ▼
 Step 4 — remove "# brain" block from ~/.claude/CLAUDE.md
       │
       ▼
 Step 5 — rm -rf ~/.claude/skills/brain/
       │
       ▼
 Step 6 — confirm
```

**Safety:**
- Never touches repo-side `.brain/` directories. Those stay in git and keep working at tier 1.
- Requires explicit y/n on the destructive step.

---

## 6. Hook flows (2)

### 6.1 SessionStart — discovery, not loading

**Fires:** every time a Claude Code session opens in a directory containing `.brain/`.

```
 Claude Code session opens in CWD
       │
       ▼
 session-start-brain.sh reads stdin JSON → extracts CWD
       │
       ├── .brain/ doesn't exist? → exit 0 (silent, no context injected)
       │
       ▼
 Read .brain/index.md  → must exist; if not, emit WARNING, exit 0
 Read .brain/SCHEMA.md → if missing, add to WARNINGS
       │
       ▼
 Compute staleness:
   LAST_BRAIN = git log -1 --format=%ct -- .brain/
   LAST_CODE  = git log -1 --format=%ct -- ':(exclude).brain/'
   if LAST_CODE > LAST_BRAIN → add staleness WARNING with dates (validated YYYY-MM-DD)
       │
       ▼
 Compute TOPIC_NAMES:  ← NEW (v1)
   ls .brain/topics/*.md | xargs basename -s .md | paste -sd ', '
       │
       ▼
 Emit JSON via jq --arg warnings --arg topics:
   {
     hookSpecificOutput: {
       hookEventName: "SessionStart",
       additionalContext:
         "brain: This repo has .brain/ project memory. Read index.md..."
         + (topics != "" ? " Topic pages available (read on demand): <list>." : "")
         + warnings
     }
   }
       │
       ▼
 Claude Code injects additionalContext into the LLM's session
```

**Token cost** (measured):

| Scenario | Tokens |
|----------|--------|
| No `.brain/` | 0 (hook exits silently) |
| No topics/ | ~150 |
| 3 topics | ~160 |
| 10 topics | ~170 |
| 30 topics | ~200 |
| 100 topics (hypothetical) | ~350 |

**Key invariant: content is never loaded at session start.** Only names. The LLM reads content on demand via wikilinks or `/brain query`.

**Risks:**
- If `jq` is missing, hook outputs nothing (silent fail, no context for LLM). See Issue #15.
- `ls` with no matches uses `|| true` pattern via 2>/dev/null → empty. Safe on bash.
- Paths with spaces: tested; `paste` handles. `jq --arg` handles JSON escaping.

### 6.2 PostToolUse (`git commit*`) — the maintenance trigger

**Fires:** after Claude Code runs a Bash command matching `git commit*`.

```
 User runs `git commit -m "..."` via Bash tool
       │
       ▼
 post-commit-brain.sh reads stdin JSON → extracts CWD
       │
       ├── .brain/ doesn't exist? → exit 0
       ├── No HEAD~1 (first commit)? → exit 0
       ├── Commit has only .brain/ files? → exit 0 (brain-only commit, skip)
       │
       ▼
 .brain/SCHEMA.md missing? → emit WARNING context, exit 0
       │
       ▼
 Emit nudge via jq:
   {
     hookSpecificOutput: {
       hookEventName: "PostToolUse",
       additionalContext:
         "brain: IMMEDIATELY check this session for brain-worthy changes...
          If significant, read .brain/SCHEMA.md, update pages
          (event-type pages AND any related .brain/topics/*.md Timelines),
          and commit: git add .brain/ && git commit -m 'brain: <summary>'..."
     }
   }
       │
       ▼
 Claude Code injects the nudge
       │
       ▼
 LLM (autonomously) runs /brain update
       │
       ▼
 /brain update walks its 7 steps (§5.3)
       │
       └── Topic maintenance (Step 6) is what the message explicitly requires.
```

**Important:** the hook doesn't know which topics are relevant. It just *instructs the LLM to check*. The knowledge of "which events match which topic" lives in `/brain update` Step 6 inside SKILL.md.

**Risks:**
- **Issue #14**: fires on `git commit --amend` too. LLM may propose duplicate updates.
- **Fires on merge commits.** No special handling — LLM treats a merge as a normal commit and may try to update brain with no relevant session context.
- **Fires on rebase.** During interactive rebase, the hook fires per commit. Could produce cascading updates.

---

## 7. Cross-cutting concerns

### 7.1 Persistence model

brain's reliability comes from TWO overlapping mechanisms, not one:

```
 Reliability stack (most reliable on top)
 ────────────────────────────────────────

 ┌─────────────────────────────────────────────────┐
 │  L1 — git (the substrate)                        │
 │  .brain/ is tracked, committed, pushed. Full     │
 │  history preserved. Any teammate's clone has it. │
 └─────────────────────────────────────────────────┘
                      ▲
                      │  updates land here
                      │
 ┌─────────────────────────────────────────────────┐
 │  L2 — hooks (the reminder layer)                  │
 │  SessionStart: tell LLM brain exists             │
 │  PostToolUse:  tell LLM to update after commits  │
 │  Without hooks: user must remember /brain update │
 └─────────────────────────────────────────────────┘
                      ▲
                      │  instructions come from here
                      │
 ┌─────────────────────────────────────────────────┐
 │  L3 — SCHEMA.md (the rules)                      │
 │  Shipped per-repo. Any LLM that reads it knows   │
 │  how to maintain brain. Source of truth.         │
 └─────────────────────────────────────────────────┘
                      ▲
                      │  reads and applies
                      │
 ┌─────────────────────────────────────────────────┐
 │  L4 — the LLM (the writer)                        │
 │  Non-deterministic. Best-effort.                 │
 │  Doctor is the safety net.                       │
 └─────────────────────────────────────────────────┘
```

**Key insight.** The system is layered so that if L4 (the LLM) misbehaves in one session, L3 (SCHEMA) tells the next LLM what the rules are, L2 (hooks) ensures the next session notices brain exists, and L1 (git) means nothing was permanently lost.

### 7.2 Token budget at session start

```
 Every session that opens in a .brain/ repo pays this cost:

 SessionStart additionalContext:             ~150 tokens (base)
 + optional topic names list:                0-50 tokens
 + optional staleness warning:               +30 tokens

 Total:                                      150-230 tokens typical

 Then the LLM chooses what to read on demand:
 - index.md                                  ~400 tokens
 - one topic page                             ~300-500 tokens
 - one feature page                           ~300-500 tokens
 - a specific decisions.md entry              ~100 tokens
 - /brain query                               varies (can read 5+ pages)
```

**Design principle.** Never preload content at session start. Name-listing is the discovery surface.

### 7.3 Compaction and archive

**Purpose.** Keep active pages small even as a project matures.

**Trigger.** Manual (SCHEMA says "when page exceeds 30 entries or 150 lines"). No auto-detection today. See Issue #10.

```
 Before compaction                After compaction
 ─────────────────                ────────────────

 decisions.md (45 entries)        decisions.md (15 entries, last 3 months)
   ## Latest decision                ## Latest decision
   ...                               ...
   ## Oldest decision              > Older entries archived in
                                   > [archive/decisions-2024.md]

                                   archive/decisions-2024.md (NEW)
                                     ## Old entry #1
                                     ## Old entry #2
                                     ... (frozen)
```

**Topic page interaction.** Topics are NOT compacted. If a topic's Timeline has a wikilink pointing at `decisions.md#x` and that entry just moved to `archive/decisions-2024.md#x`, the link is now broken.

**Doctor handles this:** when a broken wikilink's slug matches a header in an `archive/*.md` file, doctor emits a specific recovery hint:

```
 WARNING: Broken wikilink in .brain/topics/redis.md
 Points at: [[decisions.md#chose-redis-over-memcached]]
 Slug matches header in: archive/decisions-2024.md
 Recovery: repoint the wikilink to archive/decisions-2024.md#chose-redis-over-memcached
           or restore the entry from archive back to decisions.md
```

### 7.4 Merge conflicts (three cases)

brain pages are designed merge-friendly, but conflicts still happen. SCHEMA.md § Merge Conflict Guidance defines three cases:

```
 Case 1: both branches ADDED new entries (the 99% case)
 ────────────────────────────────────────────────────────
 Mechanical resolve. Keep both, sort by date descending.
 Applies to: history.md, decisions.md, bugs.md,
             features/*.md Timeline, topics/*.md Timeline
 No human judgment needed.

 Case 2: both branches EDITED the same existing entry
 ─────────────────────────────────────────────────────
 Coordination issue. Read both, combine if valid,
 or pick the correct one based on current project state.
 Applies to: any page type.
 Real human judgment required.

 Case 3: prose pages
 ───────────────────
 Applies to: index.md, architecture.md, patterns.md
 Topic Overview/Status (the non-Timeline prose)
 Read both, pick more current, or combine.
```

### 7.5 Topic pages (NEW in v1)

**Mental model:** topics are the **index into time**. They synthesize the narrative of a domain across every event that touched it.

```
 Without topics:
   Redis story = grep across decisions.md + bugs.md + history.md + features/
   + stitching together manually

 With topics:
   Redis story = read topics/redis.md
                 follow the 7 wikilinks on its Timeline
                 full narrative emerges in order
```

**Creation is explicit only** (`/brain topic <name>`). Reasons (from the v1 design):
- Auto-creation produces noisy, weak topics that nobody deletes.
- Explicit intent earns the synthesis layer.
- `/brain update` is already doing a lot — adding "spot new topic patterns" risks weak output.

**Maintenance is automatic** (`/brain update` Step 6). Every session that writes event-type entries also appends Timeline wikilinks to matching existing topics.

### 7.6 Multi-dev scenarios

```
 Team of 3 working in parallel:

 Dev A                    Dev B                    Dev C
 ─────                    ─────                    ─────
 works on auth feature    works on Redis OOM       reads brain
 /brain update            /brain update            /brain query "auth"
 → decisions.md: "…"      → bugs.md: "…"
 → features/auth.md: "…"  → topics/redis.md: "…"
 → topics/auth.md: "…"
                                                   Query works against
 git push                 git push                 whatever's been pushed
                                                   to the shared branch
                          ↓
 PR merge                 PR merge (to main)       Later: git pull
                                                   Gets both A's + B's
 │  │                     │  │                     work in one sync
 │  │                     │  │
 Timeline bullets may     Same in features/
 conflict on auth.md      and decisions.md
 → Case 1 resolve          → Case 1 resolve
 (mechanical, keep both)  (mechanical, keep both)
```

---

## 8. Integrity analysis

### 8.1 Single points of failure

| Component | If missing/broken | Blast radius |
|-----------|-------------------|--------------|
| `.brain/SCHEMA.md` (in repo) | LLM doesn't know format rules; updates risk corrupting | HIGH — every update can be malformed |
| `~/.claude/skills/brain/SCHEMA.md` | `/brain init` can't copy to repo; topic/doctor reference broken | MEDIUM — `/brain init` blocked, docs degrade |
| `~/.claude/skills/brain/DIAGNOSTICS.md` | `/brain doctor` cannot run | LOW — doctor is a periodic check, not critical path |
| `~/.claude/skills/brain/templates/*.md` | `/brain init` can't generate pages | MEDIUM — init blocked; existing brains OK |
| `jq` binary | install.sh preflight blocks install; hooks emit a static WARNING via heredoc | MEDIUM — loud, not silent; full features degraded but user sees the warning |
| `~/.claude/hooks/*.sh` | Hooks don't fire; manual-only mode | MEDIUM — tier 3 degrades to tier 2 |
| `~/.claude/settings.json` hook registration | Hooks exist but never run | HIGH + silent |
| LLM behavior | Correct? Non-deterministic updates | Always a factor |

### 8.2 LLM-as-enforcer risks

**The core architectural bet:** the LLM reads SCHEMA.md and applies the rules. There's no runtime enforcement beyond doctor.

```
 What's enforced mechanically:
 ─────────────────────────────
 - File existence (via shell tests in init, templates)
 - JSON validity in hook output (via jq)
 - Shell script syntax (bash -n on install)
 - Nothing else

 What relies on LLM following instructions:
 ──────────────────────────────────────────
 - Frontmatter structure (type:, updated:)
 - Date format (YYYY-MM-DD)
 - Newest-first ordering within pages
 - Wikilink anchor slug algorithm
 - 5-event-type recognition
 - Topic Timeline maintenance
 - Compaction thresholds
 - Commit message prefix ("brain:")
 - Every section header choice

 Doctor is the after-the-fact catcher. It's
 periodic, not continuous.
```

This is by design — mechanical enforcement (linters, pre-commit hooks that validate schema) would fight the "any LLM can maintain brain" zero-install model. But it means drift is possible and slow corrections are inevitable.

### 8.3 Dependency chain by boot order

```
 Fresh clone of brain-enabled repo:
 ──────────────────────────────────

 1. git clone                                         Required
 2. CLAUDE.md / .cursor/rules / AGENTS.md exists     Tier 1
 3. .brain/SCHEMA.md exists (via git)                 Tier 1
    │
    └── LLM can now read brain and maintain manually

 4. ~/.claude/skills/brain/ installed                 Tier 2
    │
    └── /brain commands available (init, update, etc.)

 5. ~/.claude/hooks/*.sh + settings.json registered   Tier 3
    │
    ├── SessionStart fires → topic discovery works
    └── PostToolUse fires → post-commit nudge works
```

If any step fails, the tier above it degrades gracefully. But silent failures (hooks not registered) are the worst: user thinks they have tier 3 but they don't.

---

## 9. Edge cases catalog

A non-exhaustive list of edge cases, each with observed/expected behavior.

| # | Scenario | Behavior | Notes |
|---|----------|----------|-------|
| 1 | `/brain init` on repo that already has `.brain/` | Detects via `ls .brain/index.md`, stops, suggests `/brain status` | OK |
| 2 | `/brain init` on repo with `.brain/` BUT missing index.md | Runs again; may conflict with existing pages | Documented gap |
| 3 | `/brain topic` with no argument | Unspecified. Likely error from the LLM. | **NEW ISSUE** |
| 4 | `/brain topic "../../etc/passwd"` | Slugify strips punctuation but not `..`; could write outside `.brain/topics/` | **NEW ISSUE (security-adjacent, low risk since local)** |
| 5 | `/brain topic "Redis/Cache"` | Slash in name; after slugify becomes `rediscache`. Collision with existing `rediscache` if any. | **NEW ISSUE** |
| 6 | Two topic pages slug to the same filename | Second `/brain topic` overwrites first? Unspecified. | **NEW ISSUE** |
| 7 | Topic file with empty Timeline | Doctor flags WARNING. User directed to `/brain topic <name> --sync`. | OK |
| 8 | Topic wikilink points at a page that never existed | Doctor flags as MANUAL. | OK |
| 9 | Topic wikilink points at entry that was compacted | Doctor flags with archive-slug recovery hint. | OK |
| 10 | Session-start hook runs with no `topics/` dir | `ls` returns nothing, TOPIC_NAMES empty, conditional jq omits topic line. | OK |
| 11 | Session-start hook runs with 1 topic | Lists `redis` (single name, no trailing comma). | OK |
| 12 | Session-start hook when `jq` is missing | Silent failure. No context to LLM. | **Issue #15** |
| 13 | Post-commit fires on `git commit --amend` | Runs the nudge; LLM may propose duplicate updates. | **Issue #14** |
| 14 | Post-commit fires during interactive rebase | Fires per commit. Cascading nudges. | **NEW ISSUE — rebase amplification** |
| 15 | Post-commit fires on a merge commit | Nudge fires; LLM has no session context about the merge. | **NEW ISSUE** |
| 16 | User runs `/brain decide` and `/brain update` in parallel (two Claude sessions) | Last write wins on `decisions.md`. Lost data possible. | **NEW ISSUE — no locking** |
| 17 | Archive year split: `history-2024.md` exceeds 150 lines | Unspecified. Sub-split? `history-2024-h1.md`? | **Issue #10-adjacent** |
| 18 | SCHEMA.md version in repo is older than skill's SCHEMA | Doctor emits CONTEXT warning; no forced migration. | **Issue #9** |
| 19 | `updated:` field differs from max `**Date:**` within the page | Not validated today. | **NEW ISSUE** |
| 20 | Frontmatter `type:` doesn't match filename (e.g., `decisions.md` with `type: bugs`) | Not validated today. | **NEW ISSUE** |
| 21 | User adds `.brain/` to `.gitignore` | Doctor flags ERROR + REVIEW. | OK |
| 22 | Repo has no git history (fresh init) | Post-commit hook exits (no HEAD~1). SessionStart still works. | OK |
| 23 | Repo is a shallow clone | Doctor flags WARNING; some recovery paths limited. | OK |
| 24 | Claude Code session is compacted mid-session | Session context (including WHY) may be lost before `/brain update` runs. | **Issue #6** |
| 25 | `/brain init` auto-suggests topic pages | No — explicitly disabled. init never creates topics. | OK by design |
| 26 | Dashboard HTML opened on a machine that can't execute inline JS | Blank dashboard. | Accepted limitation |
| 27 | `custom/` pages are not in dashboard | Skipped entirely. | Documented gap |
| 28 | Wikilink to `custom/<name>.md` | Works; doctor resolves if file exists. | OK |
| 29 | Special chars in header (em-dash, backticks) | Slug algorithm undefined. | **Issue #11** |
| 30 | Two branches both add new topic page with same slug | Case 1 merge (add) but both files? Git handles as file-level conflict (add+add). | **NEW ISSUE — not covered by merge guidance** |

---

## 10. Issues found (audit)

Consolidated list of all known gaps, bugs, and open architectural questions, with severity and action.

### 10.1 Pre-existing known issues (from the original 15-item backlog)

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 6 | Session compaction loses WHY before `/brain update` runs | Medium | Open. Fix idea: mid-session flush. |
| 8 | `/brain init` and `install.sh` both write brain block to CLAUDE.md (two locations) | Medium | Open. Pick one canonical. |
| 9 | No SCHEMA.md version migration path | Low | Open. Hypothetical future problem. |
| 10 | Compaction has no auto-trigger; user must notice | Low | Open. Doctor could flag threshold. |
| 11 | Wikilink anchor slug algorithm undefined for special chars (em-dash, backticks, colons) | Medium | Open. Need explicit algorithm in SCHEMA. |
| 14 | Post-commit hook fires on `git commit --amend` | Medium | Open. Could check `$(git rev-parse HEAD) != $(git rev-parse HEAD@{1})` to detect amend. |
| 15 | `jq` dependency not preflight-checked | ~~Medium~~ | **Resolved.** Three-layer fix shipped: install.sh preflight (hard error with platform install hints), both hooks degrade to a static JSON WARNING when jq is absent, doctor flags missing jq via Installation invariant. |

**Note:** issues #12 (merge conflict magnet), #13 (archive type missing), and #15 (jq preflight) were resolved during this session.

### 10.2 New issues surfaced by this architectural audit

| # | Issue | Severity | Notes |
|---|-------|----------|-------|
| N1 | `/brain topic` with missing argument — unspecified behavior | Low | Need explicit: "tell user, show usage, stop." |
| N2 | `/brain topic` slug collision detection missing | Medium | Two topics slugifying to same filename silently overwrite. |
| N3 | `/brain topic` name with path separators (`/`, `..`) not validated | Low (local-tool, low risk) | Slugify should strip or reject these before `mkdir`/write. |
| N4 | Post-commit hook fires on merge commits without special handling | Medium | LLM has no session context about the merge; may propose bad updates. Hook should detect `git rev-parse --verify MERGE_HEAD` or check commit's parent count. |
| N5 | Post-commit hook fires during interactive rebase (amplified) | Medium | Per-commit firing during rebase creates cascading updates. Should detect `GIT_REFLOG_ACTION` or `$(git rev-parse --git-path rebase-merge)` to skip. |
| N6 | Two concurrent Claude sessions updating `.brain/` create race conditions | Medium | No locking. Last write wins. Rare but possible. |
| N7 | `updated:` frontmatter can diverge from the max `**Date:**` in entries | Low | Invariant not enforced today. Doctor could add a check. |
| N8 | Frontmatter `type:` not validated against filename | Low | `bugs.md` with `type: decisions` wouldn't be caught today. |
| N9 | Two branches adding the same-slug topic page → git add+add conflict not covered in merge guidance | Low | SCHEMA Case 1 assumes file exists in both; new-file-both-sides is different mechanics. |
| N10 | Archive year-files have no sub-split guidance if they exceed compaction threshold | Low | `archive/history-2024.md` at 200+ entries? SCHEMA silent. |
| N11 | `custom/*.md` not rendered in dashboard | Low | Known gap. Acceptable for v1 but should be documented. |
| N12 | `skill/templates/graph.html` is an orphan (exists, not shipped, not referenced) | Trivial | Remove or wire up. |
| N13 | Brain's own repo has no `.brain/` — tool isn't dogfooded | Medium-philosophical | brain should be able to describe itself. Would also catch many gaps via usage. |
| N14 | `/brain topic <name> --sync` synonym expansion is LLM-guessed, not codified | Low | Could allow explicit `--sync --keywords "redis,cache,caching"`. |
| N15 | No enforcement that Timeline wikilinks resolve at write-time | Low | LLM can accidentally write a bullet with broken wikilink; only caught later by doctor. |
| N16 | SCHEMA.md slug algorithm is prose, not a reference implementation | Medium | Different LLMs may slug differently. Would help to have a canonical JS/py snippet in SCHEMA. |
| N17 | `install.sh` appends brain block to CLAUDE.md if `# brain` marker is missing, but doesn't check for partial/edited blocks | Low | Edge: user edits the block; install doesn't re-check content. |
| N18 | `~/.claude/settings.json` hook registration uses `jq` mutation but has no idempotency check beyond `grep -q post-commit-brain` | Low | Could produce duplicate entries if user's settings.json has atypical shape. |

### 10.3 Architectural concerns (not bugs, but drift risk)

| Concern | Implication |
|---------|-------------|
| Zero-install tier means the LLM is the enforcer of ALL format rules | Drift is inevitable. Doctor is the only periodic check. |
| No schema version on individual pages | A page written under SCHEMA v1 can't be identified as such. If v2 breaks a rule, old pages silently violate it. |
| Slug algorithm in prose, not code | Every LLM is its own implementer. Drift across tools (Claude Code vs Cursor) possible. |
| Compaction is manual | Pages grow unbounded unless user notices. Dashboard could count; doctor could warn; neither does today. |
| `features/` vs `topics/` vs `custom/` have overlapping semantics | SCHEMA has a callout table, but users will still get confused. |
| Topic creation threshold (3+ recurring events) is advisory, not enforced | Some projects will have 0 topics when they should have 5; others will have 50 weak ones. |
| brain doesn't dogfood itself | Bugs only surface when users report them. Using brain on brain would surface many issues proactively. |

---

## 11. Glossary

- **Active page.** Any `.brain/*.md` or `.brain/features/*.md` or `.brain/topics/*.md` that the LLM reads on demand during normal work.
- **Anchor slug.** The identifier form of a `## Header Text` — lowercase, spaces→hyphens, punctuation stripped. Used in wikilinks as `[[page.md#anchor-slug]]`.
- **Archive.** `.brain/archive/*.md`. Compacted entries, frozen, searchable via grep, not loaded at session start.
- **Brain-worthy.** A session event matching one of the 5 event types (CHOICE / BROKE / REJECTED / CONSTRAINT / STRUCTURAL).
- **Compaction.** Moving entries older than 3 months out of an active page (decisions/bugs/history) into `archive/<page>-<year>.md`.
- **Event-type page.** Any of `decisions.md`, `bugs.md`, `history.md`. Chronological, newest-first, append-mostly.
- **Feature page.** One `features/<slug>.md` per significant feature. Lifecycle tracking with Timeline.
- **Five event types.** The WHY model; §4.4.
- **Frontmatter.** The YAML block at the top of every `.brain/*.md` declaring `type:` and `updated:`.
- **Hook.** A shell script at `~/.claude/hooks/*.sh` fired by Claude Code events (SessionStart, PostToolUse).
- **Invariant.** A condition that must hold true, enforced by doctor.
- **Lifecycle hub.** A page whose purpose is to synthesize a timeline (`features/*.md`, `topics/*.md`).
- **Nudge.** The `additionalContext` message the post-commit hook sends to the LLM.
- **Schema.** `.brain/SCHEMA.md` in the repo; `~/.claude/skills/brain/SCHEMA.md` in the skill. Both contain the same canonical format rules.
- **Session-start context.** The ~150 tokens injected into every Claude Code session that opens in a `.brain/` repo.
- **Skill.** `~/.claude/skills/brain/` — the per-user installation.
- **Slug.** A URL-safe lowercased-with-hyphens form of a name.
- **Tier.** One of the three install levels (zero-install / skill / hooks).
- **Topic page.** NEW (v1): `.brain/topics/<slug>.md`. Cross-cutting narrative synthesizing events across event-type pages.
- **WHY.** The reasoning behind a code decision — what brain exists to capture.
- **Wikilink.** An inline `[[page.md]]` or `[[page.md#anchor]]` reference connecting entries across pages.

---

**Last updated:** 2026-04-17 (v1 topic pages shipped)
**Authoritative sources:**
- Format rules: `/Users/batuhan/brain/skill/SCHEMA.md`
- Doctor playbook: `/Users/batuhan/brain/skill/DIAGNOSTICS.md`
- Commands: `/Users/batuhan/brain/skill/SKILL.md`
- Install: `/Users/batuhan/brain/install.sh`
- Hooks: `/Users/batuhan/brain/skill/hooks/*.sh`
