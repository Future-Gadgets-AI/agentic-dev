# Definition of Ready — the autonomy-gate rubric

> **Enforcement: prompt-honored forcing function.** `/pickup` is *told* to run this before doing work; it is not hook-enforced. Irreversible (RED) steps must *additionally* be gated at the harness layer (ADR-0004) — a prompt is not a guarantee. The gate raises the floor; the shadow-trick + human merge cap the ceiling.

The question: **can an agent pull this issue and run it unattended, or does it need a human first?** Keyed to **reversibility × blast-radius — never model confidence** (confidence is miscalibrated and inflates as context grows).

## Pass 1 — set the bar: **D5 Blast-Radius / Reversibility**
Classify the cost of a *wrong guess* (the consequence, not how sure the model feels):
| Level | Meaning | Examples |
|-------|---------|----------|
| 🟢 **GREEN** (two-way door) | cheaply reverted, contained | code behind a flag, isolated module, branch/PR not yet merged, docs, pure refactor with tests |
| 🟡 **AMBER** | reversible in code, with reach / coordination cost | shared-interface change, non-destructive schema add, public API name, cross-team dependency |
| 🔴 **RED** (one-way door) | irreversible or wide blast radius | data deletion/migration, money movement, external/customer-facing sends, auth/secrets, prod infra |

## Pass 2 — grade the issue (each PASS / WEAK / FAIL)
| Dim | Question | A FAIL emits |
|-----|----------|--------------|
| **D1 Verifiable outcome** | is "done" explicitly checkable (a runnable test / observable assertion)? | "what concrete check proves this is done?" |
| **D2 Bounded scope** | one coherent ~hours change with known edges? | "split into …?" |
| **D3 Interpretation convergence** | one reading of the load-bearing terms? Test *behaviorally*: sketch ≥2 candidate interpretations; if they diverge in behavior ⇒ ambiguous | the divergent interpretations, as a multiple-choice question |
| **D4 Reachable context** | is everything needed present or self-discoverable? Split missing info into **epistemic** (exists in the repo) vs **aleatoric** (intent only the human holds) | epistemic ⇒ an explore-directive the agent runs itself; aleatoric ⇒ a human question |

The **D4 epistemic / aleatoric split** is the anti-over-asking valve: if the answer is in the codebase, the agent goes and finds it; only true intent-gaps become questions.

## The decision (explicit — not a weighted score)
- **RED:** require D1–D4 all PASS. Any WEAK/FAIL ⇒ **NOT-READY**. Even all-PASS ⇒ gate the irreversible step at the harness layer.
- **AMBER:** any FAIL ⇒ NOT-READY; any WEAK ⇒ **READY-WITH-LOGGED-ASSUMPTIONS** (record the assumption; take the most reversible path).
- **GREEN:** FAIL on D1 or D3 ⇒ NOT-READY; WEAK/FAIL on D2 or D4 ⇒ READY-WITH-LOGGED-ASSUMPTIONS.

## Three verdicts
- **READY** — proceed autonomously.
- **READY-WITH-LOGGED-ASSUMPTIONS** — proceed; each WEAK dimension becomes a written assumption on the PR; prefer the reversible path.
- **NOT-READY** — do **not** code. Emit the failing dimensions as targeted questions (D1/D3, aleatoric D4) or explore-directives (epistemic D4). Label `readiness:needs-refinement` (pre-pickup) or `status:needs-decision` (mid-flight), comment the gaps, bounce to the human.

## Not readiness theater
No single number — a "7/10" gets rubber-stamped and gamed. The output is a **verdict + the named gaps**, so a NOT-READY is *cheap to clear*: it hands back concrete questions and speeds work up rather than stage-gating it.

Grounding: agile Definition of Ready + INVEST; ISO/IEC/IEEE 29148 (unambiguous / complete / verifiable); ClarifyGPT (behavioral divergence detection); aleatoric vs epistemic uncertainty; Bezos one-way / two-way doors; SRE blast radius.
