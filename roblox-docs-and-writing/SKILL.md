---
name: roblox-docs-and-writing
description: Use when reading, creating, updating, or archiving documentation in a firebit Roblox project — plan files in docs/plans/ (frontmatter status, checkboxes, paused notes, archiving), moving a card on docs/BOARD.html without breaking the HTML or the session snapshot, deciding which doc is authoritative (PROJECT.md vs ARCHITECTURE.md vs DESIGN.md vs README), Moonwave API docs / build:docs / @class annotations, auditing stale plans, or how to word and date-stamp docs.
---

# roblox-docs-and-writing

## Overview

Every firebit Roblox project carries the same small, opinionated doc set with one home per fact, and every project's docs rot in the same predictable ways. This skill maps the standard doc set, gives the exact mechanics for plan files and board edits, and shows how to audit and fix documentation debt forward instead of tripping on it.

## When to use

- You need to know which doc answers a question (game facts, stack, UI, task state).
- You are creating, updating, pausing, or archiving a plan file in `docs/plans/`.
- You are moving a card on `docs/BOARD.html` or the session board snapshot looks wrong.
- You are writing any doc, plan, or skill text and need the house style.
- A plan file contradicts reality (unchecked boxes for shipped work, dead links).

## When NOT to use

- The lifecycle *rules* (when a plan is mandatory, compliance triggers, statuses) — the project's CLAUDE.md owns those; this skill owns the practical mechanics only.
- What counts as "verified" evidence for checking a box — see **roblox-validation-and-qa**.
- Whether a change is allowed at all (push, rblxsync run, dormant code, tuning) — see **roblox-change-control**.
- Known code bugs referenced by plans — see **roblox-failure-archaeology**.
- CI workflows and what a push to main does — see **roblox-run-and-operate**.

## Map of the docs of record (house convention)

| Doc | Owns |
| --- | --- |
| `docs/PROJECT.md` | Game facts: genre/core loop, currencies and their persistence, monetization surface, config rules. Mandatory read at task start (CLAUDE.md file map) |
| `docs/ARCHITECTURE.md` | Shared stack doc (Luau strict, Rojo, Wally, React 17 App/Router, Replica, ProfileDB, Promise, red), directory map, service/Replica/ProfileDB/Router patterns, gotchas. **Shared across the studio's games** — flag staleness to the owner; do not silently rewrite it |
| `DESIGN.md` (repo root) | UI design system: look, color tokens, typography, component recipes. Mandatory read before UI work |
| `docs/BOARD.html` | Kanban: in progress, testing, up next, backlog, done. Single source of truth for task state |
| `docs/plans/` | One file per non-trivial task; the working memory of the project |
| `docs/plans/archive/` | Destination for `status: done` plans |
| `README.md` | Often stale boilerplate ("firebit boilerplate for Roblox games"). Verify with `head README.md` before citing it; do not expand it without being asked |
| Moonwave API docs | Generated API reference from `--[=[ @class Xxx ]=]` doc comments in `src/`; publishes via `docs.yml` on push to main |

Projects may also carry **historical doc locations**: pre-production strategy suites (e.g. a `docs/game/` GDD/monetization/KPI set) and legacy plan directories from earlier workflow eras (e.g. `docs/superpowers/plans/`). Identify them by their dates and by whether the current CLAUDE.md workflow references them. Read them for intent, never for current numbers; never add files to them; never treat their unchecked items as open work. Recent `docs/plans/` files supersede them on specifics.

`docs/board.css` styles the board; you should never need to edit it to move a card.

Before trusting any doc, build your own trust assessment: check its dates, spot-check one or two volatile claims against the code (`grep` the symbol, `ls` the file), and note staleness in your response rather than repeating it.

## Plan-file mechanics

The project's CLAUDE.md owns the lifecycle rules and the template (goal / steps with `-> verify:` / files / risks). What follows is the practical how.

### Frontmatter

```markdown
---
status: draft
---
```

- Statuses: `draft` → `active` → `done`. Nothing else.
- Older plans may predate the workflow and lack a `status:` field entirely (check with `grep -L "^status:" docs/plans/*.md`). Every **new** plan gets frontmatter; when you touch an old plan, add the frontmatter that matches reality (fix-forward policy, below).

### Checkbox discipline

- Check a box (`- [ ]` → `- [x]`) **in the same turn** its verify criterion passes. Never batch, never defer to end of session.
- A box whose verify step is "Studio playtest" stays unchecked until a human playtests. "Code done" does not check a playtest box — see **roblox-validation-and-qa** for the evidence bar.

### Paused-note format

When stopping mid-step, add a blockquote under the unchecked box. Real example from a shipped firebit game (2026), wrapped for width:

```markdown
- [ ] Playtest with a friend in-server (Studio multi-client or live)
  -> verify: scrap pickups occasionally grant +1, Menus badge shows boost %
  > paused 2026-07-02: needs a human with a friend account — cannot be run
  > by the agent. Code path verified statically (stochastic rounding math
  > correct, scrap-only pickup gate correct, flag on).
```

A good paused note answers three questions: what is done, what is not, where to resume. Include IDs and exact resume commands when they exist.

### Archive move + board move, same turn

When the last box is checked:

1. Set `status: done` in the frontmatter.
2. `git mv docs/plans/<name>.md docs/plans/archive/<name>.md` (plain `mv` if the file was never committed).
3. Move/prune the card on `docs/BOARD.html` **in the same turn** (protocol rule 5 below).

Note the board's plan links are relative (`plans/<name>.md`); after archiving, a Done-lane card that keeps its link should point at `plans/archive/<name>.md`.

## BOARD.html editing anatomy

The board is hand-written HTML. `scripts/board-snapshot.sh` renders the active lanes at every session start (SessionStart hook in `.claude/settings.json`), so a broken board is visible immediately — to everyone.

### The Board Protocol (house-standard text; re-verify against your board's `<details class="protocol">` block)

> 1. One card = one plan file, or one task too trivial for a plan.
> 2. Move cards by editing the board. Update it in the same turn as the work.
> 3. **WIP limit:** max 2 cards In Progress. Finish or park before pulling more.
> 4. **Testing** = code done, needs a Studio playtest or rblxsync run to verify.
> 5. On **Done**, archive the plan to `docs/plans/archive/`; prune the card later — git remembers.
> 6. New ideas land in **Backlog** as one-liners; flesh into a plan before Up Next.

### Structure

- Five lanes, each a `<section class="col" data-status="...">`: `in-progress`, `testing`, `up-next` (active trio, first grid), then `backlog`, `done` (second grid, below the `<p class="rail">Parked &amp; Shipped</p>` divider).
- Each lane heading carries a count: `<h2>Testing <span class="count">5</span></h2>`. In Progress shows the WIP limit: `<span class="count">1<small>/2</small></span>`. **Update the count when you add/remove a card.**
- Active lanes use rich cards inside `<ul class="card">`:

```html
<li>
	<article>
		<h3>Card title</h3>
		<p>One-to-three-line status: what's done, what gates it.</p>
		<p class="meta flex flex-wrap">
			<a class="plan" href="plans/plan-file-name.md">plan-file-name</a>
		</p>
	</article>
</li>
```

- Backlog and Done use plain `<ul class="list">` with one-line `<li>` entries, optionally ending in the same `<a class="plan">` link.
- To move a card between active lanes: cut the whole `<li>…</li>`, paste it into the target lane's `<ul class="card">`, adjust both lane counts, and update the card's `<p>` status text to say what gates it now. Moving to Backlog/Done means rewriting the card into the one-line `list` form.
- Indentation is tabs. The file has no `<html>`/`<body>` wrapper; that is intentional, leave it.

### Do not break the snapshot markers

`board-snapshot.sh` slices the file with `sed -n '/data-status="in-progress"/,/class="rail"/p'` and strips tags. Therefore:

- Never rename or remove `data-status="in-progress"` or the `class="rail"` paragraph — the snapshot goes blank.
- Keep card text meaningful after tag-stripping (title line, status line, plan name), because that is exactly what agents see at session start.
- After editing, sanity-check: `bash scripts/board-snapshot.sh` from the repo root and read the output.

## Moonwave API docs

- **What it is:** Moonwave (npm dep) generates a Docusaurus API site from `--[=[ @class Xxx ]=]` doc comments. Services in `src/` carry `@class` annotations; keep the convention when adding a service (example in `docs/ARCHITECTURE.md` "Service Pattern").
- **Commands:** `npm run build:docs` (build to `./build/`), `npm run dev:docs` (local preview). Config in `moonwave.toml` (per-project title and `baseUrl`).
- **Publishing:** `.github/workflows/docs.yml` runs on push to main (path-filtered: `src/**`, `docs/**`, `moonwave.toml`, `README.md`) and pushes the build to the studio's shared docs repo (`firebit-dev/docs`, branch `gh-pages`), with `destination_dir` set to the project's repo name. Pushes to main are owner-only (**roblox-change-control** rule 1), so docs publish only when the owner pushes.
- **Repo-name gotcha:** learned in a shipped firebit game, 2026: the local directory name differed from the GitHub repo name; `destination_dir: ${{ github.event.repository.name }}` resolves to the **repo** name, so `moonwave.toml`'s `baseUrl` must use the repo name too. Verify the two agree: `git remote -v; grep baseUrl moonwave.toml; grep destination_dir .github/workflows/docs.yml`.

## Auditing documentation debt

Docs rot in predictable ways on this stack. Do not assume a project is clean — audit it, keep a dated debt list in your working notes, and fix forward. Policy: **surface and fix-forward when you touch a stale file — never batch-rewrite history in a dedicated cleanup pass** (that destroys the git-visible record of what actually happened, and bulk edits to old plans are exactly the noise **roblox-change-control** exists to prevent).

Standard rot patterns and their audit one-liners (run from the repo root):

| Rot pattern | Audit with |
| --- | --- |
| `docs/plans/archive/` empty despite Done-lane cards | `ls -a docs/plans/archive/` vs the board's Done lane |
| Plans with unchecked boxes for shipped features | `grep -c "^- \[ \]" docs/plans/*.md` cross-checked against the board and the code |
| Plans with no `status:` frontmatter | `grep -L "^status:" docs/plans/*.md` |
| Diagnosed-bug or near-done plans on no board lane | Compare `ls docs/plans/` against `grep -o 'plans/[a-z-]*\.md' docs/BOARD.html` |
| Dead links between plans | `grep -rn "plans/.*\.md" docs/plans/ \| while read ...` then `ls` each target |
| Bugs flagged inside a plan "for its own ticket" with no card or plan | `grep -rin "ticket\|TODO\|follow-up" docs/plans/` — canonical bug record is **roblox-failure-archaeology** |
| `docs/ARCHITECTURE.md` referencing renamed files (e.g. old `.project.json` names) | `grep -n "project.json" docs/ARCHITECTURE.md; ls *.project.json` — flag, don't silently rewrite (shared doc). Build reality: **roblox-build-and-env** |
| `PROJECT.md` claiming a feature is "not wired yet" after it shipped | Spot-check "not yet"/"planned" lines against the code |
| Boilerplate `README.md` | `head README.md` |

Case study (shipped firebit game, 2026): board protocol rule 5 ("archive on Done") went unexecuted for the project's entire first five months — `archive/` held only a `.gitkeep` while Done-lane cards linked to un-archived plans with unchecked boxes, and several near-done plans sat on no lane at all. Every one of those debts traced to the same root cause: "I'll update the plan/board later." Later never came.

Fix-forward in practice: touching a stale done-in-reality plan for any reason → add `status: done` frontmatter, check the boxes you can *verify from the code/board today* with a dated note (`> boxes checked retroactively YYYY-MM-DD: feature verified shipped via <evidence>`), archive it, and fix the board link. One file per touch, in the turn you touched it.

## House writing style (docs, plans, skills)

- **Date-stamp volatile facts.** Product IDs, flag values, board state, counts: write "(as of YYYY-MM-DD)". Undated volatile claims are future bugs.
- **"Code done" ≠ "verified".** Say which one you mean, every time. "Code done, needs Studio playtest" is the house phrase (it is board protocol rule 4 territory). The evidence bar for "verified" belongs to **roblox-validation-and-qa**.
- **No oversell.** Unshipped work is "open", "candidate", or "pending playtest" — never "done", "live", or "shipped" until it is. Minted-but-unplaytested products are "minted, unverified in game".
- **Imperative runbook voice** for skills and plan steps ("Run X. Check Y."). Tables and checklists over prose.
- **Cite evidence paths**, not vibes: file:line, commit hash, product ID, or the command whose output you saw.
- **One home per fact.** Cross-reference the owning doc/skill by name instead of restating it.
- No emojis in docs or commit text.

## Common mistakes

- Editing code and leaving the plan/board untouched "for later". The CLAUDE.md compliance trigger says the plan updates in the same turn; the board protocol says the card moves in the same turn. Later never comes — that is exactly how the case-study debts accumulated.
- Moving a board card without updating the lane `<span class="count">`, or pasting a rich `<article>` card into a `list`-style lane (Backlog/Done) instead of collapsing it to one line.
- Renaming/removing the `data-status="in-progress"` or `class="rail"` markers, which blanks the SessionStart snapshot for every future session.
- Treating pre-production strategy docs or explicitly stale balancing docs as current tuning targets. Tuning changes need the **roblox-change-control** rationale/metric/evidence gate anyway.
- "Cleaning up" all stale plans in one sweep. Fix-forward only, one file per touch.
- Silently rewriting `docs/ARCHITECTURE.md` to fix staleness — it is shared across the studio's games; flag it to the owner instead.
- Adding a new plan to a legacy plan directory (historical only) or citing a boilerplate README.md as a source of truth.
- Writing a paused note that says "WIP, will continue" — useless. State what is done, what is not, where to resume, with IDs/commands.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project. Structure and commands were verified there; every re-verification command below runs against the **current project's** repo root, and volatile facts (lane contents, plan statuses, counts) must be re-checked per project before relying on them:

| Fact | Re-verify with |
| --- | --- |
| Board protocol text + lane contents | Read the `<details class="protocol">` block in `docs/BOARD.html`; `bash scripts/board-snapshot.sh` |
| Lane/card counts, board structure | `grep -n 'data-status\|class="count"\|class="rail"' docs/BOARD.html` |
| Which plans have frontmatter + statuses | `grep -n "^status:" docs/plans/*.md; grep -L "^status:" docs/plans/*.md` |
| archive/ state | `ls -a docs/plans/archive/` |
| Unchecked-box counts per plan | `grep -c "^- \[ \]" docs/plans/*.md` |
| Moonwave config/publish target | `cat moonwave.toml; grep -n "destination_dir\|external_repository\|baseUrl" .github/workflows/docs.yml moonwave.toml` |
| Repo name vs directory name | `git remote -v; basename "$(pwd)"` |
| `@class` annotation presence | `grep -rc "@class" src --include="*.luau" \| awk -F: '{s+=$2} END {print s}'` |
| Snapshot hook still registered | `grep -n "board-snapshot" .claude/settings.json` |
| Historical/legacy doc locations and their dating | `ls docs/; grep -rn "Last Updated" docs/game/ 2>/dev/null` |
| README state | `head README.md` |
