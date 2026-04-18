# brain

Per-repo project memory that ships with git. Every developer who clones the repo gets full project context. Every LLM coding tool reads it at session start and updates it as the project evolves.

> Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) — an LLM-maintained personal knowledge base. brain takes the idea and applies it per-repo: instead of a personal wiki, every repository gets its own living memory that travels with the code.

```
.brain/
├── SCHEMA.md             LLM instructions + format rules (the brain of the brain)
├── index.md              What this project does, tech stack, team
├── architecture.md       System structure, components, data flow
├── decisions.md          Why things are the way they are
├── patterns.md           Coding conventions and team practices
├── history.md            Timeline of significant changes
├── bugs.md               Notable bugs with root cause analysis
└── features/             One page per significant feature
    └── webhook-delivery.md
```

## Why

Your codebase has a README that tells people what to install. Git history tells people what changed. But nobody records **why** things were built the way they were.

Three months later, a developer asks "why is auth custom instead of using a library?" and the answer is buried in a Slack thread that got deleted, or in the head of someone who left.

`.brain/` captures the WHY and keeps it next to the code, in git, forever.

## How It Works

brain has three tiers — each builds on the previous:

### Tier 1: Zero Install (just clone)

Any repo with `.brain/` works out of the box. No install needed.

1. Developer clones a repo that has `.brain/`
2. `CLAUDE.md` (or `.cursor/rules`, `AGENTS.md`) tells the LLM to read `.brain/SCHEMA.md`
3. `SCHEMA.md` contains everything: session behavior, update process, format rules
4. The LLM reads brain pages, tracks reasoning during the session, updates pages after significant changes

**Nothing to install. Nothing to configure. Just git clone and work.**

### Tier 2: Power Commands (`/brain` skill)

Install the skill to get commands for bootstrapping and querying:

```
/brain init         Bootstrap .brain/ from existing repo
/brain query        Search across all pages, follow [[wikilinks]]
/brain dashboard    Generate interactive HTML dashboard
/brain doctor       Full diagnostic: integrity, format, content, sync
/brain status       Show what's in .brain/ and when pages were last updated
/brain update       Manually trigger brain update
/brain decide       Quick-add a decision
/brain bug          Quick-add a bug
/brain history      Quick-add a history entry
```

### Tier 3: Auto-Update (hooks)

Install hooks for fully automatic brain maintenance:

- **Session start**: LLM automatically reads `.brain/` for project context
- **After every commit**: LLM checks the conversation for brain-worthy changes and updates pages if needed

The developer just works. Brain maintains itself.

## Install

**One-liner (installs skill + hooks):**

```bash
curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh | bash
```

**From source:**

```bash
git clone https://github.com/batucodein/brain.git
cd brain
./install.sh
```

Restart your Claude Code session after installing.

## Usage

```
/brain              Auto-detect: init if no .brain/, otherwise show status
/brain init         Bootstrap .brain/ from existing repo
/brain status       Show what's in .brain/ and when pages were last updated
/brain update       Review session changes and update relevant pages
/brain query "X"    Ask a question — searches across all pages, follows [[wikilinks]]
/brain dashboard    Generate interactive dashboard of all entries
/brain doctor       Full diagnostic: integrity, format, content quality, sync (--dry-run to diagnose only, skip fixes)
/brain uninstall    Remove brain from this machine (keeps .brain/ in repos)
```

### Quick Commands

```
/brain decide "Chose Redis over Memcached — need pub/sub for cache invalidation"
/brain bug "Race condition in webhook worker — shared slice without mutex"
/brain history "Migrated CI from CircleCI to GitHub Actions"
```

## The WHY Problem

brain captures reasoning through 5 event types that the LLM tracks during every session:

1. **A choice was made** — Multiple approaches existed, one was picked
2. **Something broke and was understood** — Bug reported, investigated, root cause found
3. **Something was rejected** — An approach was proposed and turned down
4. **A constraint shaped the work** — Performance, cost, time, compatibility steered the implementation
5. **The system changed structurally** — New component, integration, or dependency

After each commit, the LLM checks if any of these happened and updates the relevant brain pages. If no WHY exists in the conversation, it asks the developer or marks the entry for later.

## Example: The 3-Developer Story

This is the scenario brain is built for.

**January — Dev A builds webhook delivery:**

```markdown
# features/webhook-delivery.md

## Timeline
- **2026-01-15** — Initial implementation. Async delivery via Redis queue.
  See [[decisions.md#chose-redis-queue-for-webhooks]].
```

**May — Dev B fixes a race condition:**

```markdown
# bugs.md

## Race condition in webhook delivery
**Date:** 2026-05-18
**Root cause:** Shared slice in worker without mutex.
**Fix:** Per-batch channel. PR #142.
**Feature:** [[features/webhook-delivery.md]]
```

The feature page gets updated too:

```markdown
# features/webhook-delivery.md (updated)

## Timeline
- **2026-01-15** — Initial implementation. See [[decisions.md#chose-redis-queue-for-webhooks]].
- **2026-05-18** — Fixed race condition. See [[bugs.md#race-condition-in-webhook-delivery]].
```

**September — Dev C asks: "What's the story of webhook delivery?"**

The LLM reads `features/webhook-delivery.md`, follows the `[[wikilinks]]` to the original decision and the bug fix, and answers:

> Webhook delivery was built in January using a Redis queue (chosen over RabbitMQ for simplicity). In May, a race condition was found — shared slice in the worker — and fixed with per-batch channels. It currently handles ~2k deliveries/min.

Full story. Three developers. Nine months. Zero Slack archaeology.

## Git Conventions

Brain updates are included in the same commit as the code they describe:

```bash
git add .brain/ src/
git commit -m "feat: add Redis caching layer"
```

One change = one commit. The LLM updates brain pages before committing, then stages everything together. No separate commits, no special prefixes.

## Dashboard

`/brain dashboard` generates a standalone HTML dashboard showing all brain entries organized by category, sorted chronologically. No server needed — opens in your browser.

- **Sidebar navigation** — Jump between Overview, History, Decisions, Features, Bugs, Patterns, Architecture
- **Chronological ordering** — Every entry sorted by date within its category
- **Search** — Filter all entries in real-time
- **Date badges** — Every entry shows its `YYYY-MM-DD` date
- **Context tags** — Decisions show context and status, bugs show symptom/root cause/fix

Dark theme (background #0A0E27) with color-coded sections matching the brain type system.

## Platform Support

brain works with any LLM coding tool. `SCHEMA.md` ships inside `.brain/` and contains everything the LLM needs. Platform-specific files just point to it:

| Platform     | File              | What it says |
|-------------|-------------------|--------------|
| Claude Code | `CLAUDE.md`       | Read `.brain/SCHEMA.md` |
| Cursor      | `.cursor/rules`   | Read `.brain/SCHEMA.md` |
| Codex       | `AGENTS.md`       | Read `.brain/SCHEMA.md` |

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   In the repo (git)                   │
│                                                       │
│  .brain/SCHEMA.md    ← LLM instructions + format     │
│  .brain/index.md     ← Project overview               │
│  .brain/*.md         ← Brain pages                    │
│  CLAUDE.md           ← Points to SCHEMA.md            │
│                                                       │
│  Any LLM that reads CLAUDE.md can maintain brain.     │
│  Zero install required.                               │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│               Local install (optional)                │
│                                                       │
│  ~/.claude/skills/brain/SKILL.md  ← /brain commands   │
│  ~/.claude/hooks/                 ← Auto-update hooks  │
│  ~/.claude/settings.json          ← Hook registration  │
│                                                       │
│  Adds: /brain init, query, dashboard, doctor          │
│  Adds: Auto-read on session start                     │
│  Adds: Auto-update check after every commit           │
└──────────────────────────────────────────────────────┘
```

## Token & Storage Cost

| What | Size | When loaded |
|------|------|-------------|
| SCHEMA.md (LLM instructions) | ~1,200 tokens | Session start |
| index.md (project overview) | ~400 tokens | Session start |
| All brain pages | ~2,200 tokens | On demand |
| Full .brain/ on disk | ~15 KB | Always in git |

For context, a single medium source file is 3,000+ tokens. brain's overhead is negligible.

## Schema

See [SCHEMA.md](skill/SCHEMA.md) for the full format specification — LLM instructions, page types, frontmatter fields, `[[wikilink]]` syntax, update rules, compaction strategy, and merge conflict guidance.

## Inspiration

This project is inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) pattern — an LLM that maintains a personal knowledge base through an ingest → compile → query → lint cycle. brain adapts this for collaborative software development: instead of one person's wiki, it's a shared project memory that every team member's LLM reads and writes to.

## License

MIT
