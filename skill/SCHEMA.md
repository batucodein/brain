# .brain/ Schema v2.0

The `.brain/` directory is a per-repo project memory tracked in git. It gives any LLM coding tool (Claude Code, Cursor, Codex, Copilot) full project context at session start.

---

## LLM Instructions

If you are an LLM reading this file, follow these instructions. This section tells you how to read, maintain, and update this project's brain. No additional tools or skills are required — everything you need is in this file.

### At Session Start

1. Read `.brain/index.md` to understand the project.
2. Based on the user's task, read relevant pages:
   - Refactoring or adding code → `architecture.md`, `patterns.md`
   - Debugging → `bugs.md`, relevant `features/*.md`
   - New feature → `decisions.md`, related `features/*.md`
   - General question → search across all pages
3. If the task relates to a specific feature, check if `features/X.md` exists and read it for full lifecycle context.

### During the Session — Track Reasoning

The conversation is the only place where reasoning exists. Recognize these moments as they happen — they are the WHY that brain captures:

1. **A choice was made** — Multiple approaches existed, one was picked. Note what was chosen and what wasn't.
2. **Something broke and was understood** — A bug was reported, investigated, and diagnosed. The full arc matters: symptom → investigation → root cause → fix.
3. **Something was rejected** — An approach was proposed and turned down, or was tried and didn't work. Why it was rejected is high-value context.
4. **A constraint shaped the work** — Performance, cost, compatibility, time, team size — anything that steered the implementation away from the default approach.
5. **The system changed structurally** — New component, integration, dependency, or layer. Structural reasoning is the hardest to recover later.

You don't need to write anything during the session — just recognize these moments so you can reference them when updating brain.

### Updating .brain/ — The Process

After significant code changes (or when asked to update brain), follow this process:

#### 1. Get the WHAT (code changes)

Read the actual diff, not just file names:

```bash
git diff HEAD -- ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)go.sum' 2>/dev/null | head -300
git diff --cached -- ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)go.sum' 2>/dev/null | head -300
git log --since="2 hours ago" --oneline --stat 2>/dev/null
```

#### 2. Filter for significance

Skip the update if ALL changes are:
- Formatting, linting, or whitespace only
- Dependency version bumps with no behavior change
- Renaming with no design reasoning
- Changes to fewer than 3 lines with no architectural impact

Continue only if at least one change involves a new feature, bug fix, architectural change, explicit decision, pattern change, or infrastructure change.

#### 3. Categorize changes

| Category | Brain pages to update |
|----------|----------------------|
| **New feature** | `history.md`, create `features/X.md`, maybe `architecture.md` |
| **Bug fix** | `bugs.md`, update `features/X.md` if related |
| **Decision** | `decisions.md`, link from `features/X.md` if related |
| **Pattern change** | `patterns.md` |
| **Stack/dependency change** | `index.md` |
| **Architecture change** | `architecture.md` |
| **Refactor** | `history.md`, `architecture.md` if structure changed |

#### 4. Extract the WHY from conversation

For each categorized change, look back through the conversation for the 5 event types listed in "During the Session" above. Match changes to reasoning.

**If no WHY exists in the conversation** for a change: Do NOT invent one. Either:
- Ask the user what drove the change
- Or write the entry with just the WHAT and mark it: `**Context:** To be filled — reasoning not captured in session.`

#### 5. Write updates

For each page that needs updating:
1. Read the current content.
2. Add new entries at the top (newest first) for `history.md`, `decisions.md`, `bugs.md`.
3. Replace in-place for `index.md`, `architecture.md`, `patterns.md`.
4. Follow the format rules in this file. Every entry needs `**Date:** YYYY-MM-DD`.
5. Add `[[wikilinks]]` to connect related entries across pages.
6. If a significant new feature was built and no `features/X.md` exists, create one.

**Writing rules:**
- Lead with the WHY, not the WHAT. Bad: "Added Redis caching." Good: "Added Redis caching to avoid redundant API calls — same queries were hitting the API repeatedly, costing money and adding latency."
- Include alternatives considered when available.
- For bugs, always include root cause and lesson.
- Keep entries to 1-3 short paragraphs. Brain is context, not documentation.

#### 6. Commit with your code

Include brain updates in the same commit as the code changes they describe. Update brain pages before committing, then stage everything together:

```bash
git add .brain/ src/
git commit -m "feat: add Google OAuth login"
```

One change = one commit. Brain pages are part of the change, not a separate event.

### Before Session End

If significant changes were made during the session, suggest updating brain. Be specific: "I'd capture the caching decision and the auth bug root cause — want me to update brain?"

### Rules

1. **Never hallucinate.** If you can't determine something from the repo or conversation, write "Unknown — to be filled by team" rather than guessing.
2. **Be concise.** Each entry should be one paragraph or a short list. Brain is context, not documentation.
3. **Explain WHY, not WHAT.** The code shows what. Brain pages explain why.
4. **Use absolute dates.** Always `YYYY-MM-DD`. Never "yesterday" or "last week."
5. **Don't duplicate README.** Reference it: "See README.md for setup instructions."
6. **Respect existing content.** Preserve what others wrote. Add, don't replace (unless correcting errors).
7. **Commit together.** Include brain updates in the same commit as the code they describe. Update brain pages before committing.
8. **Compaction.** When any page exceeds 30 entries or 150 lines, move entries older than 3 months to `.brain/archive/<page>-<year>.md`.

---

## Directory Structure

```
.brain/
├── SCHEMA.md           # This file — format spec + LLM instructions
├── index.md            # Project overview — what, why, who, how
├── architecture.md     # Stack, structure, components, data flow
├── decisions.md        # Why things are the way they are (ADR-lite)
├── patterns.md         # Coding conventions, naming, error handling
├── history.md          # Timeline of significant changes
├── bugs.md             # Notable bugs, root causes, fixes
├── features/           # One page per significant feature (lifecycle tracking)
│   └── *.md
├── archive/            # Compacted old entries
│   └── *.md
└── custom/             # Team-defined pages (optional)
    └── *.md
```

## Page Format

Every `.brain/` page is a markdown file with YAML frontmatter:

```markdown
---
type: <page_type>
updated: YYYY-MM-DD
---

# Page Title

Content here. Use markdown normally.
```

### Frontmatter Fields

| Field     | Required | Description                              |
|-----------|----------|------------------------------------------|
| `type`    | yes      | One of the page types below              |
| `updated` | yes      | Date of last meaningful update           |

### Page Types

| Type           | File              | Purpose                                         |
|----------------|-------------------|-------------------------------------------------|
| `index`        | `index.md`        | What this project does, who it's for, tech stack overview |
| `architecture` | `architecture.md` | System structure, key components, data flow, infrastructure |
| `decisions`    | `decisions.md`    | Architectural decisions with context and reasoning |
| `patterns`     | `patterns.md`     | Code conventions, naming rules, error handling, testing approach |
| `history`      | `history.md`      | Timeline of significant milestones and changes  |
| `bugs`         | `bugs.md`         | Notable bugs with root cause and fix             |
| `feature`      | `features/*.md`   | Lifecycle of a significant feature — one page per feature |
| `custom`       | `custom/*.md`     | Team-defined pages for domain-specific context   |

## Content Guidelines

### index.md

The entry point. An LLM reads this first to understand the project.

```markdown
---
type: index
updated: 2026-04-11
---

# Project Name

One-paragraph description of what this project does and why it exists.

## Tech Stack

- **Language:** Python 3.12
- **Framework:** FastAPI
- **Database:** PostgreSQL 16
- **Cache:** Redis 7
- **CI/CD:** GitHub Actions

## Key Directories

- `src/api/` — HTTP handlers
- `src/services/` — Business logic
- `src/models/` — Database models
- `src/utils/` — Shared utilities
- `web/` — Frontend (React)

## Team

- 2 backend engineers, 1 frontend
- Project lead owns infra decisions
```

### decisions.md

Each entry is a decision with context. Newest first.

```markdown
---
type: decisions
updated: 2026-04-11
---

# Decisions

## Chose Redis over Memcached for session caching
**Date:** 2026-04-10
**Context:** Needed server-side session store with invalidation support.
**Decision:** Redis — pub/sub enables cache invalidation across instances.
**Alternatives considered:** Memcached (simpler but no pub/sub), database sessions (too slow).
**Status:** Active

## Moved from REST to gRPC for internal services
**Date:** 2026-03-15
**Context:** Inter-service latency was 40ms+ with JSON serialization.
**Decision:** gRPC with protobuf for internal calls. REST remains for public API.
**Alternatives considered:** MessagePack over HTTP (marginal gain), GraphQL (overkill for internal).
**Status:** Active
```

### history.md

Chronological log of significant changes. Newest first.

```markdown
---
type: history
updated: 2026-04-11
---

# History

## Added Redis caching layer
**Date:** 2026-04-10
Introduced Redis for session caching and rate limiting. Reduced p95 latency from 120ms to 45ms on authenticated endpoints.

## Migrated CI from CircleCI to GitHub Actions
**Date:** 2026-04-01
Moved all pipelines. Build time dropped from 8min to 3min. Saved $200/mo.

## Initial release v1.0
**Date:** 2026-03-15
Shipped core API with user auth, project CRUD, and webhook integrations.
```

### architecture.md

System structure and component relationships. This page must be built from reading actual code, not guessed from folder names.

```markdown
---
type: architecture
updated: 2026-04-11
---

# Architecture

## Overview

Brief description of the system's architecture style and key design principles.

## System Schema

```
┌─────────────────────────────────────────────────────┐
│                     Client                           │
└──────────────────────┬──────────────────────────────┘
                       │ HTTPS
┌──────────────────────▼──────────────────────────────┐
│                    API Layer                          │
│  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌─────────┐  │
│  │  Auth   │→│  Rate    │→│ Logging │→│ Handler │  │
│  │Middleware│ │  Limit   │ │         │ │         │  │
│  └─────────┘ └──────────┘ └─────────┘ └────┬────┘  │
└────────────────────────────────────────────┬────────┘
                                             │
┌────────────────────────────────────────────▼────────┐
│                  Service Layer                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Service  │  │ Service  │  │  Service          │   │
│  │    A     │  │    B     │  │    C              │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────────────┘   │
└───────┼──────────────┼─────────────┼────────────────┘
        │              │             │
┌───────▼──────────────▼─────────────▼────────────────┐
│              Data / External Layer                    │
│  ┌────────┐ ┌───────┐ ┌──────────┐ ┌────────────┐   │
│  │Database │ │ Cache │ │ External │ │ External   │   │
│  │        │ │       │ │  API 1   │ │  API 2     │   │
│  └────────┘ └───────┘ └──────────┘ └────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Components

### API Layer (`path/to/api/`)
Describe the router, middleware chain, and how requests are handled.

### Service Layer (`path/to/services/`)
Business logic. Describe how services are structured and their responsibilities.

### Repository Layer (`path/to/repo/`)
Data access. Describe the database driver, migration strategy, and patterns.

## Data Flow

Request → Router → Middleware → Handler → Service → Repository → Database
                                                  ↘ Cache

## External Integrations

| Service | Purpose | Required |
|---------|---------|----------|
| Database | Primary data store | Yes |
| Cache | Response caching, rate limiting | Yes |
| External API 1 | Description | Yes |
| External API 2 | Description | Optional |

## Infrastructure

- Hosting platform and configuration
- Database hosting
- Cache hosting
- File storage
```

### patterns.md

Coding conventions the team follows.

```markdown
---
type: patterns
updated: 2026-04-11
---

# Patterns

## Error Handling
- Services return `(result, error)` — never panic.
- Wrap errors with context: `fmt.Errorf("createUser: %w", err)`.
- API layer maps error types to HTTP codes via central middleware.

## Naming
- Interfaces: verb-er suffix (`UserReader`, `TokenValidator`).
- Constructors: `NewXxx(deps) *Xxx`.
- Files: snake_case matching the primary type they define.

## Testing
- Table-driven tests for pure functions.
- Integration tests hit real database (Docker via testcontainers).
- No mocks for database layer — test against real PostgreSQL.

## Git
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`.
- Squash merge to main. Feature branches: `feat/short-description`.
```

### bugs.md

Notable bugs with root cause analysis.

```markdown
---
type: bugs
updated: 2026-04-11
---

# Bugs

## Race condition in concurrent webhook delivery
**Date:** 2026-04-08
**Symptom:** Duplicate webhook deliveries under load.
**Root cause:** Webhook worker used shared slice without mutex. Two goroutines could read the same batch.
**Fix:** Added per-batch channel instead of shared slice. PR #142.
**Lesson:** Never share mutable state between goroutines without synchronization.
```

### features/*.md

One page per significant feature, tracking its full lifecycle. Created when a feature is first built. Updated when bugs are fixed, decisions change, or refactoring happens. This is the connective tissue — when someone asks "what's the story of X?", this page has the answer.

```markdown
---
type: feature
updated: 2026-05-20
---

# Webhook Delivery

## Overview
Async webhook delivery system that sends event payloads to subscriber endpoints with retry logic.

## Timeline

- **2026-01-15** — Initial implementation. Chose Redis queue over RabbitMQ for simplicity. See [[decisions.md#chose-redis-queue-for-webhooks]].
- **2026-03-08** — Added retry with exponential backoff (max 5 attempts, 30min cap).
- **2026-05-18** — Fixed race condition: shared slice in worker replaced with per-batch channel. See [[bugs.md#race-condition-in-webhook-delivery]].
- **2026-05-20** — Added dead letter queue for permanently failed deliveries.

## Current State
Working. Handles ~2k deliveries/min. Retry logic covers transient failures. Dead letters logged for manual review.

## Key Files
- `internal/webhook/dispatcher.go` — main delivery loop
- `internal/webhook/retry.go` — backoff logic
- `internal/webhook/worker.go` — per-batch workers
```

**When to create a feature page:** When a feature spans multiple sessions, involves architectural decisions, or is complex enough that a future developer would ask "what's the story here?" Not every small change needs one — only features that have a lifecycle.

## Linking with [[wikilinks]]

Brain pages reference each other using `[[wikilinks]]`. This connects entries across pages so the LLM can trace a feature's full story.

### Syntax

```
[[page.md]]                              → link to a page
[[page.md#section-anchor]]               → link to a specific section
[[features/webhook-delivery.md]]         → link to a feature page
```

### Anchor Format

Section headers become anchors by lowercasing and hyphenating:
- `## Chose Redis Queue for Webhooks` → `#chose-redis-queue-for-webhooks`
- `## Race Condition in Webhook Delivery` → `#race-condition-in-webhook-delivery`

### When to Link

| Situation | Link from → to |
|-----------|---------------|
| Bug fix references original feature | `bugs.md` → `[[features/X.md]]` |
| Decision relates to a feature | `decisions.md` → `[[features/X.md]]` |
| History entry about a feature | `history.md` → `[[features/X.md]]` |
| Feature references its decisions | `features/X.md` → `[[decisions.md#anchor]]` |
| Feature references its bugs | `features/X.md` → `[[bugs.md#anchor]]` |
| Bug caused by an architectural decision | `bugs.md` → `[[decisions.md#anchor]]` |

### How the LLM Uses Links

When a developer asks about a topic, the LLM:
1. Greps all `.brain/` files for the keyword
2. Finds the most relevant page (often a feature page)
3. Follows `[[wikilinks]]` to gather related entries from other pages
4. Synthesizes the full story from all connected entries

This is what makes `.brain/` a wiki, not a log.

## Date Format

Every entry in `history.md`, `decisions.md`, `bugs.md`, and `features/*.md` timelines MUST have a `**Date:** YYYY-MM-DD` line immediately after the `## ` header. Full date required — never month-only (`2026-03`), never relative. This enables chronological sorting in the dashboard.

**Correct:**
```markdown
## Chose Redis over Memcached
**Date:** 2026-04-10
Content here...
```

**Wrong:**
```markdown
## 2026-04-10 — Chose Redis over Memcached
Content here...
```

The date goes in a `**Date:**` field, not in the header. Headers are for titles only.

## What NOT to Put in .brain/

- Code snippets longer than 5 lines (link to the file instead)
- Secrets, API keys, credentials
- Personal opinions or complaints
- Speculative future plans (only record what IS, not what MIGHT BE)
- Duplicate information already in README.md (reference it instead)

## Compaction

When a page exceeds **30 entries** or **150 lines**, compact it:

1. Create `archive/` directory: `mkdir -p .brain/archive`
2. Move entries older than 3 months to `.brain/archive/<page>-<year>.md`
3. Add a summary line at the bottom of the active page:

```markdown
> Older entries archived in [archive/history-2025.md](archive/history-2025.md)
```

Archive files use the same frontmatter with `type: archive`. They are still in git, still searchable, but not loaded into LLM context at session start.

## Merge Conflict Guidance

Brain pages are designed to be merge-friendly:

- `history.md`, `decisions.md`, `bugs.md` are append-only with dates — keep both entries, order by date.
- `index.md`, `architecture.md`, `patterns.md` may have real conflicts — read both versions and pick the more current one, or combine if both changes are valid.
- When in doubt, keep both versions and let the next session reconcile.

## Platform Integration

The repo's `CLAUDE.md`, `.cursor/rules`, and `AGENTS.md` point LLM tools to this file:

**CLAUDE.md** (Claude Code):
```
# Project Brain
Read .brain/SCHEMA.md at session start for instructions on working with this project's brain.
Read .brain/index.md for project context.
```

**.cursor/rules** (Cursor):
```
Read .brain/SCHEMA.md at session start for instructions on working with this project's brain.
Read .brain/index.md for project context.
```

**AGENTS.md** (Codex):
```
Read .brain/SCHEMA.md at session start for instructions on working with this project's brain.
Read .brain/index.md for project context.
```

## Custom Pages

Teams can add domain-specific pages under `.brain/custom/`:

```
.brain/custom/
├── api-versioning.md    # API versioning strategy
├── deployment.md        # Deploy process and rollback procedures
├── onboarding.md        # New developer setup guide
└── incidents.md         # Post-mortem summaries
```

Custom pages use the same frontmatter format with `type: custom`.
