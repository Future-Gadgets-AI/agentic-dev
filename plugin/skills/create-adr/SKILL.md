---
name: create-adr
description: Drafts an Architecture Decision Record (ADR) from a standard template, with a worthiness gate, the decision/context/alternatives/consequences structure, and the status lifecycle. Use when the user asks to "create an ADR", "new ADR", "draft ADR-XXX", "document an architecture decision", or to formalize an architecturally significant technical decision. Publishing the ADR to GitHub afterward is the publish-issue skill.
---

# Create ADR

Drafts an ADR from `assets/adr-template.md`.

An ADR records **one durable architecture decision**, so the two of you don't re-litigate it later. The value is in capturing the **why** and the **trade-offs** — not just the final choice. ADRs are part of the **memory ledger** (see `git-collaboration`): they are read by the **other person's agent**, which has none of your session context, so they must be fully self-contained.

## First — is it worth an ADR?

An ADR is for a decision that is **architecturally significant and expensive to reverse** — one a future contributor will need to understand the *why* of. **Don't** draft an ADR for: anything that isn't an architecture decision; a small / low-risk / easily-reversible choice; something temporary (POC, workaround, experiment); or something already covered by an existing pattern/doc. Inflating the log with trivial decisions is an anti-pattern — it drowns out the signal of the ones that matter. When in doubt, it's probably a normal issue/PR, not an ADR.

## Process

### 1. Gather the essentials (ask the user for whatever's missing)
- **Decision** — what it is, in one sentence, in **active, present voice** ("The system adopts…", "We will…") — it reads as a commitment, not an open debate.
- **Number** — **not authoritative locally.** Canonical numbering lives in the `type:adr` issues on GitHub; local file numbers collide. In the draft, name by slug and leave the number as `ADR-XXX` / to be confirmed — the real number is assigned when published as an issue. Never treat a local file number as truth.
- **Context / Problem** — the current state and what exactly needs to be decided (the pain).
- **Alternatives** considered + **why each one was passed over** (the "why not", not just the "why yes") — that's what proves the decision was weighed.
- **Consequences** — trade-offs on **both sides**: what gets easier (positive) **and** what gets harder / riskier (negative). A consequence with only upside is a sales pitch, not a decision record.

### 2. Fill in the template
Copy `assets/adr-template.md`, fill in the sections, and save to **`notes/adr/adr-<slug>.md`** — `slug` is a verb-phrase in lowercase-with-hyphens (`enforce-input-validation`, not `team-thing-v2`). Create the directory first if it doesn't exist: `mkdir -p notes/adr`. Draft only — the push to GitHub is a separate flow.

Content rules:
- **Self-contained — zero leaked context.** The ADR goes to GitHub and must be readable, on its own, by the **other person's agent**. Do a **translation/cleaning pass** that removes: local file paths, private session state ("as we discussed"), internal nicknames/codenames, references to your own numbered notes, and process/tooling meta. At most, reference **other GitHub ADRs** — never personal workspace files. Translate any internal shorthand into self-contained language.
- **Formal / impersonal tone.** The ADR becomes a public issue — it's a shared deliverable.
- **Concrete > vague.** Diagrams (ASCII / Mermaid) when the layout matters.
- **Status & lifecycle.** `Proposed` → `Accepted` (the other dev validates) **or** `Rejected` (and it stays on record — avoids re-litigating the same idea later). Terminal states: `Superseded` / `Deprecated`.
- **An accepted decision is not rewritten by erasing the reasoning.** When it changes: raise a **new ADR that supersedes** the old one, cross-linked, and mark the old one `Superseded by ADR-YYY`. Since ADRs become **GitHub issues** (mutable), amending is also fine — but with a **dated note**, never silently. The history of the *why* must survive.

### 3. Publish as an issue on GitHub
The ADR is published as a `type:adr` issue through the **`publish-issue`** skill (it validates labels against the repo, applies them, and runs the dedup / self-containment guardrails). The label scheme lives in `git-collaboration`. Before publishing, run the self-containment translation/cleaning pass (§2).
