# brain — Diagnostics Playbook v1.0

> **Read `.brain/SCHEMA.md` first.** SCHEMA.md is the authoritative truth for
> page formats, frontmatter, date format, wikilinks, page types, compaction,
> and merge rules. This document operationalizes SCHEMA's rules as checks,
> adds git-context probing, and lists canonical recoveries for known failure
> modes. When SCHEMA evolves, these checks follow automatically because they
> cite SCHEMA sections rather than duplicating rules.

This playbook is loaded only when `/brain doctor` runs. Session-start reads
never touch this file — the session-start token budget is unaffected.

---

## How `/brain doctor` should reason

1. Read `.brain/SCHEMA.md` (ground truth for this repo's format).
2. Read this file (how to check against that truth; what to do when it's violated).
3. Probe the git environment (Phase 0 below). Store results as `ctx.*`. Every
   recovery recommendation must consult `ctx` — the *same symptom* can need
   *different commands* depending on whether the tree is dirty, HEAD is broken,
   `.brain/` is gitignored, etc.
4. Walk the invariants below. For each violation, build a finding:
   `{section, file, location, schema_ref, message, recovery, auto_fix_eligible}`.
5. Render the report grouped by section. Every finding cites its SCHEMA section.
6. Offer to run only whitelisted auto-fixes (below), with a single top-level
   user consent. Everything else is printed for the user to act on.
7. Re-verify each applied fix by re-checking its specific invariant. On failure,
   print a diagnosis block (command, exit code, stderr, what verify expected).
   Never loop.

Bias strongly toward **detection + explanation** over **execution**. Doctor's
value is knowing what's wrong, not doing everything for the user.

---

## Phase 0 — Environment probe (always run first)

Cheap git commands. Store each result on a `ctx` object. Later recovery
commands consult `ctx` to stay correct for the user's actual state.

```bash
ctx.is_git        : git rev-parse --git-dir >/dev/null 2>&1           ? yes : no
ctx.has_head      : git rev-parse HEAD >/dev/null 2>&1                ? yes : no
ctx.detached      : git symbolic-ref -q HEAD >/dev/null 2>&1          ? no  : yes
ctx.gitignored    : git check-ignore -q .brain/ 2>/dev/null           ? yes : no
ctx.brain_tracked : [ -n "$(git ls-files .brain/ 2>/dev/null | head -1)" ]  ? yes : no
ctx.shallow       : [ "$(git rev-parse --is-shallow-repository)" = "true" ] ? yes : no
ctx.dirty_files   : git status --porcelain .brain/ 2>/dev/null | awk '{print $2}'   # list
ctx.merging       : [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]    ? yes : no
ctx.behind_main   : git rev-list --count HEAD..origin/main 2>/dev/null \
                    || git rev-list --count HEAD..main 2>/dev/null || 0
```

Emit CONTEXT-section findings for anything that shapes recovery:

| Signal | Emit |
|---|---|
| `ctx.is_git=no` | CRITICAL — git-based recovery impossible; only `/brain init` can help |
| `ctx.gitignored=yes` | ERROR — `.brain/` recovery depends on git tracking; policy fix required |
| `ctx.has_head=no` | WARNING — no commits yet; git checkout cannot recover anything |
| `ctx.detached=yes` | WARNING — checkouts pull from detached sha, not branch tip |
| `ctx.shallow=yes` | WARNING — history-based recovery limited to HEAD only |
| `ctx.dirty_files` non-empty | WARNING — listed files have uncommitted edits; checkout would destroy them |
| `ctx.merging=yes` | WARNING — merge in progress; conflict markers are not corruption |
| `ctx.behind_main > 0` | WARNING — branch is behind main; restored state may be older than main |

---

## Invariants to verify

Each invariant cites the SCHEMA.md section it enforces. When SCHEMA changes,
update the rule there — checks here stay correct because they point at the rule,
not duplicate it.

### Structural invariants

- `.brain/SCHEMA.md` exists. *(SCHEMA.md § Directory Structure)*
- `.brain/index.md` exists with frontmatter and project content. *(SCHEMA.md § index.md)*
- Core pages exist: `architecture.md`, `decisions.md`, `patterns.md`, `history.md`, `bugs.md`.
  *(SCHEMA.md § Directory Structure)*
- Every `.brain/*.md`, `.brain/features/*.md`, `.brain/topics/*.md`,
  `.brain/custom/*.md`, and `.brain/archive/*.md` has frontmatter with `type:` and
  `updated:`. *(SCHEMA.md § Frontmatter Fields)*
- `type:` is one of the valid values: `index, architecture, decisions, patterns,
  history, bugs, feature, topic, custom, archive`. *(SCHEMA.md § Page Types)*
- **`type:` matches the file's expected location.** Each path maps to a canonical
  type: `decisions.md` → `decisions`, `bugs.md` → `bugs`, `history.md` → `history`,
  `index.md` → `index`, `architecture.md` → `architecture`, `patterns.md` → `patterns`,
  `features/*.md` → `feature`, `topics/*.md` → `topic`, `custom/*.md` → `custom`,
  `archive/*.md` → `archive`. Mismatch → ERROR.
  *(SCHEMA.md § Page Types)*

### Content invariants

- Every `**Date:** <v>` line matches `^\d{4}-\d{2}-\d{2}$`. *(SCHEMA.md § Date Format)*
- Every frontmatter `updated:` matches the same regex. *(SCHEMA.md § Date Format)*
- **`updated:` reflects latest content.** For event-type pages (`decisions.md`, `bugs.md`,
  `history.md`) and Timeline-bearing pages (`features/*.md`, `topics/*.md`), compute the
  max `**Date:**` across all entries/Timeline bullets. If the page's frontmatter `updated:`
  is OLDER than that max, flag as WARNING: "updated: X is older than latest entry date Y —
  the page was likely modified without bumping updated". Reason not ERROR: occasionally
  the user deliberately preserves an old `updated:` after a trivial fix.
  *(SCHEMA.md § Date Format + § Updating)*
- **Compaction threshold.** For `decisions.md`, `bugs.md`, `history.md`, and any
  `archive/<page>-<year>.md`: count `## ` top-level entries. If count ≥ 30 OR the file
  has ≥ 150 lines, flag as WARNING: "<page> is at compaction threshold (N entries, L lines)
  — consider compacting per SCHEMA.md § Compaction". Soft warning, not ERROR: compaction is
  user judgment. *(SCHEMA.md § Compaction)*
- Every `[[target]]` wikilink resolves — file exists, and for `[[page.md#anchor]]`, a
  `##`/`###` header in the target file produces the same slug when run through the
  algorithm at SCHEMA.md § Anchor Slug Algorithm (lowercase, preserve Unicode letters,
  delete punctuation, whitespace→single hyphen, collapse hyphens, trim).
  *(SCHEMA.md § Linking with wikilinks + § Anchor Slug Algorithm)*
  - **Before flagging a broken `[[page.md#anchor]]` as MANUAL**, search all `.brain/archive/*.md`
    files for a header whose slug matches `#anchor`. If found, the finding message becomes:
    *"Broken wikilink — slug matches header in `archive/<file>.md`. Content was likely compacted.
    Repoint the wikilink to the archive path, or restore from archive."* This is common in
    topic pages whose Timeline entries point at event pages that were later compacted.
- **Topic pages** (`.brain/topics/*.md`) should have a non-empty `## Timeline` section.
  Empty Timeline → WARNING: topic was created but never maintained.
  *(SCHEMA.md § topics/\*.md)*
- No conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) in any page, unless
  `ctx.merging=yes` (in which case they are expected, not corruption).
- Pages are not chronically empty (body <100 chars suggests an abandoned placeholder).

### Git invariants

- `.brain/` is NOT in `.gitignore`. *(SCHEMA.md § Updating / Commit brain updates)*
- At least one file in `.brain/` is tracked in git (otherwise brain has no backup).
- Brain commits pair with code commits (soft warning: if code has commits newer
  than latest `.brain/` commit, suggest `/brain update`).
  *(SCHEMA.md § Updating / Commit brain updates)*

### Installation invariants (only if the user has the skill installed)

- If `~/.claude/hooks/post-commit-brain.sh` or `session-start-brain.sh` exists,
  it must be registered in `~/.claude/settings.json` under the matching hook
  event. An unregistered hook file is silently dead.
- `.brain/SCHEMA.md` first line (version header) matches
  `~/.claude/skills/brain/SCHEMA.md` first line. Mismatch suggests the repo is
  pinned to an older schema and may need migration review.
- **`jq` is available on PATH** — `command -v jq` must succeed. `jq` is used by
  `install.sh` (to register hooks in settings.json) and by both hooks at
  runtime (to emit JSON to Claude Code). If missing, the hooks fall back to a
  static WARNING message and full functionality is degraded.

---

## Known failure modes → canonical recoveries

Pick the row whose `ctx` column matches the user's state. The `Action` column
is the recovery doctor prints (and, where marked `AUTO`, may execute with
consent).

| Symptom | ctx conditions | Action |
|---|---|---|
| File missing from disk | `brain_tracked=yes`, file not in `dirty_files`, HEAD version parses cleanly | `git checkout HEAD -- .brain/<file>` |
| File missing from disk | `brain_tracked=yes`, HEAD version ALSO broken | Walk `git log --format=%H -- .brain/<file>`; for each sha, test if `git show <sha>:.brain/<file>` has valid frontmatter and date; checkout the first good one: `git checkout <sha> -- .brain/<file>` |
| File missing from disk | file IS in `dirty_files` | WARN: uncommitted edits would be lost. Print BOTH the narrow checkout and the stash-first sequence. Do NOT auto-run. |
| File missing from disk | `brain_tracked=no` (untracked or never committed) | Recreate from template at `~/.claude/skills/brain/templates/<name>.md`, or run `/brain init` |
| File missing from disk | `gitignored=yes` | REVIEW: remove `.brain/` from `.gitignore` first (repo policy), then `git add .brain/` and commit |
| File missing from disk | `has_head=no` | Run `/brain init`; no git history to recover from |
| Corrupt frontmatter | HEAD version is good | `git checkout HEAD -- .brain/<file>` |
| Corrupt frontmatter | HEAD also broken, walkback finds good sha | `git checkout <sha> -- .brain/<file>` |
| Corrupt frontmatter | no good sha in history | MANUAL: rewrite frontmatter manually; preserve body |
| Invalid date `**Date:** <v>` | — | MANUAL: edit the file; use `YYYY-MM-DD` with zero-padding |
| Broken wikilink | target file exists, anchor doesn't match any header | MANUAL: repoint to an existing header (doctor may list available headers in target) OR add the missing section |
| Broken wikilink | target file doesn't exist | MANUAL: fix path, create target, or remove link |
| Broken wikilink | anchor slug matches a header in any `archive/*.md` file | MANUAL: content was likely compacted. Repoint the wikilink to the archive path (e.g., `[[decisions.md#x]]` → `[[archive/decisions-2025.md#x]]`), or restore the entry from archive |
| Broken wikilink | points at `topics/<x>.md`, target missing | MANUAL: user creates the topic via `/brain topic <x>` or removes the link |
| Topic page exists but `## Timeline` is empty | — | MANUAL: run `/brain topic <name> --sync` to backfill from event pages, or let `/brain update` populate it over time |
| Conflict markers in file | `merging=yes` | Do not touch. User resolves via normal git flow: `git checkout --ours <file>`, `--theirs`, or manual edit |
| Conflict markers in file | `merging=no` | MANUAL: stale markers from a past botched resolution; edit file |
| `.brain/SCHEMA.md` missing | skill installed at `~/.claude/skills/brain/` | **AUTO**: `cp ~/.claude/skills/brain/SCHEMA.md .brain/SCHEMA.md` |
| `.brain/SCHEMA.md` missing | skill not installed | Reinstall skill: `curl -fsSL https://raw.githubusercontent.com/batucodein/brain/main/install.sh \| bash` |
| Hook file missing from `~/.claude/hooks/` | skill installed | **AUTO**: `~/.claude/skills/brain/install.sh --hooks-only` |
| Hook file present but not registered in settings.json | skill installed | **AUTO**: `~/.claude/skills/brain/install.sh --hooks-only` |
| `jq` not on PATH (`command -v jq` fails) | — | MANUAL: install jq. `brew install jq` (macOS) / `sudo apt install jq` (Debian) / `sudo dnf install jq` (Fedora) / `sudo pacman -S jq` (Arch). Not auto-fixable — package install is too platform-specific for the whitelist. |
| SCHEMA version mismatch (repo vs local) | — | REVIEW: diff the two files; decide whether to update `.brain/SCHEMA.md` and verify your existing pages still conform |
| `.brain/` in `.gitignore` | — | REVIEW: repo policy — remove entry from `.gitignore`, then `git add .brain/` |
| Brain older than code (sync) | — | MANUAL: run `/brain update` in a session that has the relevant code context |
| Compaction threshold reached (>30 entries or >150 lines) | — | MANUAL: follow SCHEMA.md § Compaction; move oldest entries to `archive/<page>-<year>.md` |
| Missing feature page (source dir suggests a feature) | — | MANUAL: create `features/<name>.md` per SCHEMA.md § features/*.md |
| Empty page (<100 chars body) | — | MANUAL: fill with real content or delete the page |

---

## Auto-fix whitelist

Doctor may execute ONLY these commands, and only when the user has answered
`y` to the single top-level prompt. Every other recovery is prose.

### 1. Restore missing `.brain/SCHEMA.md` from local skill

- **Condition**: `.brain/SCHEMA.md` missing AND `~/.claude/skills/brain/SCHEMA.md` exists.
- **Guardrail**: `.brain/SCHEMA.md` not in `ctx.dirty_files` (trivially true if missing).
- **Command**: `cp ~/.claude/skills/brain/SCHEMA.md .brain/SCHEMA.md`
- **Verify**: `test -f .brain/SCHEMA.md && head -1 .brain/SCHEMA.md | grep -q '^# \.brain/ Schema'`

### 2. Reinstall / re-register hooks

- **Condition**: hook script missing from `~/.claude/hooks/` OR hook script present
  but not registered in `~/.claude/settings.json`.
- **Guardrail**: `~/.claude/skills/brain/install.sh` exists and is executable.
- **Command**: `~/.claude/skills/brain/install.sh --hooks-only`
- **Verify**: re-run the Installation invariant checks — hook files exist AND a
  `jq` probe confirms they're registered under `hooks.PostToolUse` /
  `hooks.SessionStart`.

Nothing outside this whitelist is ever auto-executed. Not git checkouts (even
safe ones), not content edits, not `.gitignore` changes, not `git add`, not
stash, not reinstalls.

---

## Reasoning guidance (for the LLM running doctor)

1. **Read SCHEMA.md first, then this file.** Doctor's intelligence is the union
   of both. Without SCHEMA, doctor doesn't know what "correct" means for this repo.
2. **Cite SCHEMA sections in findings.** Every ERROR should say which SCHEMA
   rule it violates — this grounds the fix and teaches the user.
3. **Context-awareness is non-negotiable.** Same symptom in different `ctx` =
   different command. Getting this wrong is worse than not suggesting a fix.
4. **When in doubt, print. Do not execute.** Doctor is a diagnostic tool, not
   a code editor.
5. **Never auto-edit brain content.** Dates, wikilink targets, prose, feature
   bodies, frontmatter values the user wrote — these are the project's record
   of meaning and must stay in the user's hands.
6. **Never run broad `git checkout HEAD -- .brain/`** — always narrow per file.
   Broad form destroys uncommitted work across the whole brain.
7. **Never execute stash/pop sequences.** Stash-pop can conflict; leaves a mess
   worse than the original problem. Print the sequence; let the user run it.
8. **Never touch a file with conflict markers during a merge.** Let git's
   normal flow (`--ours` / `--theirs` / manual) handle it.
9. **Verify once, then stop.** If a whitelisted fix's verify fails, print a
   diagnosis block (command, exit code, stderr, what verify looked for vs
   found) and defer to the user. No fallback loops, no retries.
10. **Stay small.** If a new failure mode appears, first ask whether SCHEMA.md
    needs a clarified rule. Adding a row to the recovery table is the second
    step, not the first.

---

## Version alignment

- This playbook is `v1.0`. It targets `SCHEMA.md v2.0` (the first line of the
  skill's `SCHEMA.md`).
- Before running invariant checks, doctor should compare the version lines of:
  - `.brain/SCHEMA.md` (repo)
  - `~/.claude/skills/brain/SCHEMA.md` (local skill)
  - this file's first line
- If the repo's `SCHEMA.md` is older than the local skill's, doctor may still
  run checks, but should note in CONTEXT: *"Repo SCHEMA is vX; newer checks
  may reference invariants that don't yet apply."* Treat unsupported invariants
  as WARNINGs, not ERRORs.

When brain's schema version bumps, bump this file's version too and list the
changed invariants in a short changelog at the bottom of this file.

---

## Changelog

- **v1.0** — Initial playbook. Covers SCHEMA.md v2.0. Phase 0 probe, structural /
  content / git / installation invariants, 20-row recovery table, two-item auto-fix
  whitelist, reasoning guidance.
