---
name: brain
description: Per-repo project memory that ships with git. Bootstrap, maintain, and query .brain/ for full project context.
trigger: /brain
---

# /brain

Per-repo project memory tracked in git. Every developer who clones the repo gets full project context. Every LLM tool reads `.brain/` at session start and updates it as the project evolves.

**How it works:** `.brain/SCHEMA.md` ships with the repo and contains everything an LLM needs — session behavior, update process, format rules. No local install required for basic brain functionality. This skill adds power commands on top.

## Usage

```
/brain                    # Auto-detect: init if no .brain/, otherwise status
/brain init               # Bootstrap .brain/ from existing repo (or create empty for new repo)
/brain status             # Show what's in .brain/ and when each page was last updated
/brain update             # Review current session's changes and update relevant pages
/brain decide "<text>"    # Record an architectural decision
/brain bug "<text>"       # Record a notable bug fix
/brain history "<text>"   # Add a history entry
/brain query "<question>" # Ask a question — search pages, follow links, synthesize answer
/brain topic <name>       # Create or sync a topic page (add --sync [--keywords "a,b,c"] to backfill Timeline)
/brain dashboard          # Generate interactive dashboard of all .brain/ entries
/brain doctor             # Full diagnostic: integrity, format, content quality, staleness
/brain uninstall          # Remove brain skill, hooks, and config from this machine
```

## What You Must Do When Invoked

Parse the subcommand from the user's message. If no subcommand, auto-detect: check if `.brain/` exists. If not, run `init`. If yes, run `status`.

---

## Command: init

Bootstrap `.brain/` for this repository.

### Step 1 — Check if .brain/ already exists

```bash
ls .brain/index.md 2>/dev/null && echo "EXISTS" || echo "NO_BRAIN"
```

If `EXISTS`: tell the user `.brain/` is already initialized. Offer to run `status` instead. Stop here.

If `NO_BRAIN`: continue to Step 2.

### Step 2 — Analyze the repository

Determine if this is an existing repo with history or a fresh repo.

```bash
git log --oneline -1 2>/dev/null && echo "HAS_HISTORY" || echo "NO_HISTORY"
```

**If NO_HISTORY (new repo):** Skip to Step 3 with empty/minimal content for all pages.

**If HAS_HISTORY:** Run a comprehensive analysis. This is the most important step — the quality of the brain depends on how deeply you understand the codebase. Use the Agent tool or run multiple reads in parallel.

**Print progress after each phase so the user knows what's happening.**

**Phase A — Surface scan (run in parallel):**
After Phase A completes, print: `Phase A: Found [language] project with [N] files, [N] commits, stack: [detected stack]...`

**2a. Repo structure:**
```bash
find . -maxdepth 3 -type f \( -name "*.go" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.java" -o -name "*.rs" -o -name "*.rb" -o -name "*.cs" -o -name "*.swift" -o -name "*.kt" -o -name "*.dart" -o -name "*.vue" -o -name "*.svelte" \) | head -80
```

**2b. Config files (detect stack):**
```bash
ls -la go.mod go.sum package.json tsconfig.json Cargo.toml Gemfile requirements.txt pyproject.toml pom.xml build.gradle Makefile Dockerfile docker-compose.yml .github/workflows/*.yml 2>/dev/null
```

**2c. Existing documentation:**
```bash
cat README.md 2>/dev/null | head -200
cat CONTRIBUTING.md 2>/dev/null | head -100
cat CHANGELOG.md 2>/dev/null | head -100
ls docs/ 2>/dev/null | head -20
ls doc/ 2>/dev/null | head -20
```

**2d. Git history (comprehensive):**
```bash
git log --oneline -100
git log --format="%an" | sort -u
git tag -l --sort=-version:refname | head -20
```

**2e. Infrastructure:**
```bash
cat docker-compose.yml 2>/dev/null
cat Dockerfile 2>/dev/null | head -30
ls .github/workflows/ 2>/dev/null
ls migrations/ 2>/dev/null | head -20
```

**Phase B — Deep code analysis (CRITICAL — this is what makes the brain useful):**
After Phase B completes, print: `Phase B: Read [N] entry points, [N] services, [N] migrations, found [N] bug-fix commits...`

After Phase A, you know the language and structure. Now read the actual code:

**2f. Entry points — read FULL files, not just first 30 lines:**
Read the main entry point(s): `main.go`, `cmd/*/main.go`, `app.py`, `index.ts`, `src/main.*`, `Main.java`, `Program.cs`, `lib.rs`. This shows how the app boots, what dependencies it wires up, and the high-level structure.

**2g. Route definitions / API surface:**
Find and read the file(s) that define routes, endpoints, or URL patterns:
- Go: grep for `router`, `mux`, `Handle`, `Route` in server files
- Python: grep for `@app.route`, `urlpatterns`, `router`
- Node/TS: grep for `app.get`, `app.post`, `router.`, `createTRPCRouter`
- Java: grep for `@GetMapping`, `@PostMapping`, `@RequestMapping`

Read these files fully — they map the entire API surface and reveal every feature.

**2h. Domain/model layer:**
Read the files that define core business entities:
- Go: `internal/domain/`, `models/`, `types/`
- Python: `models.py`, `schemas.py`, `domain/`
- TS: `types/`, `models/`, `prisma/schema.prisma`
- Java: `domain/`, `entity/`, `model/`

These show what the system actually manages.

**2i. Service/business logic layer:**
Read 3-5 key service files (the ones with the most logic, not just CRUD). Look in:
- `internal/service/`, `services/`, `use_cases/`, `internal/*/handler.go`
- Read enough to understand what each major feature DOES, not just what files exist

**2j. Database schema:**
Read migration files or schema definitions to understand the data model:
```bash
ls migrations/ 2>/dev/null && cat migrations/*up*.sql 2>/dev/null | head -200
cat prisma/schema.prisma 2>/dev/null
cat db/schema.rb 2>/dev/null | head -200
```

**2k. Bug extraction from git (thorough):**
```bash
git log --oneline --all --grep="fix" --grep="bug" --grep="hotfix" --grep="patch" --grep="crash" --grep="race" --grep="leak" --grep="broken" --grep="revert" -i | head -30
```
For the top 5 most significant-looking fixes, read the commit message AND the diff:
```bash
git show <commit-hash> --stat
git show <commit-hash> -- '*.go' '*.py' '*.ts' '*.js' | head -80
```
This reveals actual root causes and fixes, not just commit titles.

**2l. Feature identification from git:**
```bash
git log --oneline --all --grep="feat" --grep="add" --grep="implement" --grep="new" -i | head -30
```
Cross-reference with the directory structure: each major directory under `internal/`, `src/`, or `app/` likely represents a feature. For each, check git log for that path:
```bash
git log --oneline -- <path> | head -10
```

**Phase C — Architecture mapping:**
After Phase C completes, print: `Phase C: Mapped [N]-layer architecture, [N] external integrations...`

After reading the code, map the actual architecture — not guessed from folder names, but understood from how components call each other:

**2m. Dependency flow:**
From the entry point and route handlers, trace how a request flows:
- Which handler calls which service?
- Which service calls which repository/external API?
- What middleware is in the chain?
- What async/background processing exists?

**2n. External integrations:**
Find all external API calls, third-party SDKs, message queues, etc. Grep for:
```bash
grep -rl "http.Get\|http.Post\|fetch(\|axios\|requests.get\|NewClient" --include="*.go" --include="*.py" --include="*.ts" --include="*.js" . 2>/dev/null | head -20
```
Read these files to understand what external services the app talks to.

### Step 3 — Generate .brain/ pages

Create the `.brain/` directory and all core pages.

```bash
mkdir -p .brain/custom .brain/features .brain/topics .brain/archive
```

(The `topics/` directory starts empty — topics are user-created via `/brain topic <name>`.)

**Copy SCHEMA.md into the repo** so it ships with git:
```bash
# Verify source exists before copying
if [ ! -f ~/.claude/skills/brain/SCHEMA.md ]; then
    echo "ERROR: brain skill not installed at ~/.claude/skills/brain/SCHEMA.md"
    echo "Install first: curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh | bash"
    exit 1
fi

cp ~/.claude/skills/brain/SCHEMA.md .brain/SCHEMA.md

# Verify copy succeeded
if [ ! -f .brain/SCHEMA.md ]; then
    echo "ERROR: Failed to copy SCHEMA.md to .brain/"
    exit 1
fi
```

For each page, use the analysis from Step 2 to generate content. Follow the format defined in `.brain/SCHEMA.md`.

**Generation rules:**

- **index.md**: Synthesize from README + repo structure + config files. Include: what the project does, tech stack, key directories, team (from git authors).

- **architecture.md**: Build from the actual code analysis (Phase B+C), NOT from folder names. Must include:
  - How the app boots (from entry point reading)
  - Request flow: from HTTP entry → middleware → handler → service → repo → DB/external
  - All external integrations discovered in step 2n
  - Infrastructure from docker-compose, CI configs, Dockerfiles
  - Data model summary from migration/schema reading

- **decisions.md**: Extract from README mentions of "chose", "decided", "why", "instead of". Check for ADR directories (`docs/adr/`, `doc/decisions/`). Also infer decisions from the code: if the stack uses Redis, that was a decision. If there's a custom auth middleware instead of a library, that was a decision. Each entry needs `**Date:** YYYY-MM-DD` — use the earliest git commit date related to that decision.

- **patterns.md**: Infer from the actual code read in Phase B: error handling patterns, naming conventions, test structure, dependency injection approach, data fetching patterns.

- **history.md**: Build from git tags, significant commits, and README changelog if present. Each entry needs `**Date:** YYYY-MM-DD`.

- **bugs.md**: Use the thorough bug extraction from step 2k. For each significant bug found in git history, read the commit diff to extract: symptom, root cause, fix, and lesson. Each entry needs `**Date:** YYYY-MM-DD`. If no bugs found in git, start empty.

- **features/*.md**: Create one page per major feature identified in step 2l. Each feature page must include:
  - Overview: what it does (from reading the actual service/handler code)
  - Timeline: key commits from `git log -- <path>` with `**Date:** YYYY-MM-DD`
  - Current state: working/in-progress/deprecated
  - Key files: list the actual source files
  - `[[wikilinks]]` to related entries in decisions.md, bugs.md, history.md

- **topics/*.md** (DO NOT CREATE DURING INIT): Topic pages are cross-cutting narrative syntheses (e.g., `topics/redis.md`, `topics/auth.md`). They emerge from explicit user intent via `/brain topic <name>`, not from repo analysis. Init sets up event-type pages + features; topics are a synthesis layer the user adds when a specific domain has proven it deserves one. Do not auto-create topic pages at init time — a topic created by init that never gets reviewed becomes stale noise.

**After generating pages, tell the user what was created and offer to review each page. Note that `.brain/topics/` was NOT populated — suggest the user run `/brain topic <name>` when a domain feels ready for synthesis (e.g., after 3+ related entries accumulate in `decisions.md` / `bugs.md`).**

### Step 4 — Install platform integration

brain supports three platform instruction files:
- `CLAUDE.md` (Claude Code)
- `.cursor/rules` (Cursor)
- `AGENTS.md` (Codex)

**Precedence rule:**
- **Update every file that already exists.** If the user or their teammates have chosen a tool (and therefore created one of these files), /brain init updates that file with the brain section.
- **Do NOT create files that don't exist.** Creating a `.cursor/rules` on a repo whose team doesn't use Cursor adds clutter and signals a tool choice the user didn't make.
- **Exception:** if NONE of the three exist, create `CLAUDE.md` as the default (since this is a Claude Code skill).

**Content marker for idempotent re-runs:** wrap the brain section with `<!-- brain:start -->` / `<!-- brain:end -->` comments so re-running /brain init replaces the section cleanly rather than appending.

**Procedure:**

```bash
HAS_CLAUDE=$([ -f CLAUDE.md ] && echo 1 || echo 0)
HAS_CURSOR=$([ -f .cursor/rules ] && echo 1 || echo 0)
HAS_AGENTS=$([ -f AGENTS.md ] && echo 1 || echo 0)

# If none exist, default to CLAUDE.md
if [ "$HAS_CLAUDE$HAS_CURSOR$HAS_AGENTS" = "000" ]; then
    HAS_CLAUDE=1
    touch CLAUDE.md
fi
```

For each file that `HAS_*` is 1:
1. Read the file.
2. If it contains `<!-- brain:start -->` ... `<!-- brain:end -->`, REPLACE the block (between the markers) with the canonical content.
3. Otherwise, APPEND the marker-wrapped block at the end of the file.

**Canonical block content** (same for all three files — SCHEMA's Platform Integration section is the source):
```markdown
<!-- brain:start -->
# Project Brain
This repo has .brain/ project memory. Read .brain/index.md for project context.
When updating brain pages, read .brain/SCHEMA.md for format rules and update instructions.
<!-- brain:end -->
```

**Rationale:** users often use multiple tools (Claude + Cursor together is common). Updating all that exist keeps instructions in sync. Never creating missing files respects the user's tool choice. The content markers make the operation idempotent.

### Step 5 — Offer auto-update hooks

After creating `.brain/`, check if the user already has brain hooks installed:

```bash
grep -q "post-commit-brain" ~/.claude/settings.json 2>/dev/null && echo "HOOKS_INSTALLED" || echo "NO_HOOKS"
```

**If HOOKS_INSTALLED:** Skip this step — everything is already set up.

**If NO_HOOKS:** Ask:

```
.brain/ initialized. 

Would you like to install auto-update hooks? This adds:
  - Auto-read: brain pages loaded at session start in any repo with .brain/
  - Auto-update: checks for brain-worthy changes after each commit

These are optional — brain works without them via CLAUDE.md + SCHEMA.md.
Install hooks? (y/n)
```

**If yes:** Guide the user to run the install script:
```
Run this to install hooks:
  curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh | bash
```

**If no:** Skip. Brain still works — CLAUDE.md in the repo tells the LLM to read SCHEMA.md.

### Step 6 — Commit brain initialization

Auto-commit the brain files:

```bash
git add .brain/ CLAUDE.md
git add .cursor/rules 2>/dev/null
git add AGENTS.md 2>/dev/null
git commit -m "brain: initialize project memory"
```

### Step 7 — Summary

Print a summary:

```
.brain/ initialized and committed with N pages:
  - index.md (project overview)
  - architecture.md (system structure)
  - decisions.md (N decisions extracted)
  - patterns.md (coding conventions)
  - history.md (N milestones)
  - bugs.md (N bugs documented)
  - SCHEMA.md (format rules + LLM instructions)

Platform integration:
  - CLAUDE.md ✓
  - .cursor/rules ✓
  - AGENTS.md ✓

Committed: "brain: initialize project memory"

Next: Review the generated pages with `/brain status`.
```

---

## Command: status

Show current state of `.brain/`.

### Step 1 — Check existence

```bash
ls .brain/index.md 2>/dev/null && echo "EXISTS" || echo "NO_BRAIN"
```

If `NO_BRAIN`: tell user to run `/brain init` first.

### Step 2 — Read all pages and summarize

For each `.brain/*.md` file:
1. Read the frontmatter to get `type` and `updated` date.
2. Count entries (for history/decisions/bugs: count `## ` headers).
3. Display a summary table.

Output format:
```
.brain/ status for: <project name from index.md>

| Page             | Updated    | Entries |
|------------------|------------|---------|
| index.md         | 2026-04-11 | -       |
| architecture.md  | 2026-04-10 | -       |
| decisions.md     | 2026-04-10 | 5       |
| patterns.md      | 2026-04-08 | -       |
| history.md       | 2026-04-11 | 12      |
| bugs.md          | 2026-04-09 | 3       |

Custom pages: api-versioning.md, deployment.md
```

---

## Command: update

Review what happened in the current session and update relevant `.brain/` pages.

Follow the update process defined in `.brain/SCHEMA.md` (section "Updating .brain/ — The Process"). The process covers:

1. Reading the actual diff (not just file names)
2. Filtering for significance (skip trivial changes)
3. Categorizing changes (feature, bug, decision, pattern, stack, architecture, refactor)
4. Extracting the WHY from conversation (matching the 5 event types)
5. Writing updates with proper format, dates, and `[[wikilinks]]`
6. Maintaining topic page Timelines (append wikilinks to matching `topics/*.md`; never create topics here)
7. Including brain updates in the same commit as the code

After completing the update, show what was changed:

```
Updated .brain/:
  - decisions.md: Added "Chose Google OAuth over Auth0"
    WHY captured: simpler integration for current scale, Auth0 pricing doesn't justify at <1k users
  - history.md: Added "Implemented OAuth2 flow"
  - architecture.md: Updated auth section with OAuth provider flow
  - features/auth.md: Added timeline entry, linked to [[decisions.md#chose-google-oauth]]
  - topics/auth.md: Appended Timeline entry linking to decisions.md#chose-google-oauth

Brain pages updated and ready to commit with your code changes.
```

---

## Command: decide

Shortcut to add a decision entry.

### Usage
```
/brain decide "Chose PostgreSQL over MongoDB because we need ACID transactions for payment processing"
```

### Steps

1. Read `.brain/decisions.md`.
2. Parse the user's text to extract: decision, context, alternatives if mentioned. Derive a proposed `## ` header (first clause, title-cased).
3. **Duplicate check.** Scan existing `## ` entries in the file. For each:
   - If an entry has `**Date:** <today>` AND its header + first body line share ≥80% token overlap with the new proposed entry → flag as a likely duplicate.
   - Show the user the existing entry and the proposed new one, then ask:
     ```
     Similar entry exists from today:

       ## <existing header>
       **Date:** <today>
       <first line of existing body>

     Proposed new entry:

       ## <new header>
       <proposed body>

     Add anyway? (y/N)
     ```
     Default is `N`. Only proceed if user confirms `y` / `yes`.
   - If no same-day near-duplicate is found, proceed silently.
4. Add new entry at the top with today's date.
5. Update `updated` date in frontmatter.
6. Write the file.
7. Confirm: `Added decision to .brain/decisions.md: "Chose PostgreSQL over MongoDB"`

---

## Command: bug

Shortcut to record a notable bug.

### Usage
```
/brain bug "Race condition in webhook delivery — shared slice without mutex, fixed with per-batch channel"
```

### Steps

1. Read `.brain/bugs.md`.
2. Parse the user's text to extract: symptom, root cause, fix. Derive a proposed `## ` header.
3. **Duplicate check.** Same rule as `/brain decide` step 3: if any existing entry has `**Date:** <today>` and ≥80% token overlap with the new proposed entry, prompt `Add anyway? (y/N)` (default N).
4. Add new entry at the top with today's date.
5. Update `updated` date in frontmatter.
6. Write the file.
7. Confirm: `Added bug to .brain/bugs.md: "Race condition in webhook delivery"`

---

## Command: history

Shortcut to add a history entry.

### Usage
```
/brain history "Migrated from REST to gRPC for internal service communication"
```

### Steps

1. Read `.brain/history.md`.
2. Derive a proposed `## ` header from the user's text.
3. **Duplicate check.** Same rule as `/brain decide` step 3: if any existing entry has `**Date:** <today>` and ≥80% token overlap with the new proposed entry, prompt `Add anyway? (y/N)` (default N).
4. Add new entry at the top with today's date.
5. Update `updated` date in frontmatter.
6. Write the file.
7. Confirm: `Added to .brain/history.md: "Migrated from REST to gRPC"`

---

### Duplicate-detection algorithm (shared by decide/bug/history)

```
Given proposed entry with header H_new and first body line B_new:
  For each existing entry E in the file with **Date:** == today:
    tokens_new    = lowercase words from (H_new + " " + B_new), split on whitespace + punctuation
    tokens_exist  = same from E
    overlap       = |tokens_new ∩ tokens_exist| / min(|tokens_new|, |tokens_exist|)
    if overlap >= 0.80:
      flag as near-duplicate, show both, prompt y/N
      stop at first match (don't flood user with every similar entry)
```

This is **warn-only, never hard-block** — the user always has the final say. It catches the common mistake of running the same `/brain decide` twice on the same day, without preventing legitimate same-day entries on related topics.

---

## Command: topic

Create or sync a topic page — a cross-cutting narrative synthesizing events from `decisions.md`, `bugs.md`, `history.md`, and `features/*.md` about a single domain (subsystem, concept, recurring concern).

Topic creation is **explicit, user-initiated only**. The LLM never auto-creates topic pages during `/brain update` or `/brain init` — this prevents weak, sticky topics. `/brain update` does maintain existing topics automatically.

### Usage
```
/brain topic <name>                      # Create topics/<slug>.md from template if missing
/brain topic <name> --sync               # Scan event pages for entries; LLM-guessed synonyms
/brain topic <name> --sync --keywords "a,b,c"   # Sync using EXPLICIT keyword list (no synonym guessing)
```

### Steps

1. **Validate the argument.**
   - If `<name>` is missing or empty: print usage (`/brain topic <name> [--sync [--keywords "a,b,c"]]`), do NOT create anything, stop.
   - Trim whitespace from `<name>`.
   - Reject if `<name>` contains any of: `/`, `\`, `..`, leading `.`, null bytes, control characters. Print:
     ```
     Topic name cannot contain path separators or leading dot.
     ```
     Stop. No file is created.

2. **Slugify the name** per SCHEMA.md § Anchor Slug Algorithm (lowercase, strip punctuation, whitespace→hyphens, collapse hyphens, trim). Call this `<slug>`. Empty slug after slugification (e.g., name was all punctuation) → print error and stop.

3. **Check existence.**
   ```bash
   test -f .brain/topics/<slug>.md && echo EXISTS || echo MISSING
   ```

4. **If MISSING and NOT --sync:**
   - Read the template at `~/.claude/skills/brain/templates/topic.md`. If the template is missing, tell the user the skill install is incomplete and suggest `~/.claude/skills/brain/install.sh` to restore it. Stop.
   - Substitute `{{TOPIC_NAME}}` with the user's original casing of `<name>` (e.g. "Redis Caching", not "redis-caching").
   - Substitute `{{DATE}}` with today's date in `YYYY-MM-DD`.
   - Create the `.brain/topics/` directory if it doesn't exist (`mkdir -p`).
   - Write `.brain/topics/<slug>.md`.
   - Tell the user:
     ```
     Created .brain/topics/<slug>.md. Fill in the Overview and Current Status
     sections with your understanding of this topic. Run
     `/brain topic <slug> --sync` to backfill the Timeline from existing
     decisions/bugs/history/features entries.
     ```
   - Stop. Do NOT proceed to sync unless `--sync` was on the original command.

5. **If EXISTS and NOT --sync (collision):**
   - Print:
     ```
     topics/<slug>.md already exists. Options:
       • Edit the file directly if you want to update its Overview or Current Status
       • Run /brain topic <name> --sync to pull in any new event entries
       • If you meant a different topic, pick a distinct name
     ```
   - Stop. Do NOT overwrite or regenerate.

6. **If --sync is passed** (works whether the file was just created or already existed):
   - **Determine the keyword set:**
     - If `--keywords "a,b,c"` was provided: use EXACTLY that comma-separated list (after trimming whitespace around each term). No LLM synonym expansion.
     - Otherwise: start from `<name>` + `<slug>`; infer obvious synonyms (e.g., "redis" → "cache", "caching", "session store"). If the inference is uncertain, ask the user.
   - **Search event pages:**
     ```bash
     grep -niE '(<keyword1>|<keyword2>|...)' .brain/decisions.md .brain/bugs.md .brain/history.md .brain/features/*.md 2>/dev/null
     ```
   - For each match, identify the enclosing `## ` header (the entry) and its `**Date:**` line. Compute the anchor slug using SCHEMA.md § Anchor Slug Algorithm.
   - **Dedupe against existing Timeline** — before adding a proposed bullet, grep the topic's current Timeline for the specific `[[page.md#anchor]]`. If already present, silently skip that candidate (this prevents `--sync` from producing duplicates when re-run).
   - Propose the REMAINING bullets to the user in the format:
     ```
     - **YYYY-MM-DD** — <short caption from the entry's header or first line> [[<page>.md#<anchor>]]
     ```
     Show the user the full list and ask for confirmation:
     ```
     Found N entries matching keywords (M already in Timeline, skipped). Propose adding to topics/<slug>.md:

       - **2026-04-10** — Chose Redis over Memcached [[decisions.md#chose-redis-over-memcached]]
       - **2026-03-22** — Fixed connection pool exhaustion [[bugs.md#redis-connection-pool-exhaustion]]
       ...

     Add all? (y / select / skip)
     ```
     If N is 0 (all matches already in Timeline), print "All matches already in Timeline — nothing to sync." and stop.
   - On confirmation, read `.brain/topics/<slug>.md`, locate the `## Timeline` section, append the proposed bullets, then sort all Timeline bullets by `**Date:** YYYY-MM-DD` descending (newest first).
   - Update the topic's `updated:` frontmatter to today's date.
   - Write the file.
   - Confirm to user: `Synced N entries into topics/<slug>.md Timeline.`

7. **Never auto-create topic pages from any other command.** If `/brain update` detects a recurring theme that might deserve a topic, it SUGGESTS the user run `/brain topic <domain>` — it does not create the file itself.

---

## Command: query

Search across all `.brain/` pages, follow `[[wikilinks]]`, and synthesize an answer.

### Usage
```
/brain query "why is auth custom?"
/brain query "what happened with webhook delivery?"
/brain query "what decisions did we make about caching?"
```

### Steps

1. **Check existence.** If no `.brain/`, tell user to run `/brain init`.

2. **Search all pages.** Grep all `.brain/**/*.md` files for keywords extracted from the question. Search for:
   - Exact phrases from the question
   - Key nouns and technical terms
   - Related terms (e.g., "auth" also search "authentication", "JWT", "login")

```bash
grep -ril "<keyword>" .brain/
```

3. **Rank results.** Prioritize:
   - `topics/*.md` AND `features/*.md` pages (highest — topics are cross-cutting narrative hubs, features are lifecycle hubs; both answer "what's the story of X?" more completely than event-type pages alone)
   - Direct keyword matches in headers (`## ` lines)
   - Pages with more matches
   - Archive pages (`archive/*.md`) matter when the question is about past history; include them in the ranked list rather than excluding

4. **Read matched pages.** Read the top 3-5 most relevant pages fully. If a topic page is in the matched set, read its full Timeline and follow its wikilinks — topic pages are the intended entry point for cross-year narratives.

5. **Follow wikilinks.** For every `[[page.md#anchor]]` found in the matched pages:
   - Read the linked page/section
   - Collect the connected context
   - Follow one level deep only (don't recurse infinitely)
   - If a wikilink points at a compacted entry (target not in active page), check the corresponding `archive/*.md` for the same anchor slug

6. **Synthesize.** Combine all gathered context into a clear, chronological answer:
   - Start with what it is (from topic page, feature page, or index)
   - Walk through the timeline (from topic Timeline, feature timeline, or history entries)
   - Include decisions and their reasoning (from decisions.md or archive)
   - Include bugs and fixes if relevant (from bugs.md or archive)
   - Cite sources: "According to `.brain/topics/redis.md` and `.brain/decisions.md`..."

7. **Output format:**

```
## Query: "what happened with webhook delivery?"

Webhook delivery is an async event delivery system using a Redis queue
(chose Redis over RabbitMQ for operational simplicity — decisions.md).

### Timeline
- 2026-01-15: Initial implementation (features/webhook-delivery.md)
- 2026-03-08: Added retry with exponential backoff
- 2026-05-18: Fixed race condition — shared slice replaced with
  per-batch channel (bugs.md)

### Current State
Working. Handles ~2k deliveries/min with dead letter queue for failures.

Sources: features/webhook-delivery.md, decisions.md, bugs.md
```

---

## Command: dashboard

Generate an interactive HTML dashboard showing all `.brain/` entries organized by category, sorted chronologically. Standalone HTML file — no server needed.

### Usage
```
/brain dashboard
```

### Steps

1. **Check existence.** If no `.brain/`, tell user to run `/brain init`.

2. **Read all .brain/ pages.** Read every `.brain/**/*.md` file.

3. **Build the data object.** Parse each page and construct a JSON object:

   ```json
   {
     "index": {
       "updated": "2026-04-11",
       "description": "What the project does...",
       "techStack": "Python 3.12 · React 19 · PostgreSQL 16...",
       "team": "3 engineers, 1 frontend",
       "directories": "src/api/ · src/services/ · web/..."
     },
     "history": [
       {"title": "Entry title", "date": "2026-04-11", "content": "What happened..."}
     ],
     "decisions": [
       {"title": "Decision title", "date": "2026-03-15", "content": "What was decided...", "context": "Why...", "status": "Active"}
     ],
     "features": [
       {"title": "Feature name", "date": "2026-01-15", "content": "Overview...", "links": ["decisions.md#anchor"]}
     ],
     "bugs": [
       {"title": "Bug title", "date": "2026-05-18", "content": "Description...", "symptom": "What happened...", "rootCause": "Why...", "fix": "How fixed...", "lesson": "Takeaway..."}
     ],
     "topics": [
       {"slug": "redis", "title": "Redis", "updated": "2026-04-16", "overview": "First paragraph of Overview...", "timelineCount": 7, "relatedCount": 3}
     ],
     "customs": [
       {"slug": "onboarding", "title": "Onboarding", "updated": "2026-04-16", "overview": "First paragraph of the custom page..."}
     ],
     "patterns": [
       {"title": "Pattern name", "content": "How it works..."}
     ],
     "architecture": {
       "overview": "System description...",
       "components": [{"title": "Component", "content": "Details..."}],
       "infrastructure": "Infra details..."
     }
   }
   ```

   **Parsing rules for entries (history, decisions, bugs):**
   - Split page by `## ` headers
   - Title = the header text
   - Date = extract from `**Date:** YYYY-MM-DD` line (MUST be present)
   - Content = first paragraph after Date line
   - For decisions: also extract `**Context:**`, `**Status:**`
   - For bugs: also extract `**Symptom:**`, `**Root cause:**`, `**Fix:**`, `**Lesson:**`
   - For features: extract `## Timeline` entries and `## Key Files`
   - Sort all entries by date, newest first

   **Parsing rules for topics (`topics/*.md`):**
   - `slug` = filename without `.md` (e.g., `redis` from `topics/redis.md`)
   - `title` = the `# ` heading text
   - `updated` = frontmatter `updated:` value
   - `overview` = first paragraph under `## Overview`
   - `timelineCount` = count of bullets under `## Timeline`
   - `relatedCount` = count of wikilinks under `## Related` (features + topics combined)
   - Topics are rendered **one card per page** (not flattened into per-Timeline-entry cards). Each card is a link to the full topic page on disk.

   **Parsing rules for customs (`custom/*.md`):**
   - `slug` = filename without `.md` (e.g., `onboarding` from `custom/onboarding.md`)
   - `title` = the `# ` heading text
   - `updated` = frontmatter `updated:` value
   - `overview` = first paragraph under the `# ` heading (custom pages don't have a fixed `## Overview` — take the first prose paragraph)
   - Customs are rendered **one card per page**, like topics. Each card links to the custom page on disk.

   **Parsing rules for index.md:**
   - Description = first paragraph after `# Title`
   - Tech Stack = content under `## Tech Stack` (join bullet points)
   - Team = content under `## Team`
   - Directories = content under `## Key Directories` (join bullet points)

   **Parsing rules for patterns.md:**
   - Each `## ` section = one pattern card
   - Title = header, Content = section body

   **Parsing rules for architecture.md:**
   - Overview = content under `## Overview`
   - Components = each `### ` subsection under `## Components`
   - Infrastructure = content under `## Infrastructure`

4. **Read the dashboard template.** Read `~/.claude/skills/brain/templates/dashboard.html`. If the file is not found, stop and tell the user:
   ```
   ERROR: Dashboard template missing at ~/.claude/skills/brain/templates/dashboard.html
   Reinstall brain: curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh | bash
   ```
   Do NOT generate HTML from scratch — the template is required.

5. **Replace placeholders:**
   - `{{PROJECT_NAME}}` → project name from `.brain/index.md` title
   - `{{BRAIN_JSON}}` → the JSON data object (including `topics` if any exist)
   - `{{TOTAL_ENTRIES}}` → count of history + decisions + features + bugs + topics entries
   - `{{LAST_UPDATED}}` → most recent `updated` date from any page frontmatter

6. **Write to `.brain/dashboard.html`.**

7. **Open in browser:**
   ```bash
   open .brain/dashboard.html      # macOS
   xdg-open .brain/dashboard.html  # Linux
   ```

8. **Add to .gitignore** if not already there:
   ```bash
   grep -q "dashboard.html" .brain/.gitignore 2>/dev/null || echo "dashboard.html" >> .brain/.gitignore
   ```

9. **Confirm:**
   ```
   Generated .brain/dashboard.html
     History: 4 entries
     Decisions: 5 entries
     Features: 0 entries
     Topics: 3 pages
     Bugs: 0 entries
     Patterns: 7
     Architecture: 4 components

   Opened in browser.
   ```

---

## Command: doctor

Diagnose `.brain/` and, with explicit user consent, apply a tightly-whitelisted
set of mechanical fixes. Everything else is reported for the user to resolve.

Doctor is a reasoning task, not a script. It reads two knowledge documents at
runtime and decides what to check and what to suggest:

1. **`.brain/SCHEMA.md`** — the authoritative format rules for this repo.
   What pages must exist, frontmatter fields, date format, wikilink syntax,
   page types, compaction, merge guidance. If it's not in SCHEMA, it's not
   a rule doctor can enforce.
2. **`~/.claude/skills/brain/DIAGNOSTICS.md`** — the playbook. Phase 0
   environment probe, the invariants to check (citing SCHEMA sections), the
   failure-mode → recovery table, and the auto-fix whitelist. Loaded only
   when doctor runs, so session-start token budget is unaffected.

If `DIAGNOSTICS.md` is missing from the skill install, tell the user the skill
is incomplete and suggest `~/.claude/skills/brain/install.sh` to restore it.
Do NOT attempt to diagnose without it — guessing rules is worse than reporting
the gap.

### Usage
```
/brain doctor             # Diagnose, then prompt before applying auto-fixes
/brain doctor --dry-run   # Diagnose only — never prompt, never apply fixes
```

### How to run it

1. **Read `.brain/SCHEMA.md`.** This is what "correct" means for this repo.
2. **Read `~/.claude/skills/brain/DIAGNOSTICS.md`.** This tells you what to
   check and how to reason about failures.
3. **Probe the environment** using DIAGNOSTICS § Phase 0. Store each signal
   on a `ctx` object — every recovery recommendation below consults `ctx`
   because the same symptom needs different commands depending on whether
   the tree is dirty, HEAD is broken, `.brain/` is gitignored, etc.
4. **Walk the invariants** listed in DIAGNOSTICS (structural, content, git,
   installation). Read each `.brain/*.md` and `.brain/features/*.md` **once**
   and extract everything needed (frontmatter, headers, dates, wikilinks,
   conflict markers, body length) in a single pass.
5. **Build findings.** For each violation:
   `{section, file, location, schema_ref, message, recovery, auto_fix_eligible}`.
   Every finding cites the SCHEMA section it violates — this grounds the fix
   and teaches the user.
6. **Render the report** grouped by section (CONTEXT, SYSTEM, FORMAT & CONTENT,
   SYNC, GAPS, SUMMARY). Empty sections stay silent.
7. **Offer auto-fixes** — only the items DIAGNOSTICS lists in its auto-fix
   whitelist. One top-level `[y/n]` prompt covers all of them; no per-item
   ceremony. Skip the prompt entirely if `--dry-run` or if nothing is
   whitelist-eligible.
8. **Verify each applied fix** by re-running its specific invariant (the
   `Verify` command DIAGNOSTICS specifies for that fix). If verify fails,
   print a diagnosis block (command, exit code, stderr, what verify expected
   vs found) and defer. **Do not loop, do not retry, do not fall back.**

### Non-negotiable principles

1. **Detection is side-effect-free.** Steps 1–6 never mutate anything.
2. **Auto-fixes are exactly what DIAGNOSTICS whitelists** — no more.
   As of DIAGNOSTICS v1.0: restore missing `.brain/SCHEMA.md` from the local
   skill, and re-register hooks via `install.sh --hooks-only`. Nothing else.
3. **Never auto-edit brain content.** Dates, wikilinks, prose, frontmatter
   values the user wrote — these are the project's record of meaning and
   stay in the user's hands.
4. **Never auto-run `git checkout`**, even narrow ones. Print the command;
   let the user run it. A dirty file checkout destroys uncommitted work.
5. **Never run broad `git checkout HEAD -- .brain/`.** Always per-file.
6. **Never run stash/pop sequences automatically.** Print them; the user runs them.
7. **Never touch files with conflict markers during a merge.** Let git's
   normal flow (`--ours` / `--theirs` / manual) handle it.
8. **Bias toward detection + explanation over execution.** Doctor's value
   is knowing what's wrong, not doing everything for the user.

---

## Command: uninstall

Remove all brain components from the local machine. Does NOT touch `.brain/` directories inside repos — those stay in git.

### Usage
```
/brain uninstall
```

### Step 1 — Confirm with the user

```
This will remove brain from your machine:
  - Skill files (~/.claude/skills/brain/)
  - Hook scripts (~/.claude/hooks/*-brain.sh)
  - Hook config from ~/.claude/settings.json
  - Brain section from ~/.claude/CLAUDE.md

This will NOT remove .brain/ from any repo — your project memory stays in git.

Proceed? (y/n)
```

Wait for confirmation. If no, stop.

### Step 2 — Remove hook scripts

```bash
rm -f ~/.claude/hooks/post-commit-brain.sh
rm -f ~/.claude/hooks/session-start-brain.sh
```

### Step 3 — Remove brain hooks from settings.json

Remove only brain-related hook entries, keep everything else:

```bash
if [ -f ~/.claude/settings.json ]; then
  jq '
    # Remove brain entries from PostToolUse
    if .hooks.PostToolUse then
      .hooks.PostToolUse = [.hooks.PostToolUse[] | select(.hooks[0].command | test("brain") | not)]
    else . end |
    # Remove empty PostToolUse array
    if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
    # Remove brain entries from SessionStart
    if .hooks.SessionStart then
      .hooks.SessionStart = [.hooks.SessionStart[] | select(.hooks[0].command | test("brain") | not)]
    else . end |
    # Remove empty SessionStart array
    if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
    # Remove empty hooks object
    if .hooks == {} then del(.hooks) else . end
  ' ~/.claude/settings.json > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
fi
```

### Step 4 — Remove brain section from CLAUDE.md

Remove only the brain block, keep everything else:

```bash
if [ -f ~/.claude/CLAUDE.md ]; then
  # Remove the block from "# brain" to the next "# " heading or end of file
  awk '
    /^# brain$/ { skip=1; next }
    /^# / && skip { skip=0 }
    !skip { print }
  ' ~/.claude/CLAUDE.md > ~/.claude/CLAUDE.md.tmp && mv ~/.claude/CLAUDE.md.tmp ~/.claude/CLAUDE.md
fi
```

Verify CLAUDE.md is not empty after removal. If it only had the brain block:
```bash
if [ ! -s ~/.claude/CLAUDE.md ]; then
  rm ~/.claude/CLAUDE.md
fi
```

### Step 5 — Remove skill directory

```bash
rm -rf ~/.claude/skills/brain/
```

### Step 6 — Confirm

```
brain uninstalled.

Removed:
  ✓ Skill files (~/.claude/skills/brain/)
  ✓ Hook scripts
  ✓ Hook config from settings.json
  ✓ Brain section from CLAUDE.md

Not touched:
  - .brain/ directories in your repos (still in git)
  - Other skills, hooks, and settings

Restart your Claude Code session to complete removal.
```
