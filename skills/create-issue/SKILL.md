---
name: create-issue
description: Drafts the body of a well-formed, self-contained (non-ADR) issue from a per-type template — feature, task, bug, spike, or epic — following A2A best practices (readable by the other person's agent, native GitHub relationships, one topic per issue, no labels line). Use when the user wants to create, draft, write, or open an issue, or asks for a feature, task, bug, spike, or epic issue. For architecture decisions use create-adr; to publish to GitHub use publish-issue.
---

# Create Issue

Drafts the **body of a (non-ADR) issue**, well-formed, for the current repo, from a per-type template. **Authoring only** — publishing is the `publish-issue` skill; ADRs live in `create-adr`.

The value: a good issue records **one** topic in a **self-contained** way — readable by the **other person's agent**, which has none of your session context — and tied to related issues through GitHub's native features. See `git-collaboration` for the full A2A model.

## Types (pick ONE)

| Type | When to use | Title |
|---|---|---|
| `epic` | large umbrella initiative (keep 1–2 on the board, no more) | `[EPIC] …` |
| `feature` | a capability to add | `[FEATURE] …` |
| `task` | a concrete unit of work (child of a feature/epic/ADR; links branch + PR) | `[TASK] …` |
| `bug` | a defect (repro + expected/actual) | `[BUG] …` |
| `spike` | a time-boxed investigation (question + timebox + deliverable) | `[SPIKE] …` |

Label scheme (`type:` · `priority:` · `status:`): see `git-collaboration`. Validated against the repo at publish time by `publish-issue`.

## Content rules (the why)

1. **Self-contained — zero leaked context.** No local paths (`src/...`, `/Users/...`), no references to your own numbered notes (a personal "analysis #4" becomes an accidental link to real issue `#4`), no private session state ("the thing we discussed"), no internal nicknames or codenames. **Test:** would the *other person's agent*, with no shared context, understand this on its own?
2. **Native relationships, not manual mentions.** Parent/epic and related issues go through GitHub's features (sub-issues / "add parent" / Related), **not** written as "Parent: #21" in the body — a manual mention is a weak link that rots and can collide with a real issue number. The body describes the *content*; the relationship graph is GitHub metadata (applied by `publish-issue`).
3. **One topic, one issue.** Before drafting, confirm the topic isn't already covered by another issue (`publish-issue` runs the dedup check). Multiple issues for the same subject is disorganization — consolidate into one, or into a larger issue with sub-issues.
4. **No Labels line in the body.** Labels are applied directly on the issue. No `> **Labels:** …`.
5. **Formal, impersonal tone, active voice, concrete > vague.** Add a diagram (ASCII/Mermaid) when the layout matters.

## Process

1. **Pick the type** and confirm there's no duplicate on the board.
2. **Copy the type's block** from `assets/issue-templates.md` and fill it in.
3. **Self-containment pass** (rule 1) before saving.
4. **Save the draft** to `notes/issues/<type>-<slug>.md` (slug = lowercase-with-hyphens, no internal labels).
5. **Publishing** is the `publish-issue` skill (it applies labels, native relationships, and the dedup/self-containment guardrails). A draft that's **not** going to GitHub yet — e.g. one the author still wants to review before taking it on publicly — **stays in the file only**. Publishing is an explicit decision by whoever owns the issue.

If the capability needs an architecture decision, open an ADR (`create-adr`) and link it — **don't decide architecture inside a feature issue.**
