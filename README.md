# brain

Per-repo project memory that ships with git. Every developer who clones the repo gets full project context. Every LLM coding tool reads it at session start and updates it as the project evolves.

> Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) — an LLM-maintained personal knowledge base. brain takes the idea and applies it per-repo: instead of a personal wiki, every repository gets its own living memory that travels with the code.

```
.brain/
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

brain is a skill for LLM coding tools (Claude Code, Cursor, Codex). When you start a session:

1. The LLM reads `.brain/index.md` to understand your project
2. Based on your task, it reads relevant pages (architecture for refactoring, bugs for debugging)
3. As you work, it updates pages with new decisions, bug fixes, and history
4. Feature pages connect everything with `[[wikilinks]]` — so you can trace a feature's full lifecycle

No CLI binary. No server. No database. Just markdown files and an LLM that knows how to maintain them.

## Install

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh | bash
```

**From source:**

```bash
git clone https://github.com/batucodein/brain.git
cd brain
./install.sh
```

**Manual:**

```bash
mkdir -p ~/.claude/skills/brain/templates
cp skill/SKILL.md skill/SCHEMA.md ~/.claude/skills/brain/
cp skill/templates/*.md ~/.claude/skills/brain/templates/
```

Then add to `~/.claude/CLAUDE.md`:

```markdown
# brain
- **brain** (`~/.claude/skills/brain/SKILL.md`) - per-repo project memory. Trigger: `/brain`
When the user types `/brain`, invoke the Skill tool with `skill: "brain"` before doing anything else.
When a repo has `.brain/` directory, read `.brain/index.md` at session start for project context.
```

Restart your Claude Code session after installing.

## Usage

```
/brain              Auto-detect: init if no .brain/, otherwise show status
/brain init         Bootstrap .brain/ from existing repo
/brain status       Show what's in .brain/ and when pages were last updated
/brain update       Review session changes and update relevant pages
/brain query "X"    Ask a question — searches across all pages, follows [[wikilinks]]
/brain health       Check for stale pages, broken links, compaction needed
/brain graph        Generate interactive D3.js graph visualization
```

### Quick Commands

```
/brain decide "Chose Redis over Memcached — need pub/sub for cache invalidation"
/brain bug "Race condition in webhook worker — shared slice without mutex"
/brain history "Migrated CI from CircleCI to GitHub Actions"
```

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

Brain updates are committed separately from code with a `brain:` prefix:

```bash
git add .brain/
git commit -m "brain: record Redis caching decision"
```

This keeps PR diffs clean. Filter commits:

```bash
git log --grep="^brain:"                    # only brain updates
git log --invert-grep --grep="^brain:"      # only code changes
```

## Graph Visualization

`/brain graph` generates a standalone HTML file with an interactive D3.js force-directed graph. No server needed — just opens in your browser.

- **Color-coded nodes** — Features (blue), Decisions (green), Bugs (red), History (purple), Architecture (amber), Patterns (pink)
- **Hover** to see content preview and connections
- **Search** to find specific entries and highlight their neighborhood
- **Filter** by type to focus on decisions, bugs, or features
- **Drag** nodes to rearrange, scroll to zoom

The graph shows how brain entries connect through `[[wikilinks]]` — making the relationships between features, decisions, and bugs visible at a glance.

## Platform Support

brain works with any LLM coding tool. On init, it creates platform-specific instruction files:

| Platform     | File              |
|-------------|-------------------|
| Claude Code | `CLAUDE.md`       |
| Cursor      | `.cursor/rules`   |
| Codex       | `AGENTS.md`       |

Each file tells the LLM: "Read `.brain/index.md` at session start. Update pages when you make significant changes."

## Token & Storage Cost

| What | Size | When loaded |
|------|------|-------------|
| index.md (session start) | ~400 tokens | Every session |
| All 6 pages | ~2,200 tokens | On demand |
| Full .brain/ on disk | ~9 KB | Always in git |
| Compressed in git pack | ~4 KB | - |

For context, a single medium source file is 3,000+ tokens. brain's overhead is negligible.

## Schema

See [SCHEMA.md](skill/SCHEMA.md) for the full format specification — page types, frontmatter fields, `[[wikilink]]` syntax, update rules, compaction strategy, and merge conflict guidance.

## Inspiration

This project is inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) pattern — an LLM that maintains a personal knowledge base through an ingest → compile → query → lint cycle. brain adapts this for collaborative software development: instead of one person's wiki, it's a shared project memory that every team member's LLM reads and writes to.

## License

MIT
