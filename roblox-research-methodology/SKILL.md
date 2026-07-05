---
name: roblox-research-methodology
description: Use when forming or testing a hypothesis in a Roblox game project — investigating a bug's root cause, proposing a mechanism ("I think the CFrame flips because..."), deciding whether a fix or feature idea is proven or still a hunch, designing a playtest or Studio experiment, wondering whether to keep digging or stop, retiring an idea, or asked "how do we know that?", "is this verified?", "should we try X?". Also when an investigation keeps producing partial fixes that don't stick.
---

# Roblox Research Methodology

## Overview

A hunch becomes an accepted result only after it predicts numbers before the experiment and its mechanism explains every observation, including the negative ones. Anything short of that stays labeled a hypothesis, and abandoned hypotheses get written down, not dropped. This applies to every house-stack project (docs/plans/ lifecycle, docs/BOARD.html kanban, FeatureFlags class, per the project's CLAUDE.md).

## When to use / When NOT to use

**Use when:** root-causing a bug, proposing a mechanism, designing an experiment or playtest, deciding proven-vs-hunch, retiring an idea, or judging when to stop an investigation.

**Do NOT use for:**

| Task | Use instead |
| --- | --- |
| Hands-on triage of a live symptom (which experiment discriminates) | roblox-debugging-playbook |
| The actual math derivations (spawn counts, income curves, DevEx) | roblox-proof-and-analysis-toolkit |
| What evidence a change needs before "done" (tests, scenarios, lanes) | roblox-validation-and-qa |
| Whether you may make the change at all (tuning gates, hard rules) | roblox-change-control |
| Past settled battles and currently-open bugs | roblox-failure-archaeology |
| Platform mechanics themselves (CFrame math, replication, DataStores) | roblox-platform-reference |
| Plan-file mechanics, board card movement | the project's CLAUDE.md owns the plan lifecycle; roblox-docs-and-writing owns doc mechanics |

## 1. The evidence bar

A mechanism is **accepted** only when it explains ALL observations — including the negatives ("the received value was correct", "the fix didn't change the symptom"). A mechanism that explains three of four symptoms is not "mostly right"; it is wrong or incomplete.

**Case study — the trap placement saga (learned in a shipped firebit game, 2026; full chronicle in roblox-failure-archaeology).** Symptoms observed: (1) client ghost preview and server-placed trap disagreed by 180° yaw; (2) descendant parts of the placed Model were mirrored; (3) the placed Model's descendants sat at their original asset CFrames even though logging proved the network-received CFrame was correct; (4) asymmetric assets drifted orientation only when spawned through a pickup wrapper. Each partial fix explained a subset and the bug survived. The saga closed only when every symptom had a verified cause:

| Symptom | Mechanism |
| --- | --- |
| 180° client/server disagreement | left-handed basis (`up:Cross(WORLD_FORWARD)`); Roblox silently re-normalizes CFrames to right-handed over the network, so client (post-network) and server (local) disagreed |
| Mirrored descendants | same left-handed basis, pre-network on the ghost |
| Descendants at original CFrames despite a correct received CFrame | `PivotTo` on an **unparented** Model can leave descendants behind — parent-order bug, proven by diag logging |
| Asymmetric assets drifting | pickup wrapper collapsed the Model to a bounding-box part |
| (contributing) Euler round-trip mismatch | `CFrame.Angles` (XYZ) doesn't round-trip `ToEulerAnglesYXZ` |

The settled architecture (wire payload = position + YXZ Euler table, never raw CFrames) removed the whole class of representation mismatch. The platform facts live in roblox-platform-reference; the lesson lives here: **when a fix ships and a symptom remains, your mechanism was wrong — go back to observations, don't stack another patch.**

**Adversarial refutation (skeptic pass).** Before adopting a conclusion X reached in a session, run a deliberate attempt to refute X: re-read the raw observations asking "what would I expect to see if X were false, and do I see it?"; grep for counterexamples; if a subagent is available, spawn one whose only brief is "argue X is wrong, with evidence". X is adopted only if the refutation fails. This is the project CLAUDE.md honesty rules ("never fabricate, say I haven't verified this") applied to conclusions, not just symbols.

## 2. Predict numbers BEFORE running

State the predicted observable — a number, not a direction — before the experiment. "It should improve" is not a prediction; "night 3 solo should spawn 7 NPCs" is. Derivation recipes live in roblox-proof-and-analysis-toolkit; this section owns the discipline.

The pattern:

1. Find the actual formula in the project's data module (`src/Shared/Data/...`) — read it, don't recall it.
2. Derive the predicted value by hand from that formula for the exact scenario you will run.
3. Name where the actual value will be read: a telemetry/balance-log print, a currency leaderstat, a console count. If the project has no such observable for this system, adding one (flag-gated) is part of the experiment.
4. Write the prediction into the plan file's verify clause before the run; record actual vs predicted after — even (especially) on mismatch. Match → model confirmed; mismatch → you learned something either way.

**Case study A (shipped firebit game, 2026):** the NPC wave-count formula was evaluated by hand for a specific night/player-count ("predict 7"), written into the plan, then read back from a server-side balance-log night summary print. **Case study B (same project):** a friend-bonus multiplier floored small integer session-currency awards to invisibility (`floor(2 × 1.15) = 2`), so stochastic rounding was added with the verify criterion written in advance — "Studio command-bar run over 1000 samples averages ~2.3". The number preceded the run.

Checklist before any experiment or playtest:

- [ ] Hypothesis written as one sentence with a mechanism, not a vibe.
- [ ] Predicted observable stated with a number/range and where it will be read.
- [ ] Prediction recorded in the plan file's verify clause before the run.
- [ ] After the run: record actual vs predicted, even (especially) on mismatch.

Tuning changes carry an extra gate on top of this: roblox-change-control rule 4 (stated rationale + predicted metric + evidence path).

## 3. The idea lifecycle

Stages per the house conventions. Plan-file format and board mechanics are owned by the project's CLAUDE.md / roblox-docs-and-writing — this section owns what makes each stage *earned*.

| Stage | What it is | How to verify it in the current project |
| --- | --- | --- |
| **Seed** | one-liner in the parking lot (`docs/plans/plans.md`, if the project keeps one) or a Backlog card on `docs/BOARD.html` | `head docs/plans/plans.md`; open the board's Backlog lane |
| **Plan draft** | `docs/plans/<name>.md` per the CLAUDE.md template, `status: draft` | `grep -l "status: draft" docs/plans/*.md` |
| **Gated experiment** | the change ships behind a switch so it can be tried and reverted cheaply: a FeatureFlag (boolean in `src/Shared/Class/FeatureFlags.luau`), a Studio-only path, or a data-value bump | `grep -n "<FlagName>" src/Shared/Class/FeatureFlags.luau`; flag inventory lives in roblox-config-and-flags |
| **Testing-lane evidence** | board Testing lane = code done, Studio/playtest evidence still owed; evidence bar per roblox-validation-and-qa | check the board's Testing lane against actual playtest notes in the plan file |
| **Done + archive** | all boxes checked, `status: done`, plan moved to `docs/plans/archive/` | `ls docs/plans/archive/` — an empty archive with "done" work is doc debt (historically under-followed; see roblox-docs-and-writing) |
| **OR documented retirement** | the idea dies with a written rationale — commit body, plan note, or strategy doc | `git log --grep="<idea>"`; grep plans for an "Explicitly dropped" / decision-note section |

**Case study — test-rollover by id bump (shipped firebit game, 2026):** when the persistence layer resets a player's saved progress on a version-id mismatch, bumping a data-module id (e.g. season `"S1"` → `"S1-test1"`) restarts everyone's progress for a from-scratch retest, then bumping again re-tests. Cheap, reversible, no schema surgery — a legitimate gated-experiment technique wherever the profile code has that mismatch-reset behavior (verify it does before relying on it).

**Case study — documented retirement (shipped firebit game, 2026):** a bonus mechanic was removed with the rationale in both the commit body and the plan's decision note ("contradicted the single-currency design intent"), and a strategy doc kept an "Explicitly dropped (do NOT build)" list for rejected dark-pattern ideas. The write-down is the deliverable, not the deletion.

**Diag-commit pattern.** Temporary diagnostic commits are acceptable and expected during hard investigations — they get removed in the eventual fix commit. Find prior instances in the current project with `git log --all --oneline -i --grep="diag"`. Prefer **flag-gating** prints over committing bare ones: the better end-state is a `DEBUG` flag (off) guarding them, not naked prints awaiting cleanup (the originating game shipped bare turret debug prints and had to gate them in a follow-up commit). Remember commits stay local either way — never push to origin main/production (roblox-change-control rule 1).

## 4. Where good ideas come from

Consult these sources before inventing from scratch:

| Source | Pattern | How to use it |
| --- | --- | --- |
| **Cross-project porting** | sibling studio games share the house stack, so whole systems port (the originating game's weapon, vehicle, and NPC-chase systems were each ported from a sibling firebit game rather than redesigned) | when a system exists in a sibling studio game, port and adapt rather than redesign; check sibling repos before greenfielding |
| **Off-repo strategy sessions** | long-horizon strategy work (progression, monetization) can happen in a claude.ai session and land as a reviewed docs-only merge that later drives multiple features | treat a landed strategy doc as an idea backlog with rationale already attached |
| **Platform docs + market data** | the studio knowledge repo at `/Users/dig1t/Git/brain` (read-only): compiled wiki at `obsidian/brain/knowledge/index.md`, official creator-docs guides, engine API YAML, RoMonitor trend snapshots | optional deepening — read its `index.md` first; load-bearing platform facts live in roblox-platform-reference |
| **House pattern references** | `/Users/dig1t/Git/hot-potato` Router/App is the canonical house React pattern source | pattern reference only, not a dependency |

## 5. When to stop

Stop an investigation line when either:

- **Two consecutive dry rounds** — two full hypothesis→experiment cycles that neither confirmed nor narrowed anything, or
- **The mechanism is refuted** — the discriminating experiment contradicted the hypothesis.

Then do NOT silently abandon. Write the negative result down where the next session will find it:

1. In the plan file, as a paused/decision note: what was hypothesized, what was tried, what was observed, why it's rejected or parked (model: a "SEPARATE BUG — flag for its own ticket" note inside the plan that surfaced it, so the dead end is scoped instead of lost).
2. If it's an open bug or a dead-end mechanism others might retry: record it in roblox-failure-archaeology's OPEN section.

A written negative result is a research output. An unwritten one is a guaranteed repeat of the same dead end by the next session.

## Common mistakes

- Accepting a mechanism that explains most symptoms — the trap-placement saga (section 1) is the canonical example of exactly this.
- Running the playtest first and rationalizing the number afterward. Prediction goes in the plan file *before* the run.
- "It should feel better" as a verify criterion. Name the observable and where you'll read it.
- Concluding X and moving on without a skeptic pass — assign the refutation, don't skip it because the story is tidy.
- Tuning a number as an "experiment" without the roblox-change-control rule-4 package (rationale + predicted metric + evidence path).
- Silently dropping a dead-end investigation — write the negative result (section 5).
- Committing bare debug prints with no flag and no removal plan; if you must commit diagnostics, mark them `diag(...)` and strip them in the fix commit.
- Reinventing a system a sibling studio game already ships (section 4) — check sibling repos and the studio knowledge repo first.

## Provenance and maintenance

Derived 2026-07-05 from the firebit house-stack reference project; case studies are attributed to it and are illustrative only — no rule here depends on that repo or its git history existing. Re-verify volatile facts against the CURRENT project repo:

- Parking lot exists: `head -5 docs/plans/plans.md`
- Draft plans: `grep -l "status: draft" docs/plans/*.md`
- Flag inventory: `grep -n "= true\|= false" src/Shared/Class/FeatureFlags.luau`
- Archive discipline: `ls -a docs/plans/archive/`
- Prior diag commits: `git log --all --oneline -i --grep="diag"`
- Retirement rationales: `git log --oneline --grep="drop\|remove\|retire" -i` plus grep plans for "Explicitly dropped" / decision notes
- Studio knowledge repo present: `ls /Users/dig1t/Git/brain/obsidian/brain/knowledge/index.md`
