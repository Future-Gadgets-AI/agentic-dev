# Constitution — agentic-dev

Non-negotiable operating rules for autonomous and human-assisted work in this repository, patterned on [github/spec-kit](https://github.com/github/spec-kit)'s constitution: named Core Principles, a mandatory Governance section, a versioned footer. Every principle below traces to an already-accepted ADR or a file in `plugin/contracts/`, or is explicitly marked **newly ratified by this constitution** — no silently invented policy. For the standing mission and current-phase intent this constitution serves, see `GOAL.md`.

## Core Principles

### I. GitHub Is the Sole State Store — the Issue Is the Spec

- A GitHub issue MUST be treated as the complete, self-contained specification of a unit of work — not a pointer to context that lives elsewhere (a chat transcript, local notes, a session's memory).
- A session MUST hold no authoritative state of its own: it reads an issue's GitHub state, advances the work, and writes the result back to GitHub before finishing.
- The durable state of a work item MUST live only in GitHub primitives: the issue body, its labels, its comments, its branch, its PR, and native sub-issue links.
- Label and lifecycle vocabulary MUST be validated against the live repository before use; an agent MUST NOT create a new label unilaterally — surface the gap and ask a human instead.
- Deferred work MUST be captured as a draft issue (`readiness:draft`), never as an in-chat "we'll do it later" or a local TODO.

**Rationale:** Sessions are stateless workers — a session's chat history and local scratch state do not survive to the next session and are invisible to a collaborator's agent. If a work item's authoritative state could live anywhere else, the workflow would break the moment a session ends or a different agent takes over. Any session must be able to resume any issue from its GitHub state alone.

**Traces to:** ADR-0001 (#9); `plugin/contracts/labels.md`.

### II. Issue-Only Agentic Execution

- The agentic executor MUST run only on an existing GitHub issue; a raw one-line description MUST first become an issue through a human-authoring entrypoint before any autonomous execution begins.
- Human/authoring entrypoints (drafting issues, ADRs, epics) and agentic/execution entrypoints MUST remain distinct — the same run MUST NOT both invent a spec and autonomously build against it.
- The executor MUST refuse a `type:epic` issue outright — an epic is a container, not an executable unit, and MUST be decomposed into child issues first.

**Rationale:** Turning a vague ask into a committed spec is the highest-risk judgment in the whole workflow. Concentrating it inside the same unattended pass that also builds the change removes the one human checkpoint that catches a wrong premise before code gets written.

**Traces to:** ADR-0002 (#10).

### III. The Definition-of-Ready Autonomy Gate

- Before starting unattended work, the executor MUST run the Definition-of-Ready gate keyed to **reversibility × blast-radius** — never to the model's own stated or apparent confidence.
- A `RED` (one-way-door) classification MUST require every readiness dimension (D1–D4) to PASS before autonomous work proceeds; the exact grading table is the single source of truth in `plugin/contracts/dor-rubric.md` and is intentionally not restated here, to avoid the two drifting out of sync.
- A NOT-READY verdict MUST be emitted as the specific failing dimensions — targeted questions or explore-directives — never as a single opaque score, and MUST relabel the issue `readiness:needs-refinement` (or `status:needs-decision` if the block is mid-flight) rather than proceed on a guess.
- Missing information the codebase itself can answer (epistemic) MUST be resolved by the agent exploring; missing information only a human's intent can supply (aleatoric) MUST be asked, never guessed.
- When proceeding under logged assumptions, the executor SHOULD prefer the most reversible implementation path available.

**Rationale:** Model confidence is miscalibrated and inflates as context grows; grading against the cost of being wrong, not the model's certainty, is what keeps autonomy safe on the steps that can't be undone.

**Traces to:** ADR-0004 (#23); `plugin/contracts/dor-rubric.md`.

### IV. The Human Boundary: Author, Decide, Merge

- A human MUST own three — and only these three — points in the lifecycle: authoring/refining an issue, resolving an escalated (`status:needs-decision`) question, and merging the final PR.
- Everything between an issue reaching `readiness:ready` and a PR reaching Review MUST NOT require a human in the loop; a human may supervise or intervene at will, but the design target is zero-touch.
- A mid-flight block MUST be escalated asynchronously (label + structured comment) rather than pausing for a synchronous human wait; a later session MUST be able to resume from that state alone.
- A component MUST NOT merge a PR autonomously, regardless of how green its checks are.

**Rationale:** The boundary is what makes "fire-and-forget" both safe and honest — humans stay exactly at the two judgment calls that matter (what to build, whether to ship it) and at the escape hatch for anything the gate can't resolve alone, without being pulled into the mechanical middle.

**Traces to:** ADR-0002 (#10); ADR-0003 (#15); `plugin/contracts/lifecycle.md`.

### V. Verify Before Merge: the Smoke Gate and Blind Review

- A PR MUST NOT be opened without an executed test and a real smoke of the changed path, captured as a transcript — including the shadow-trick for paid or destructive paths that cannot be safely run for real.
- Every PR MUST then receive a blind review — an agent with fresh context, isolated in its own clone, not a fork and not the shared working tree — before the PR goes to the human for the merge decision (Principle IV); how deeply the human additionally reviews is their call, not a mandated ceremony.
- The blind reviewer MUST actually execute the issue's test plan and observe the result, not infer completion from the diff alone.

**Rationale:** A confident-sounding transcript is not the same as a change that works, and an agent reviewing its own work in its own context tends to confirm what it already believes it did. A real smoke before the PR opens, then an independently-run re-verification after, catches what either check alone would miss.

**Traces to:** ADR-0003 (#15); `plugin/contracts/lifecycle.md`.

### VI. Enforcement Honesty

- A component MUST NOT describe a gate, a label rule, or an ownership boundary as "enforced" unless a hook or other mechanical control actually blocks the violating action.
- A gate that only an agent is *told* to run MUST be described as "prompt-honored" — a forcing function, not a guarantee.
- Any future hard enforcement (hooks, CI checks) MUST update the affected principle's description in the same change that ships it — the doc's claimed enforcement level MUST always match reality.

**Rationale:** A workflow that calls a best-effort convention "enforced" trains everyone — human and agent — to trust a safety net that isn't there. Naming the real enforcement level precisely is what lets the shadow-trick, draft-PR defaults, and the human merge correctly carry the weight the prompts alone cannot.

**Traces to:** ADR-0003 (#15); ADR-0004 (#23); `plugin/contracts/lifecycle.md`; `plugin/contracts/dor-rubric.md`; `plugin/contracts/labels.md`.

### VII. Bot Identity for Organizational Writes

- Every GitHub write that represents the workflow's own action (issues, PRs, comments, commits, pushes) MUST be attributed to the configured machine account, never to a contributor's personal account.
- A write path that cannot assume the bot identity MUST fail fast — it MUST NOT silently fall back to a personal account.
- Reading and reviewing as a human MUST use the human's own identity; this principle governs the workflow's own writes, not a human's review comments.

**Rationale:** Attribution is how a multi-session, multi-agent workflow stays auditable — every autonomous write must be traceable to "the workflow acted here," distinct from a person's own judgment, especially once several sessions and collaborators' agents write to the same repo concurrently.

**Traces to:** **Newly ratified by this constitution.** Previously documented only as an operating convention in `README.md` ("Bot identity & setup") and `CLAUDE.md` ("GitHub writes run as the bot"), not as an accepted ADR; this ratification is the decision record.

## Consumption Contract

This file states its own intended consumption; wiring the steps below to actually load it is separate follow-up work (see `CLAUDE.md`'s backlog), not something this document does by itself — consistent with Principle VI, a statement of intent is not a claim of enforcement.

**Steps that SHOULD load this file as context:**

- `/pickup`, at issue intake, alongside the Definition-of-Ready gate (Principle III) — before any autonomous work begins.
- The `a2a-workflow` engine and its phases (understand → clarify → issue → branch → implement → verify → PR → blind-review) — as ambient context for the duration of a run.
- `review-pr` and the blind-review step — as the enforcement point below.
- The authoring entrypoints (`create-issue`, `create-adr`, `refine-issue`) — so a drafted issue doesn't request something a Core Principle forbids.

**Constitution Authority rule** (mirrors spec-kit's `/analyze`-phase rule): within any review — blind or human — a diff or a decision that conflicts with a Core Principle's MUST is automatically the highest-severity finding: a request-changes, fixed at the source (the code, the issue, or the PR), never diluted, reinterpreted, or silently waived by the reviewing agent. A conflict with a SHOULD is a normal-severity finding, argued on its merits.

## Governance

**Authority.** This constitution supersedes ad-hoc practice for anything it states as a MUST. Where a skill's, agent's, or command's own instructions conflict with a Core Principle, the principle wins — the component's instructions are what needs fixing, not the principle.

**Amendment procedure.** An amendment MUST:

1. Be proposed as a normal PR against this file, off its own branch, linked to the ADR that motivates it (if any) or explicitly marked as newly ratified by the amendment itself.
2. Prepend a short **Sync Impact Report** (an HTML comment at the top of the diff) naming the version delta and which of `GOAL.md`, `plugin/contracts/*.md`, and any dependent skill/agent/command prose should be re-checked for consistency.
3. Pass the same blind-review-plus-human-merge gate as any other change (Principle V) — no self-merge, no exception for governance changes.

**Versioning policy (SemVer).**

- **MAJOR** — a principle is removed, or redefined in a way that reverses its prior MUST.
- **MINOR** — a new principle is ratified, or an existing principle's guidance is materially expanded.
- **PATCH** — wording, clarification, or rationale fixes that don't change what's required.

**Compliance review.** A PR is expected to be checked against this constitution at the review step (see Consumption Contract). Today that check is **prompt-honored** — the reviewer is told to do it — not hook-enforced (Principle VI); this section will be updated the moment that changes.

**Volatility contract.** This file changes only through the amendment procedure above, with a version bump — never as a drive-by edit in an unrelated PR. Contrast `GOAL.md`, which may be updated through a normal documentation PR.

---

**Version** 1.0.0 | **Ratified** 2026-07-03 | **Last Amended** 2026-07-03
