---
name: brain
description: Per-repo project memory that ships with git. Bootstrap, maintain, and query .brain/ for full project context.
trigger: /brain
---

# /brain

Per-repo project memory tracked in git. Every developer who clones the repo gets full project context. Every LLM tool reads `.brain/` at session start and updates it as the project evolves.

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
/brain health             # Check brain health: stale pages, broken links, gaps
/brain dashboard           # Generate interactive dashboard of all .brain/ entries
/brain hooks install      # Install git hooks for auto-update reminders (opt-in)
/brain hooks remove       # Remove brain git hooks
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

**Phase A — Surface scan (run in parallel):**

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
mkdir -p .brain/custom .brain/features .brain/archive
```

For each page, use the analysis from Step 2 to generate content. Follow the format defined in `SCHEMA.md` (read it from `~/.claude/skills/brain/SCHEMA.md`).

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

**After generating pages, tell the user what was created and offer to review each page.**

### Step 4 — Install platform integration

Detect which platform files exist and append brain instructions.

**CLAUDE.md:**
```bash
if [ -f CLAUDE.md ]; then
    echo "CLAUDE_MD_EXISTS"
else
    echo "NO_CLAUDE_MD"
fi
```

If exists: append the brain section (see Platform Integration in SCHEMA.md). If not: create it with the brain section.

**Cursor rules:**
```bash
mkdir -p .cursor
```
Create `.cursor/rules` if it doesn't exist, or append brain instructions.

**AGENTS.md:**
Create `AGENTS.md` if it doesn't exist, or append brain instructions.

**Always add to .gitignore if needed — nothing to ignore, .brain/ is tracked.**

### Step 5 — Summary

Print a summary:

```
.brain/ initialized with N pages:
  - index.md (project overview)
  - architecture.md (system structure)
  - decisions.md (N decisions extracted)
  - patterns.md (coding conventions)
  - history.md (N milestones)
  - bugs.md (N bugs documented)

Platform integration:
  - CLAUDE.md ✓
  - .cursor/rules ✓
  - AGENTS.md ✓

Next: Review the generated pages with `/brain status`, then commit .brain/ to git.
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

Review what happened in the current session and update relevant `.brain/` pages. The goal is to capture the WHY behind changes — the reasoning, trade-offs, and context that git diff cannot show.

### Step 1 — Get the WHAT (code changes)

Read the actual diff, not just file names:

```bash
git diff HEAD --stat 2>/dev/null
git diff --cached --stat 2>/dev/null
```

Then read the full diff content for changed files (excluding generated/lock files):

```bash
git diff HEAD -- ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)go.sum' 2>/dev/null | head -300
git diff --cached -- ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)go.sum' 2>/dev/null | head -300
```

Also check recent commits made during this session:

```bash
git log --since="2 hours ago" --oneline --stat 2>/dev/null
```

### Step 2 — Significance filter

Not every change is brain-worthy. Skip the update (tell the user "no significant changes to record") if ALL changes are:
- Formatting, linting, or whitespace only
- Dependency version bumps with no behavior change
- Renaming with no design reasoning
- Changes to fewer than 3 lines with no architectural impact

Continue only if at least one change involves:
- New feature or endpoint
- Bug fix with a root cause
- Architectural change (new dependency, new layer, new integration)
- A decision the user explicitly reasoned about
- A pattern the team established or changed
- Infrastructure or deployment change

### Step 3 — Categorize each significant change

For each significant change from the diff, assign a category:

| Category | Signals in diff | Brain page |
|----------|----------------|------------|
| **New feature** | New files in feature directories, new routes/endpoints, new service | `history.md`, `features/X.md`, maybe `architecture.md` |
| **Bug fix** | Changes in existing logic, fix in commit message, error handling added | `bugs.md`, `features/X.md` if related |
| **Decision** | New dependency in go.mod/package.json, switched library, new pattern introduced | `decisions.md`, `features/X.md` if related |
| **Pattern change** | New error handling approach, naming convention shift, new test pattern | `patterns.md` |
| **Stack change** | New entry in go.mod/package.json/requirements.txt, new Docker service | `index.md` |
| **Architecture change** | New directory structure, new middleware, new external integration | `architecture.md` |
| **Refactor** | Moved code between files, restructured layers, no behavior change | `history.md`, `architecture.md` if structure changed |

### Step 4 — Extract the WHY from conversation (CRITICAL)

This is what makes brain valuable. The diff tells you WHAT changed. The conversation tells you WHY. For each categorized change, look back through the conversation for these **event types**:

1. **A choice was made** — There were multiple possible approaches and one was picked. The reasoning may be explicit or implied. If the user picked from options you proposed, the rejected options are "alternatives considered."

2. **Something broke and was understood** — A problem was reported, investigation happened, a root cause was found. Capture the full arc: symptom → investigation → root cause → fix → lesson.

3. **Something was rejected** — The user said no to a suggestion, or an approach was tried and didn't work. The rejected path and the reason it was rejected are often more valuable than the chosen path.

4. **A constraint shaped the implementation** — Performance, cost, compatibility, timeline, team size, legal requirements — anything that made the solution different from the "obvious" approach.

5. **The system changed structurally** — New component, new integration, new layer, removed dependency. The reasoning for structural changes is the hardest to recover later.

**If no WHY exists in the conversation** for a change: Do NOT invent one. Either:
- Ask the user: "I see you added Redis caching — what drove that decision?"
- Or write the entry with just the WHAT and mark it: `**Context:** To be filled — reasoning not captured in session.`

### Step 5 — Read current brain pages and write updates

For each page that needs updating:
1. Read the current content.
2. Add new entries at the top (newest first) for `history.md`, `decisions.md`, `bugs.md`.
3. Replace in-place for `index.md`, `architecture.md`, `patterns.md`.
4. Follow SCHEMA.md format strictly. Every entry needs `**Date:** YYYY-MM-DD`.
5. Add `[[wikilinks]]` to connect related entries across pages. Every bug, decision, or history entry that relates to a tracked feature MUST link to `[[features/X.md]]`, and the feature page must link back.
6. If a significant new feature was built and no `features/X.md` exists, create one.
7. Write the updated files.

**Writing rules for entries:**
- Lead with the WHY, not the WHAT. Bad: "Added Redis caching." Good: "Added Redis caching to avoid redundant AI API calls — same product/market queries were hitting the API repeatedly, costing money and adding latency."
- Include alternatives considered when available: `**Alternatives considered:** Memcached (simpler but no pub/sub), database caching (too slow for our p95 target).`
- For bugs, always include the root cause and lesson: `**Lesson:** Never share mutable state between goroutines without synchronization.`
- Keep entries to 1-3 short paragraphs. Brain is context, not documentation.

### Step 6 — Commit brain changes separately

```bash
git add .brain/
git commit -m "brain: <short summary of what changed>"
```

Examples:
- `brain: record Redis caching decision and trade-offs`
- `brain: document OAuth bug root cause and fix`
- `brain: add payment feature page with initial timeline`

Never mix brain and code changes in the same commit.

### Step 7 — Show what was updated

```
Updated .brain/:
  - decisions.md: Added "Chose Google OAuth over Auth0"
    WHY captured: simpler integration for current scale, Auth0 pricing doesn't justify at <1k users
  - history.md: Added "Implemented OAuth2 flow"
  - architecture.md: Updated auth section with OAuth provider flow
  - features/auth.md: Added timeline entry, linked to [[decisions.md#chose-google-oauth]]

Committed: brain: record OAuth2 decision and update architecture
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
2. Add new entry at the top with today's date.
3. Parse the user's text to extract: decision, context, alternatives if mentioned.
4. Update `updated` date in frontmatter.
5. Write the file.
6. Confirm: `Added decision to .brain/decisions.md: "Chose PostgreSQL over MongoDB"`

---

## Command: bug

Shortcut to record a notable bug.

### Usage
```
/brain bug "Race condition in webhook delivery — shared slice without mutex, fixed with per-batch channel"
```

### Steps

1. Read `.brain/bugs.md`.
2. Add new entry at the top with today's date.
3. Parse the user's text to extract: symptom, root cause, fix.
4. Update `updated` date in frontmatter.
5. Write the file.
6. Confirm: `Added bug to .brain/bugs.md: "Race condition in webhook delivery"`

---

## Command: history

Shortcut to add a history entry.

### Usage
```
/brain history "Migrated from REST to gRPC for internal service communication"
```

### Steps

1. Read `.brain/history.md`.
2. Add new entry at the top with today's date.
3. Update `updated` date in frontmatter.
4. Write the file.
5. Confirm: `Added to .brain/history.md: "Migrated from REST to gRPC"`

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
   - `features/*.md` pages (highest — these are the lifecycle hubs)
   - Direct keyword matches in headers (`## ` lines)
   - Pages with more matches

4. **Read matched pages.** Read the top 3-5 most relevant pages fully.

5. **Follow wikilinks.** For every `[[page.md#anchor]]` found in the matched pages:
   - Read the linked page/section
   - Collect the connected context
   - Follow one level deep only (don't recurse infinitely)

6. **Synthesize.** Combine all gathered context into a clear, chronological answer:
   - Start with what it is (from feature page or index)
   - Walk through the timeline (from history entries and feature timeline)
   - Include decisions and their reasoning (from decisions.md)
   - Include bugs and fixes if relevant (from bugs.md)
   - Cite sources: "According to `.brain/decisions.md`..."

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

## Command: health

Audit `.brain/` for quality issues.

### Usage
```
/brain health
```

### Steps

1. **Check existence.** If no `.brain/`, tell user to run `/brain init`.

2. **Read all pages.** Read every `.brain/**/*.md` file. Parse frontmatter for `updated` dates.

3. **Run checks:**

**Staleness** — Flag pages not updated in 30+ days:
```
Check: (today's date) - (page updated date) > 30 days
```

**Broken wikilinks** — Find all `[[...]]` references and verify targets exist:
```bash
grep -roh '\[\[[^]]*\]\]' .brain/ | sort -u
```
For each link:
- `[[page.md]]` → check file exists
- `[[page.md#anchor]]` → check file exists AND section header exists

**Missing feature pages** — Scan major code directories. For each significant feature area (3+ files in a directory, or a directory name that suggests a feature), check if a corresponding `features/*.md` exists.

**Compaction needed** — Check if any page exceeds 30 entries or 150 lines:
```bash
wc -l .brain/*.md
grep -c "^## " .brain/history.md .brain/decisions.md .brain/bugs.md
```

**Orphan entries** — Find entries in history.md, decisions.md, or bugs.md that relate to a feature but don't have a `[[wikilink]]` to a feature page.

**Empty pages** — Flag pages that only have frontmatter and a header but no real content.

4. **Output format:**

```
.brain/ health check for: ProjectName

Score: 7/10

Issues found:
  [STALE] patterns.md — last updated 45 days ago
  [BROKEN LINK] features/webhook.md references [[decisions.md#redis-queue]]
      but no section "redis-queue" found in decisions.md
  [MISSING FEATURE] src/payments/ has 8 files but no features/payments.md
  [COMPACTION] history.md has 35 entries (threshold: 30) — consider archiving
  [ORPHAN] decisions.md "Chose Redis for caching" has no [[wikilink]] to a feature page

Suggestions:
  - Run /brain update to refresh stale pages
  - Create features/payments.md for the payments module
  - Add [[wikilinks]] to connect orphan entries
  - Run compaction on history.md (move pre-2026 entries to archive/)
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

4. **Read the dashboard template.** Read `~/.claude/skills/brain/templates/dashboard.html`.

5. **Replace placeholders:**
   - `{{PROJECT_NAME}}` → project name from `.brain/index.md` title
   - `{{BRAIN_JSON}}` → the JSON data object
   - `{{TOTAL_ENTRIES}}` → count of history + decisions + features + bugs entries
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
     Bugs: 0 entries
     Patterns: 7
     Architecture: 4 components

   Opened in browser.
   ```

---

## Command: hooks install

Install a git post-commit hook that reminds the LLM to check if brain pages need updating.

### Steps

1. Check if `.git/hooks/post-commit` exists. If it does, check if it already contains brain logic. If yes, skip.

2. Create or append to `.git/hooks/post-commit`:

```bash
#!/bin/bash
# brain: remind to update .brain/ after significant commits

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null)
BRAIN_FILES=$(echo "$CHANGED_FILES" | grep "^\.brain/" || true)
CODE_FILES=$(echo "$CHANGED_FILES" | grep -v "^\.brain/" || true)

# If code changed but brain didn't, print reminder
if [ -n "$CODE_FILES" ] && [ -z "$BRAIN_FILES" ]; then
    CODE_COUNT=$(echo "$CODE_FILES" | wc -l | tr -d ' ')
    if [ "$CODE_COUNT" -gt 3 ]; then
        echo ""
        echo "brain: $CODE_COUNT files changed without .brain/ update."
        echo "       Consider running /brain update in your next session."
    fi
fi
```

3. Make executable:
```bash
chmod +x .git/hooks/post-commit
```

4. Confirm: `Installed post-commit hook. You'll see reminders when significant code changes don't include brain updates.`

---

## Command: hooks remove

Remove brain's git hook.

### Steps

1. Read `.git/hooks/post-commit`.
2. Remove the brain section (between `# brain:` markers).
3. If the file is now empty (only had brain hook), delete it.
4. Confirm: `Removed brain post-commit hook.`

---

## Session Behavior (Automatic)

When `.brain/` exists in the current repo, the LLM should actively track reasoning throughout the session — not just at update time.

### At Session Start
1. Read `.brain/index.md` to understand the project.
2. Based on the user's first task, read relevant pages (e.g., `architecture.md` for refactoring, `bugs.md` for debugging).
3. If the task relates to a specific feature, check if `features/X.md` exists and read it for full context.

### During Session — Track Reasoning
The conversation is the only place where reasoning exists. Be aware of these moments as they happen:

1. **A choice was made** — Multiple approaches existed, one was picked. Note what was chosen and what wasn't.
2. **Something broke and was understood** — A bug was reported, investigated, and diagnosed. The full arc matters.
3. **Something was rejected** — An approach was proposed and turned down. Why it was rejected is high-value context.
4. **A constraint shaped the work** — Performance, cost, compatibility, time, team size — anything that steered the implementation away from the default approach.
5. **The system changed structurally** — New component, integration, or dependency. Structural reasoning is the hardest to recover later.

You don't need to write anything during the session — just recognize these moments so you can reference them at `/brain update` time.

### Before Session End (if significant changes were made)
Suggest running `/brain update` to capture what happened. Be specific about what you'd record: "I'd capture the Redis caching decision and the webhook bug root cause — want me to run `/brain update`?"

---

## Important Rules

1. **Never hallucinate content.** If you can't determine something from the repo, write "Unknown — to be filled by team" rather than guessing.
2. **Be concise.** Each entry should be one paragraph or a short list. `.brain/` is not documentation — it's context.
3. **Explain WHY, not WHAT.** The code shows what. Brain pages explain why.
4. **Use absolute dates.** Never "yesterday" or "last week". Always `2026-04-11`.
5. **Don't duplicate README.** Reference it: "See README.md for setup instructions."
6. **Respect existing content.** When updating, preserve what others wrote. Add, don't replace (unless correcting errors).
7. **Separate commits.** Always commit brain changes separately from code with prefix `brain:`. Never mix brain and code in the same commit. This keeps PR diffs clean and lets teams filter brain history with `git log --grep="^brain:"`.
8. **Compaction.** When any page exceeds 30 entries or 150 lines, compact it: move entries older than 3 months to `.brain/archive/<page>-<year>.md`, keep a one-line summary in the active page pointing to the archive. Active pages stay fast to read; full history is still in git.
