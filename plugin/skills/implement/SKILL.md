---
name: implement
description: Turns a ready (readiness:ready) issue into code by driving the environment's SDD (spec-driven development) design and build phases headlessly, then returns a parsed build report for the caller's smoke gate and PR body. An atomic unit of the composable lifecycle (ADR-0009) — independently invocable, no sequencing of its own; discovers the design/build entrypoints at runtime rather than hardcoding a plugin namespace. Use when a composer (`/pickup`, the full-lifecycle engine) needs the implement movement of the issue → PR flow, or to smoke-test it standalone on one ready issue. Does not re-check readiness, branch, or open the PR.
---

# Implement

Turns a **ready** issue into **code**: synthesizes a minimal design input from what the issue already says, drives the environment's separately-installed SDD workflow plugin through its **design** and **build** phases headlessly, and hands back a parsed build report. The *design → build* movement of the issue lifecycle (ADR-0009 — Proposed — the atomic-skill framing this fits into): nothing before it (the DoR re-check, the branch) and nothing after it (the smoke gate, the PR) — see **Scope**.

> **No GitHub writes.** This skill touches only the local working tree — the synthesized input, `.gitignore`, and whatever the design/build phases produce. Nothing here needs the bot identity; the composer's own commit/push (already bot-authored, per `git-collaboration`) picks these files up along with the rest of the implementation chunk.

## Input

Everything below assumes you're **already on the implementation branch, in the target repo** — branching is the composer's job, done before it calls this skill.

You need the ready issue's DoR content — problem statement, success criteria, acceptance tests:
- **Composed** (preferred) — the caller already re-checked DoR (per `dor-rubric.md`) and hands this straight through; don't re-fetch it.
- **Standalone** (smoke-testing this skill on its own) — fetch it yourself:
  ```bash
  gh issue view <N> --repo OWNER/REPO --json title,body,comments,labels
  ```
  Confirm `readiness:ready` is on the issue before proceeding. Re-deriving the DoR verdict is `refine-issue` / the composer's re-check's job, not this skill's — but running against a not-actually-ready issue is a cheap footgun worth a guard.

## Step 0 — Environment pre-check (stop here if it fails)

The SDD design and build phases are **not vendored in this plugin** — they come from a separately-installed SDD workflow plugin (5-phase: brainstorm → define → design → build → ship). Availability was confirmed at DoR-refinement time; headless *operability* was not — this check is what closes that gap, on every run, rather than trusting a memory of last time.

Look at what's actually available in **this session** — not a remembered or assumed name:
- Scan your available skills for one that creates "architecture and technical specification" (Phase 2 / design) and one that "executes implementation" (Phase 3 / build).
- Scan your available agent types for the same two phases — some SDD plugins expose a phase as a skill, some as an agent, some as both.
- A real hit is usually namespaced `<plugin>:workflow:design[-agent]` / `<plugin>:workflow:build[-agent]` — but the prefix is whichever plugin happens to be installed. **Never hardcode a specific plugin's namespace**; a different machine installs a different one.

Reject a candidate that is **interactive-only** — design and build must run unattended. The strength of that signal differs by surface: an **agent** surface declares a harness-enforced `Tools:` list, so an `AskUserQuestion` grant is a hard guarantee it's interactive (that's brainstorm/define) — reject it. A **skill** surface has no enforced tool list, so judge it by framing alone: a description reading like "collaborative dialogue" or "capture requirements" is interactive.

- **Both resolve, headless** → record their exact names (you'll need them for the `Method:` line) and continue.
- **Either is absent, or only an interactive variant exists** → **STOP.** Do not fall back to planning or building it yourself — that would re-implement what this atomic skill exists to delegate. (This deliberately differs from `a2a-workflow`'s older P5 stance, which falls back to `the-planner` + `codebase-explorer` when AgentSpec is absent — that fallback is a composer's prerogative if it chooses to keep offering one; this atomic skill's own contract is stop-and-report, not silent degrade.) Return a Blocked report (`assets/build-report-summary.md`) naming exactly what's missing, e.g. "no headless Phase 2 (design) entrypoint found among available skills/agents."

## Step 1 — Synthesize the design input

The issue already passed the Definition of Ready — D1 (verifiable outcome) and D3 (interpretation convergence) already forced its problem statement and checkable criteria to be explicit (`dor-rubric.md`). **Assemble, don't invent:** pull the problem statement from the issue's Summary/Motivation, and the checkable criteria from whichever checklist its type template used (Definition of done · Acceptance criteria · Expected vs actual) — reframe each bullet as a one-line acceptance test. Carry over any logged assumptions from the issue's DoR-audit comment verbatim; design should honor them, not re-litigate them.

This is intentionally **thinner** than a full interactive DEFINE document — no clarity score, no target-users table, no assumptions ledger. Those come from a collaborative Define pass this run doesn't have (see **What this skips**); design needs problem + criteria + tests, not the full ceremony.

```bash
mkdir -p .claude/sdd/_synthesized .claude/sdd/features .claude/sdd/reports
grep -qxF '.claude/sdd/_synthesized/' .gitignore 2>/dev/null || \
  printf '\n# implement skill — throwaway synthesized design-input (never commit)\n.claude/sdd/_synthesized/\n' >> .gitignore
```

Write the synthesized doc to `.claude/sdd/_synthesized/DEFINE_<SLUG>.md` — `SLUG` = a short, stable, readable tag such as `ISSUE_<N>_<UPPER_SNAKE first few words of the title>` (e.g. issue #52 → `ISSUE_52_IMPLEMENT_SKILL`; the exact casing isn't load-bearing, only stability across this run is). This is the throwaway half of the artifact split — see **Artifact placement**.

## Step 2 — Invoke design, headlessly

Call the Step 0 design entrypoint with the Step 1 file as its input:
- **Skill surface** → call it with the Step 1 file's path as the argument.
- **Agent-only surface** → spawn it (never `subagent_type: fork` — this is a fresh phase run, not a continuation of your context), briefing it with the file path and "run headlessly, do not ask questions."

If both surfaces resolved in Step 0, prefer the skill surface — it keeps artifact capture in the main conversation.

It writes its artifact to `.claude/sdd/features/DESIGN_<SLUG>.md` — this project's fixed SDD working-area convention, independent of which plugin is providing the phase. Capture the path (if it reports a different one, use that instead and note the deviation) and skim it for the inline decisions it recorded — you'll want the highlights for the PR body later.

If design itself can't produce an artifact — a genuine gap even the DoR-passed issue didn't cover — that's a blocker, not a silent stop: record it and produce a Blocked report rather than improvising a design yourself.

## Step 3 — Invoke build, headlessly

Call the Step 0 build entrypoint the same way, with the Step 2 design artifact as its input. It writes code per the design's file manifest, plus `.claude/sdd/reports/BUILD_REPORT_<SLUG>.md`.

Build runs autonomously by its own nature — a decision fork it hits gets resolved and logged into its own report, never escalated back through you. Your job is to let it run and then read what it produced, not to re-decide on its behalf.

## Step 4 — Parse the build report, return it

Read the native `BUILD_REPORT_<SLUG>.md` and normalize it into the shape in `assets/build-report-summary.md` — status, files touched, autonomous decisions, blockers, acceptance-test verification, plus the `Method:` line (below). Hand this back to the caller; it's what feeds:
- the caller's own **G2 verify/smoke gate** (`a2a-workflow/assets/verify-gate.md`) — a Blocked or failing-acceptance-test report is not something to round up to green;
- the **PR body** — the summary and acceptance-test table are the "what changed" + "test plan" material `create-pr` expects.

## What this skips, and why

| Phase | Why `implement` doesn't run it |
|---|---|
| **Brainstorm** (0) | Collaborative exploration for an unclear idea — this issue already cleared the DoR gate; there's nothing left to explore. |
| **Define** (1) | Collaborative requirements capture — the calling composer's own DoR gate already forced verifiable-outcome + convergent-interpretation quality; Step 1 assembles from it instead of re-deriving it. |
| **Ship** (4) | Archives to `.claude/sdd/archive/` and closes the loop — this project already has its own closing move (`create-pr` → blind review → human merge); running SDD's ship too would race two "done" mechanisms. |

## Artifact placement — the committed / gitignored split

```
.claude/sdd/
├── _synthesized/                    # gitignored — throwaway, this skill's own input
│   └── DEFINE_<SLUG>.md
├── features/
│   └── DESIGN_<SLUG>.md             # committed — reviewer-facing design record
└── reports/
    └── BUILD_REPORT_<SLUG>.md       # committed — reviewer-facing build evidence
```

Only `_synthesized/` is gitignored. The synthesized define stand-in earns nothing on its own — it's a mechanical assembly of facts already sitting in the issue, not a collaborated artifact — so it isn't worth version-history noise. The DESIGN and BUILD_REPORT are the reviewer's traceability trail (what was decided, what was built, what was verified) and go into the PR like any other change.

If the target repo already gitignores `.claude/` wholesale, that would silently swallow the DESIGN and BUILD_REPORT too — don't assume the split holds. Check both paths with `git check-ignore` before relying on it (this is the same check the smoke procedure runs); if either is unexpectedly ignored, the composer's commit step needs an explicit `!.claude/sdd/features/` / `!.claude/sdd/reports/` un-ignore rule.

## Method attribution

Per ADR-0008 (canonical-method discipline — Proposed): record which method produced the code as an auditable line, not silently. `implement`'s method is always the same shape, using the exact names Step 0 resolved:

```
Method: SDD design+build (<resolved design entrypoint> -> <resolved build entrypoint>)
```

ADR-0008 hasn't yet settled *where* this line ultimately lives (PR body vs. commit trailer vs. issue field — its own open questions say so); until it does, carry it inside the returned build-report-summary and let the caller place it.

## Smoke procedure

1. Pick a real `readiness:ready` issue in a repo that has an SDD workflow plugin installed — a scratch/disposable repo, not this one, so a throwaway feature doesn't pollute `agentic-dev`.
2. Run Step 0 for real; capture the resolved design/build entrypoint names (or the exact Blocked reason, if resolution fails).
3. Run Steps 1–4 end to end on that issue; capture:
   - the synthesized `DEFINE_<SLUG>.md` path and a 2–3 line excerpt;
   - the resolved `DESIGN_<SLUG>.md` path and a 2–3 line excerpt;
   - the resolved `BUILD_REPORT_<SLUG>.md` status field;
   - `git status --short` showing the code changes plus the two committed artifacts, with the synthesized input absent;
   - `git check-ignore -v .claude/sdd/_synthesized/DEFINE_<SLUG>.md` (expect: matched) **and** `git check-ignore -v .claude/sdd/features/DESIGN_<SLUG>.md` (expect: not matched) — this is what actually proves the committed/gitignored split, not just the `.gitignore` file's text.
4. Paste the full transcript (commands + output, including the Blocked path if you deliberately trigger one by renaming a plugin) as the smoke evidence.

## Scope

- **In:** one ready issue, from DoR content to a parsed build report — pre-check, synthesize, design, build, parse, return.
- **Out:** re-running the DoR gate (the caller's job — `refine-issue` / the composer's re-check); creating the branch (the composer, before calling this); opening the PR (`create-pr`); the SDD ship/archive phase (see **What this skips**).

## DOs / DON'Ts

**DO:** resolve the design/build entrypoints fresh every run, by matching what's actually available · treat a missing or interactive-only phase as a stop, not a workaround · assemble the design-input from the issue's own DoR content, never invent requirements · keep the native DESIGN/BUILD_REPORT as the full record and the summary as the handback contract · gitignore only the synthesized input.

**DON'T:** hardcode a plugin namespace (e.g. `agentspec:...`) as if it's the only possible one · run brainstorm/define/ship · let build's autonomous decisions become questions back to you · round a Blocked or partially-failing build report up to "done" · commit the synthesized design-input.
