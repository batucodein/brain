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
/brain graph              # Generate interactive D3 graph visualization of .brain/
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

**If HAS_HISTORY:** Gather context from the repo. Run these in parallel:

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
cat README.md 2>/dev/null | head -100
cat CONTRIBUTING.md 2>/dev/null | head -50
cat CHANGELOG.md 2>/dev/null | head -50
ls docs/ 2>/dev/null | head -20
ls doc/ 2>/dev/null | head -20
```

**2d. Git history:**
```bash
git log --oneline -50
git log --format="%an" | sort -u
git tag -l --sort=-version:refname | head -10
git log --diff-filter=A --summary --format="" -- "*.go" "*.py" "*.ts" "*.js" "*.java" "*.rs" | head -30
```

**2e. Key entry points (read first 30 lines of likely entry files):**
Read files matching: `main.go`, `cmd/*/main.go`, `src/main.*`, `app.py`, `index.ts`, `index.js`, `src/index.*`, `src/app.*`, `Main.java`, `Program.cs`, `lib.rs`.

**2f. Database/infrastructure signals:**
```bash
ls migrations/ 2>/dev/null | head -10
ls internal/repo/ 2>/dev/null || ls src/repository/ 2>/dev/null || ls models/ 2>/dev/null
cat docker-compose.yml 2>/dev/null | head -40
```

### Step 3 — Generate .brain/ pages

Create the `.brain/` directory and all core pages.

```bash
mkdir -p .brain/custom .brain/features .brain/archive
```

For each page, use the analysis from Step 2 to generate content. Follow the format defined in `SCHEMA.md` (read it from `~/.claude/skills/brain/SCHEMA.md`).

**Generation rules:**

- **index.md**: Synthesize from README + repo structure + config files. Include: what the project does, tech stack, key directories, team (from git authors).
- **architecture.md**: Infer from directory structure, entry points, config files. Describe components, layers, data flow, infrastructure.
- **decisions.md**: Extract from README mentions of "chose", "decided", "why", "instead of". Check for ADR directories (`docs/adr/`, `doc/decisions/`). If no explicit decisions found, start with one entry: "Initial architecture" describing the stack choices.
- **patterns.md**: Infer from code style: error handling patterns, naming conventions, test structure. Scan 3-5 representative source files.
- **history.md**: Build from git tags and significant commits. Group by month or milestone.
- **bugs.md**: Start mostly empty. Check git log for messages containing "fix", "bug", "hotfix" — summarize the 3-5 most significant ones if found.
- **features/*.md**: Identify 3-5 major features from the codebase (key directories, significant commit clusters, README feature descriptions). Create one page per feature with overview, timeline from git history, current state, and key files. Add `[[wikilinks]]` between feature pages and any related entries in decisions.md, bugs.md, history.md.

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

Review what happened in the current session and update relevant `.brain/` pages.

### Step 1 — Detect what changed

```bash
git diff --stat HEAD 2>/dev/null
git diff --cached --stat 2>/dev/null
```

Also review the conversation context: what did the user and LLM work on in this session?

### Step 2 — Determine which pages need updates

Apply the update rules from SCHEMA.md:

- New significant feature added → `history.md`, `architecture.md`, create `features/X.md`
- Architectural decision made during session → `decisions.md`, link from `features/X.md` if related
- Bug fixed → `bugs.md`, `history.md`, update `features/X.md` if the bug relates to a tracked feature
- New pattern established → `patterns.md`
- Stack/dependency changed → `index.md`
- Infrastructure changed → `architecture.md`

### Step 3 — Read each relevant page, update it

For each page that needs updating:
1. Read the current content.
2. Add/modify the relevant section following SCHEMA.md format rules.
3. Update the `updated` date in frontmatter.
4. Add `[[wikilinks]]` to connect related entries across pages. Every bug, decision, or history entry that relates to a feature must link to its feature page, and vice versa.
5. Write the updated file.

### Step 4 — Commit brain changes separately

Brain updates get their own commit, separate from code changes. This keeps PR diffs clean.

```bash
git add .brain/
git commit -m "brain: <short summary of what changed>"
```

Examples:
- `brain: record Redis caching decision`
- `brain: update architecture with OAuth flow`
- `brain: add webhook race condition to bugs`

If there are also unstaged code changes, commit brain first, then the code. Never mix brain updates with code changes in the same commit.

### Step 5 — Show what was updated

```
Updated .brain/:
  - history.md: Added "Implemented OAuth2 flow with Google provider"
  - decisions.md: Added "Chose Google OAuth over Auth0 — simpler for our scale"
  - architecture.md: Updated auth section with OAuth flow

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
.brain/ health check for: MarketIntel

Score: 7/10

Issues found:
  [STALE] patterns.md — last updated 45 days ago
  [BROKEN LINK] features/webhook.md references [[decisions.md#redis-queue]]
      but no section "redis-queue" found in decisions.md
  [MISSING FEATURE] internal/scoring/ has 8 files but no features/scoring.md
  [COMPACTION] history.md has 35 entries (threshold: 30) — consider archiving
  [ORPHAN] decisions.md "Chose Redis for caching" has no [[wikilink]] to a feature page

Suggestions:
  - Run /brain update to refresh stale pages
  - Create features/scoring.md for the scoring pipeline
  - Add [[wikilinks]] to connect orphan entries
  - Run compaction on history.md (move pre-2026 entries to archive/)
```

---

## Command: graph

Generate an interactive D3.js force-directed graph showing all brain entries and their `[[wikilink]]` connections. Outputs a standalone HTML file — no server needed, just open in a browser.

### Usage
```
/brain graph
```

### Steps

1. **Check existence.** If no `.brain/`, tell user to run `/brain init`.

2. **Read all .brain/ pages.** Read every `.brain/**/*.md` file including `features/`, `custom/`, and `archive/`.

3. **Extract nodes.** For each page, create nodes from:

   **Page-level nodes** (one per file):
   - `index.md` → node with type `index`
   - `architecture.md` → node with type `architecture`
   - `patterns.md` → node with type `pattern`
   - `features/*.md` → node with type `feature`

   **Entry-level nodes** (one per `## ` section within a page):
   - Each `## ` section in `decisions.md` → node with type `decision`
   - Each `## ` section in `bugs.md` → node with type `bug`
   - Each `## ` section in `history.md` → node with type `history`

   **Node format:**
   ```json
   {
     "id": "decisions.md#chose-redis-queue",
     "label": "Chose Redis queue for webhooks",
     "type": "decision",
     "content": "First 120 chars of the section content...",
     "date": "2026-01-15",
     "file": "decisions.md"
   }
   ```

   **ID convention:** `filename.md` for page-level nodes, `filename.md#anchor` for entry-level nodes. Anchors are the section header lowercased and hyphenated.

4. **Extract edges.** For each `[[wikilink]]` found in any page:
   - `[[page.md]]` → edge from current node to the page-level node
   - `[[page.md#anchor]]` → edge from current node to the specific entry node
   - If a `## ` section mentions a feature/component by name (even without a wikilink), create an implicit edge with a dashed style

   **Edge format:**
   ```json
   {
     "source": "features/webhook-delivery.md",
     "target": "decisions.md#chose-redis-queue"
   }
   ```

5. **Also extract implicit connections.** Scan entry content for references to other entries by keyword matching:
   - If a bug entry mentions "webhook" and there's a `features/webhook-delivery.md`, create an implicit edge
   - If a history entry mentions "Redis" and there's a decision about Redis, create an implicit edge
   - Only create implicit edges when confidence is high (exact feature name or unique technical term match)

6. **Read the graph template.** Read `~/.claude/skills/brain/templates/graph.html`.

7. **Replace placeholders.** In the template:
   - `{{PROJECT_NAME}}` → project name from `.brain/index.md` title
   - `{{GRAPH_JSON}}` → the JSON object with `nodes` and `edges` arrays
   - `{{NODE_COUNT}}` → total number of nodes
   - `{{EDGE_COUNT}}` → total number of edges

8. **Write output file.**
   ```bash
   # Write to .brain/graph.html
   ```
   Write the filled template to `.brain/graph.html`.

9. **Open in browser.**
   ```bash
   open .brain/graph.html      # macOS
   xdg-open .brain/graph.html  # Linux
   ```

10. **Add to .gitignore.** Add `graph.html` to `.brain/.gitignore` if not already there (the graph is generated, not source):
    ```bash
    echo "graph.html" >> .brain/.gitignore
    ```

11. **Confirm:**
    ```
    Generated .brain/graph.html with N nodes and M edges.
    Opened in browser.

    Node breakdown:
      Features: 5    Decisions: 8    Bugs: 3
      History: 12    Architecture: 1  Patterns: 1

    Tip: Use the filter buttons to focus on specific types.
         Hover over nodes to see connections.
         Search to find specific entries.
    ```

### Visual Design

The graph uses a dark theme (background #0A0E27) with color-coded nodes:

| Type | Color | Size | Description |
|------|-------|------|-------------|
| Feature | Blue `#3B82F6` | Large (14px) | Hub nodes — lifecycle pages |
| Decision | Green `#10B981` | Medium (10px) | Architectural choices |
| Bug | Red `#EF4444` | Medium (10px) | Bug fixes with root cause |
| History | Purple `#8B5CF6` | Small (8px) | Timeline milestones |
| Architecture | Amber `#F59E0B` | Large (12px) | System structure |
| Pattern | Pink `#EC4899` | Medium (9px) | Coding conventions |
| Index | Gray `#64748B` | Largest (16px) | Project overview hub |

**Interactions:**
- **Hover** a node → highlights connected nodes, dims others, shows tooltip with content preview
- **Click & drag** → reposition nodes
- **Search** → filters nodes by label/content, highlights matches and their neighbors
- **Filter buttons** → show only one type and its connections
- **Scroll** → zoom in/out
- **Pan** → click and drag on empty space

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

When `.brain/` exists in the current repo, the LLM should:

### At Session Start
1. Read `.brain/index.md` to understand the project.
2. Based on the user's first task, read relevant pages (e.g., `architecture.md` for refactoring, `bugs.md` for debugging).
3. If the task relates to a specific feature, check if `features/X.md` exists and read it for full context.

### During Session
1. When making architectural decisions, mention that you'll record it in `.brain/decisions.md`.
2. When fixing non-trivial bugs, note the root cause for `.brain/bugs.md` and update the relevant `features/X.md`.
3. When establishing new patterns, flag them for `.brain/patterns.md`.
4. When building a significant new feature, create `features/X.md` to track its lifecycle from day one.
5. Always add `[[wikilinks]]` when entries relate to each other across pages.

### Before Session End (if significant changes were made)
Suggest running `/brain update` to capture what happened.

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
