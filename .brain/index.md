---
type: index
updated: 2026-04-18
---

# brain

Per-repo LLM project memory that ships with git. A repo with `.brain/` gives any LLM coding tool (Claude Code, Cursor, Codex) full project context at session start.

The tool captures the **WHY** behind decisions, bugs, and architectural moves — the reasoning that normally lives in Slack threads and people's heads. It keeps that reasoning next to the code, in git, forever.

## Tech Stack

- **Languages:** Bash (installer + hooks), Markdown (content + schema)
- **Dependencies:** git, jq, Claude Code (or any LLM tool that reads `CLAUDE.md`)
- **Template format:** YAML frontmatter + Markdown with `[[wikilinks]]`
- **Installation:** one-liner `curl -fsSL .../install.sh | bash`

## Key Directories

- `install.sh` — bootstrap script (skill + hooks + settings.json registration)
- `skill/SKILL.md` — command specs for `/brain init`, `update`, `query`, `doctor`, `topic`, etc.
- `skill/SCHEMA.md` — authoritative format rules; shipped per-repo
- `skill/DIAGNOSTICS.md` — `/brain doctor` playbook; skill-local only
- `skill/templates/` — page templates (index, architecture, decisions, patterns, history, bugs, topic) + dashboard.html
- `skill/hooks/` — session-start and post-commit hook scripts
- `.brain/` — this directory; brain's own project memory (dogfooding)
- `ARCHITECTURE.md` — full architectural doc: three-tier model, flows, integrity analysis
- `README.md` — user-facing quickstart

## Team

Solo project. Author: batuhan.ozalhan@gmail.com. Built in collaboration with Claude (Anthropic).

See [[architecture.md]] for the system design; [[decisions.md]] for why things are the way they are; [[topics/zero-install.md]] and [[topics/slugging.md]] for cross-cutting concerns.
