# Issue templates (non-ADR)

Pick ONE type. Title format: `[TYPE] <concise title>`. The body is **self-contained and formal** — no local paths, no references to your own numbered notes, no private session state, no in-text labels. Set parents / related issues via GitHub's native sub-issue · "add parent" · Related features, **not** inline `#NN` mentions.

---

## `[FEATURE]`

## Summary
<What capability, for whom, and why now — one short paragraph.>

## Motivation
<The concrete problem or the value. What is painful or missing today.>

## Proposed approach
<High-level direction. If this needs an architecture decision, open an ADR (create-adr) and link it — don't decide architecture inside a feature issue.>

## Scope
- In scope: <…>
- Out of scope: <…>

## Acceptance criteria
- [ ] <verifiable outcome>
- [ ] <verifiable outcome>

---

## `[TASK]`

## Summary
<The concrete unit of work — one line.>

## Definition of done
- [ ] <verifiable>
- [ ] <verifiable>

## Links
<Parent (feature / epic / ADR) set via GitHub relationship. Development branch and PR linked here once they exist.>

---

## `[BUG]`

## Summary
<What is broken — one line.>

## Reproduction
1. <step>
2. <step>

## Expected vs actual
- Expected: <…>
- Actual: <…>

## Environment
<Anything needed to reproduce, stated self-containedly — OS / runtime / version / inputs. No machine-specific local paths.>

## Root cause / proposed fix
<If known; otherwise state it is under investigation.>

---

## `[SPIKE]`

## Question
<The single thing to investigate.>

## Timebox
<e.g. 1 day — a spike is bounded by design.>

## Why now
<What decision or downstream work this unblocks.>

## Deliverable
<What the spike produces: a recommendation, a decision input, a throwaway POC.>

## Done when
- [ ] <the question is answered, with evidence>

---

## `[EPIC]`

## Vision
<The large outcome this epic delivers.>

## Scope
<What is in; what is explicitly out.>

## Child issues
<Tracked via GitHub sub-issue relationships — not an inline list of `#NN`.>

## Sequence / milestones
<The rough order of the child work.>
