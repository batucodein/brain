# brain

**Per-repo project memory that ships with git.** Every developer who clones the repo inherits full project context. Every LLM coding tool reads it at session start and maintains it as the project evolves.

> Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) pattern — an LLM-maintained knowledge base. brain applies the idea per-repo: instead of a personal wiki, every repository gets a living memory that travels with its code.

---

## The problem brain solves

Your codebase has:

- A **README** that tells people what to install and how to run it
- **Git history** that tells people what changed line-by-line
- **No place** for the *why*

Three months later, a developer asks *"why is auth custom instead of using a library?"* and the answer is buried in a Slack thread that got deleted, or in the head of someone who left.

brain captures the **WHY** and keeps it next to the code, in git, forever. Any LLM that reads your repo can answer questions about decisions, bugs, architectural shifts — without archaeology.

---

## A concrete example

**January** — Dev A builds webhook delivery:

```markdown
# features/webhook-delivery.md
## Timeline
- **2026-01-15** — Initial implementation. Async delivery via Redis queue.
  See [[decisions.md#chose-redis-queue-for-webhooks]].
```

**May** — Dev B fixes a race condition:

```markdown
# bugs.md
## Race condition in webhook delivery
**Date:** 2026-05-18
**Root cause:** Shared slice in worker without mutex.
**Fix:** Per-batch channel. PR #142.
**Feature:** [[features/webhook-delivery.md]]
```

The feature page auto-updates with a Timeline entry linking to the bug.

**September** — Dev C asks *"what's the story with webhook delivery?"*

The LLM reads `features/webhook-delivery.md`, follows the `[[wikilinks]]` to the original decision and the bug fix, and answers:

> Webhook delivery was built in January using a Redis queue (chosen over RabbitMQ for operational simplicity). In May, a race condition — shared slice in the worker — was fixed with per-batch channels. It currently handles ~2k deliveries/min.

Full story. Three developers. Nine months. Zero Slack archaeology.

---

## Directory layout

```
 .brain/
 ├── SCHEMA.md          authoritative format rules; shipped per-repo
 ├── index.md           project overview (what, tech stack, team)
 ├── architecture.md    system structure, components, data flow
 ├── decisions.md       why things were built this way (append-only)
 ├── patterns.md        coding conventions, error handling, testing
 ├── history.md         timeline of significant changes
 ├── bugs.md            notable bugs with root cause + fix
 ├── features/          one page per feature — full lifecycle
 │   └── webhook-delivery.md
 ├── topics/            cross-cutting narratives (subsystems, concepts)
 │   ├── redis.md
 │   └── auth.md
 ├── archive/           compacted old entries (still searchable)
 │   └── history-2024.md
 └── custom/            team-defined pages (onboarding, runbooks)
     └── oncall.md
```

---

## How it works

brain runs on three layers:

### 1. The graph (markdown + wikilinks)

Every page can reference any other via `[[wikilinks]]`:

```
 [[decisions.md#chose-redis]]        link to a specific entry
 [[features/auth.md]]                link to a feature's lifecycle
 [[topics/redis.md]]                 link to a cross-cutting narrative
 [[archive/decisions-2024.md#x]]     link to compacted content
```

There's no database, no embedding index, no vector search. Just markdown links the LLM reads and follows. Any human can open a file and see the connections.

### 2. The write loop (how knowledge enters brain)

```
 User writes code ──► git commit
                         │
                         ▼
                 post-commit hook fires
                         │
                         ├── amend/merge/rebase/revert → skip
                         │
                         └── normal commit → nudge the LLM
                         │
                         ▼
                 LLM runs /brain update
                         │
                         ▼
                 Watch for 5 event types (the "WHY"):
                   1. A CHOICE was made (alternatives weighed)
                   2. Something BROKE and was understood
                   3. Something was REJECTED
                   4. A CONSTRAINT shaped the work
                   5. The system changed STRUCTURALLY
                         │
                         ▼
                 Filter trivia (formatting, version bumps, renames)
                         │
                         ▼
                 Categorize → extract WHY → write entries + wikilinks
                         │
                         ▼
                 git commit .brain/
```

If no WHY exists in the conversation, the LLM asks the developer or marks the entry for later. **It never invents reasoning.**

### 3. The read loop (how brain answers questions)

```
 User asks something
      │
      ▼
 LLM already has baseline context from SessionStart hook:
   • knows .brain/ exists
   • knows topic page names
      │
      ▼
 Grep for keywords (includes archive/) → rank matches
      │
      ▼
 Read the top 3-5 pages, follow [[wikilinks]] one level deep
      │
      ▼
 If a wikilink doesn't resolve → check archive/ for the slug
      │
      ▼
 Synthesize chronological answer with citations
```

---

## Features

### Three installation tiers

| Tier | What you get | How to enable |
|---|---|---|
| **1. Zero install** | Any LLM that reads `CLAUDE.md`/`.cursor/rules`/`AGENTS.md` can maintain `.brain/` via the pointer to `SCHEMA.md` | `git clone` a brain-enabled repo |
| **2. Skill** | 11 `/brain` commands available in Claude Code | `./install.sh` (no flags) |
| **3. Hooks** | Brain auto-reads on session start + nudges to update after commits | Same installer — hooks included |

Each tier builds on the previous. You can stop at any tier.

### Commands (skill tier)

| Command | What it does |
|---|---|
| `/brain` | Auto-detect: `init` if no `.brain/`, otherwise `status` |
| `/brain init` | Bootstrap `.brain/` from an existing repo by analyzing the code |
| `/brain status` | Show what's in `.brain/` and when pages were last updated |
| `/brain update` | Manually trigger a brain update for the current session |
| `/brain decide "<text>"` | Quick-add an architectural decision |
| `/brain bug "<text>"` | Quick-add a notable bug |
| `/brain history "<text>"` | Quick-add a history entry |
| `/brain topic <name>` | Create or sync a topic page (cross-cutting narrative) |
| `/brain query "<question>"` | Search all pages, follow `[[wikilinks]]`, synthesize answer |
| `/brain dashboard` | Generate an interactive HTML dashboard |
| `/brain doctor` | Diagnose integrity, format, and content (with `--dry-run`) |
| `/brain uninstall` | Remove brain skill + hooks from the machine (keeps `.brain/` in repos) |

### Topic pages — the synthesis layer

Event-type pages (decisions/bugs/history) are sliced by *what kind of event*. Topic pages are sliced by *domain*:

```
 Without topics:
   Redis story = grep across decisions.md + bugs.md + history.md + features/
   + stitching together manually

 With topics:
   Redis story = read topics/redis.md
                 follow the 7 Timeline wikilinks
                 full narrative emerges in order
```

Topic creation is **explicit** (`/brain topic redis`). The LLM never auto-creates topic pages — that prevents weak, sticky topics. Maintenance is automatic: `/brain update` appends Timeline bullets to matching topics.

### Archive — cold storage with zero token tax

Brain pages grow forever. Compaction moves entries older than 3 months to `.brain/archive/<page>-<year>.md`:

- Active pages stay small → cheap at session start
- Archives stay in git → still searchable, still in history
- The LLM reaches for archive on demand (via `/brain query`, wikilink fallback, or organic questions about old events)

Topic Timelines can point into archive. Doctor detects compacted links and suggests repointing.

### Dashboard

`/brain dashboard` generates a standalone HTML file with:

- **Sidebar nav:** Overview, History, Decisions, Features, Topics, Custom, Bugs, Patterns, Architecture
- **Entry cards** sorted by date, color-coded by type
- **Real-time search** across all entries
- **Works offline** — no server, no JS framework

Opens in your browser; dark theme (#0A0E27).

### Doctor — integrity catcher

`/brain doctor` reads `SCHEMA.md` + a skill-local playbook at runtime and walks these invariants:

- Structural: core pages exist, frontmatter valid, `type:` matches filename
- Content: dates valid, `updated:` matches latest entry, wikilinks resolve (with archive-slug recovery)
- Compaction: flag pages past the threshold
- Installation: hooks registered, `jq` available
- Git: `.brain/` tracked, not gitignored

Auto-fixes are whitelisted to exactly two mechanical operations (restore `SCHEMA.md`, re-register hooks). Everything else is reported for the user.

### Deterministic slug algorithm

Every `## Header` produces the same anchor across every LLM and tool. `[[page.md#anchor]]` resolves identically in Claude Code, Cursor, Codex. Specified in SCHEMA with a Python reference implementation + worked examples.

### Hooks — the reliability layer

Two shell scripts wire into Claude Code:

- **SessionStart hook:** every Claude session that opens in a brain-enabled repo sees `.brain/` exists + topic page names (~180 tokens every session). Content is read on demand, never pre-loaded.
- **Post-commit hook:** after `git commit*`, nudges the LLM to check for brain-worthy changes. Skips amend, merge, rebase, cherry-pick, and revert commits (no session context to capture).

### Self-documenting (brain dogfoods itself)

The brain repo uses brain. Clone it, run `/brain query "why topic pages?"`, get a real synthesized answer. The `.brain/` in this repo is a working example of well-maintained brain content.

---

## Prerequisites

- **bash** — the installer and hooks are shell scripts
- **git** — brain is per-repo and ships in git history
- **jq** — JSON processor used by the installer + both hooks
- **Claude Code** (or any LLM tool that reads `CLAUDE.md` / `.cursor/rules` / `AGENTS.md`)

**Installing jq:**

| Platform | Command |
|---|---|
| macOS | `brew install jq` |
| Debian / Ubuntu | `sudo apt install jq` |
| Fedora / RHEL | `sudo dnf install jq` |
| Arch | `sudo pacman -S jq` |
| Other | see [jqlang.org/download](https://jqlang.org/download/) |

The installer detects missing jq and offers to install it for you if a supported package manager is available. Otherwise it prints instructions and exits cleanly — no partial installs.

---

## Install

**One-liner (skill + hooks):**

```bash
curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh | bash
```

**From source:**

```bash
git clone https://github.com/batucodein/brain.git
cd brain
./install.sh
```

**Refresh hooks only** (if `/brain doctor` reports hooks missing or unregistered):

```bash
~/.claude/skills/brain/install.sh --hooks-only
```

Restart your Claude Code session after installing.

---

## Quick commands

Record something without walking through `/brain update`:

```bash
/brain decide "Chose Redis over Memcached — need pub/sub for cache invalidation"
/brain bug "Race condition in webhook worker — shared slice without mutex"
/brain history "Migrated CI from CircleCI to GitHub Actions"
/brain topic redis               # create topic page
/brain topic redis --sync        # backfill Timeline from existing entries
```

All quick-adds run a same-day duplicate check + category-mismatch check before inserting. Both fold into one y/N prompt — no double-prompting.

---

## Git conventions

Brain updates ship in the same commit as the code they describe:

```bash
git add .brain/ src/
git commit -m "feat: add Redis caching layer"
```

One change = one commit. The LLM updates brain pages before committing, then stages everything together.

When the post-commit hook triggers an update *after* the code commit (you forgot, or the LLM caught it retroactively), brain makes a separate commit with the `brain:` prefix:

```bash
git add .brain/
git commit -m "brain: captured Redis caching decision"
```

---

## Platform support

brain works with any LLM coding tool that reads a project instruction file. `SCHEMA.md` ships inside `.brain/` with everything the LLM needs; platform files just point to it.

| Platform | File | Content |
|---|---|---|
| Claude Code | `CLAUDE.md` | "Read `.brain/SCHEMA.md`" |
| Cursor | `.cursor/rules` | "Read `.brain/SCHEMA.md`" |
| Codex | `AGENTS.md` | "Read `.brain/SCHEMA.md`" |

`/brain init` writes to every existing platform file and creates none that don't exist (respects your tool choice).

---

## Architecture

```
 ┌──────────────────────────────────────────────────────────────┐
 │                     Tier 1 — in the repo (git)                │
 │                                                               │
 │   .brain/SCHEMA.md       authoritative format rules          │
 │   .brain/index.md        project overview                    │
 │   .brain/{decisions,bugs,history}.md   event logs            │
 │   .brain/features/*.md   per-feature lifecycles              │
 │   .brain/topics/*.md     cross-cutting narratives            │
 │   .brain/archive/*.md    compacted old entries                │
 │   .brain/custom/*.md     team-defined pages                  │
 │   CLAUDE.md              points to SCHEMA.md                 │
 │                                                               │
 │   Any LLM that reads the pointer can maintain brain.         │
 │   Zero install required.                                     │
 └──────────────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────────────┐
 │            Tier 2 — skill (per-user, optional)               │
 │                                                               │
 │   ~/.claude/skills/brain/SKILL.md       /brain command specs │
 │   ~/.claude/skills/brain/SCHEMA.md      canonical format     │
 │   ~/.claude/skills/brain/DIAGNOSTICS.md doctor playbook      │
 │   ~/.claude/skills/brain/templates/     page starter templates│
 │                                                               │
 │   Enables: all 11 /brain commands                             │
 └──────────────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────────────┐
 │            Tier 3 — hooks (per-user, optional)                │
 │                                                               │
 │   ~/.claude/hooks/session-start-brain.sh   discovery          │
 │   ~/.claude/hooks/post-commit-brain.sh     write trigger      │
 │   ~/.claude/settings.json                  registration       │
 │                                                               │
 │   Enables: auto-read on session start, auto-update nudge     │
 └──────────────────────────────────────────────────────────────┘
```

For the full architectural doc — every command flow, every hook flow, edge cases, integrity analysis — see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Token & storage cost

| What | Size | When loaded |
|---|---|---|
| SessionStart hook `additionalContext` | ~180 tokens | Every Claude Code session in a brain-enabled repo |
| `index.md` (project overview) | ~400 tokens | Loaded by the LLM at session start (per SCHEMA instructions) |
| One topic, feature, or event page | ~300–500 tokens | On demand when referenced or queried |
| `SCHEMA.md` (format rules) | ~10,700 tokens | **Only** when the LLM is updating pages; NOT at session start |
| `DIAGNOSTICS.md` (doctor playbook) | ~4,200 tokens | **Only** when `/brain doctor` runs |
| Full `.brain/` on disk | ~15 KB minimum | Always in git |

Session-start cost is low (~580 tokens total including `index.md`). A single medium source file costs 3,000+ tokens — brain's overhead is negligible for the value it delivers.

---

## Schema

See [skill/SCHEMA.md](skill/SCHEMA.md) for the full format specification — LLM instructions, the 5 event types, page types, frontmatter fields, `[[wikilink]]` syntax and anchor slug algorithm, update rules, compaction strategy, merge conflict guidance (4 cases), decision supersession, and feature removal conventions.

---

## Inspiration

Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) pattern — an LLM that maintains a personal knowledge base through an ingest → compile → query → lint cycle. brain adapts this for collaborative software development: instead of one person's wiki, it's a shared project memory that every team member's LLM reads and writes to.

---

## License

MIT
