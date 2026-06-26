---
name: fix-bug
description: Fix a bug end-to-end through the full A2A workflow — reproduce, root-cause, draft a [BUG] issue, branch, fix, verify with a real smoke, open a PR, and run a blind review. Use whenever the user reports a defect or wants a bug fixed properly (issue + branch + PR), not just a throwaway patch — e.g. "fix the bug where…", "X is broken", "this silently does the wrong thing", "the CLI crashes when…". Wraps the a2a-workflow engine with bug-specific settings.
argument-hint: "[bug description or issue #]"
---

# Fix Bug — thin wrapper over `a2a-workflow`

**This is a thin wrapper. It does NOT re-implement the flow** — it sets the bug-specific knobs and hands off to the **`a2a-workflow`** engine, which runs P0→P8 and the four quality gates. Don't hand-write `gh` / issue / PR mechanics here; those belong to the action skills the engine calls (`create-issue`, `publish-issue`, `create-pr`). `review-pr` is **not** one of them — it's the *other* agent's job; the engine's own check is the P7 blind-review pass.

If a `[BUG]` issue already exists (the user gave an issue #), skip drafting — start the flow from it.

## What this wrapper sets (vs the shared engine)

| Knob | Bug setting |
|---|---|
| Issue template | **bug** — `[BUG]` title; sections `## Reproduction` · `## Expected` · `## Actual` · `## Root cause` · `## Acceptance criteria`. |
| Branch | `fix/<slug>`. |
| Labels | built-in `bug` + `phase:*` + `priority:*` (kb scheme). **Bump to `priority:p0`/`p1`** when it silently costs money/tokens, corrupts data, or hits every user. |
| ADR | **almost never** — a bug fix is a decision only if the *fix itself* changes architecture. Default: no ADR. |
| Expansion (P1) | narrow the lenses to **root-cause + sibling-defect scan**: where else does this same defect pattern live? |

## Bug-specific must-dos (on top of the engine's gates)

1. **Reproduce FIRST.** Don't propose a fix you haven't watched fail. The reproduction goes into the issue verbatim and *becomes* the smoke test's success condition: **fix applied → the repro now behaves.**
2. **Root cause, not symptom.** Trace to the actual defect; a patch over a symptom leaves the bug alive somewhere else.
3. **Sibling-defect scan.** `grep` for the same pattern at other call sites / sibling handlers. Fix the reachable ones; flag latent ones **honestly as defense-in-depth** — don't inflate them into live bugs (a sharp reviewer catches the overstatement).
4. **The smoke proves the fix.** G2's smoke must demonstrate *the specific repro now passes*. If the buggy path is paid/destructive, use the **shadow trick** (stub the paid binary; prove the guard fires with zero spend).

## Run it

Hand off to **`a2a-workflow`** with the settings above. The engine drives the rest: intake → expansion/ripple → clarification gate → draft + publish the `[BUG]` issue → `fix/` branch (pushed immediately) → implement in chunks (push each verified one) → verify/smoke gate → PR → blind-review → report. Headless: a blocking question becomes a documented assumption + a draft PR; **the human merges.**

> Worked example to model on: the bilingual `--backend` silent-paid-default fix (issue #1 / PR #2) — reproduced, root-caused to two defaults (one live, one latent), smoked with the shadow trick, blind-reviewed, reported.
