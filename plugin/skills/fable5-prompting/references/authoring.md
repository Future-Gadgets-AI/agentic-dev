# Authoring Claude Code artifacts for Fable 5

Applies to skills, agent definitions, CLAUDE.md files, slash commands, and subagent prompts. The through-line: Fable 5 rewards intent and punishes over-specification. Write less, explain why, and let the model navigate.

## Skills

**Description = the entire triggering mechanism.** Name what the skill does AND the concrete contexts that should summon it — phrasings, artifacts, symptoms ("output got worse after upgrade"). Models under-trigger skills, so make descriptions assertive: "use whenever X, even if the user doesn't say Y." Also carve the negative space: name the adjacent skills that own neighboring territory so two skills don't fight over one prompt.

**Body: goals and judgment, not scripts.** State the outcome, the constraints, and the reasoning behind non-obvious rules. If you catch yourself writing ALWAYS/NEVER in caps or a rigid seven-section output template, reframe: what failure is that rule preventing? Say that instead. Reserve hard templates for outputs a machine parses.

**Progressive disclosure.** Keep SKILL.md under ~500 lines; split domain depth into `references/` with a routing table saying when to read each. Claude reads only what the task needs.

**Expect the skill to be edited by the model.** Fable 5 updates skills on the fly based on what it learns mid-task. Write so that partial application still helps — self-contained sections, no long dependency chains between rules.

## Agent definitions

**Frontmatter carries the routing and the economics.**
- `description`: same rules as skills — proactive trigger contexts plus one or two example exchanges. Pick one example format and keep it consistent across your fleet.
- `model` / `effort`: choose deliberately per the tiering rule — Haiku/Sonnet for mechanical work (fetch, extract, scan, verify, format), the flagship only where synthesis or judgment is the bottleneck. **Record the rationale in the file**, one line next to the choice (e.g., `model: sonnet` + "routine synthesis, not flagship judgment"): an unexplained tier choice reads as arbitrary and gets churned by the next editor. An agent definition without a model choice silently inherits the most expensive default.
- `tools`: allowlist the minimum the agent needs — a reviewer gets read/search tools, not Write/Edit; a drafting agent that never runs code doesn't get Bash. Least privilege prevents unrequested side effects and makes the agent's contract legible at a glance.

**Body: identity in two lines, then capabilities, boundaries, output contract.** What worked for older models now reads as decoration and dilutes instruction-following:
- ASCII "knowledge architecture" diagrams — cut.
- Numeric confidence scores per capability (0.60–0.95) — cut; the model doesn't calibrate to them.
- Mission-statement quotes and persona filler — cut.
- Per-capability boilerplate templates — collapse into one output contract.

A strong Fable 5 agent body is often 40–80 lines: who it is, what good output looks like, what it must not do and why, and how to report.

**Verification beats instruction.** Rather than 20 rules aimed at preventing bad output, add one verification step that catches it: "before returning, check each claim against a file you actually read." When the agent gathers data through a convenient API, have it cross-check once against ground truth — e.g., a PR list from `gh` against `git log` over the tag range — one cross-check catches what a page of accuracy exhortations doesn't.

## CLAUDE.md

Always in context, so every line taxes every turn. Keep it to durable, non-derivable facts: identity, hard guardrails, house conventions. Anything conditional ("when doing X...") belongs in a skill that triggers on X. If CLAUDE.md exceeds ~100 lines, something is living there that should be a skill or a memory file.

## Subagent orchestration

Fable 5 dispatches parallel subagents readily and manages long-lived ones dependably. Design for that:

- **Delegate explicitly.** Tell the orchestrator when delegation is appropriate rather than hoping it infers:

  > Delegate independent subtasks to subagents and keep working while they run. Intervene if a subagent goes off track or is missing relevant context.

- **Async over blocking.** Prefer letting the orchestrator continue while subagents run; a barrier that waits for all results is only justified when the next step genuinely needs every result at once.
- **Long-lived beats fire-and-forget** when subtasks share context: one subagent that keeps its context across related subtasks saves cache reads and avoids bottlenecking on the slowest spawn.
- **Fresh-context verifiers outperform self-critique.** For anything worth verifying, spawn a separate verifier subagent that reads the spec and the output cold, rather than asking the producer to review itself.
- **Tier the models.** Fan-out on Haiku/Sonnet; flagship for synthesis and judgment only.

## Long-running and autonomous artifacts

For scheduled tasks, loops, and overnight runs, three failure modes dominate; each has a tested counter-snippet (integration.md holds the full set with API context):

1. Fabricated progress → progress-audit snippet (ground every claim in a tool result).
2. Stopping early to ask permission → checkpoint snippet (SKILL.md) plus the autonomous-pipeline reminder.
3. Context anxiety → avoid surfacing token countdowns; add the context reassurance line.

## Communication snippets

**Brevity / lead-with-outcome** — the doc's finding is that one short instruction beats enumerating verbosity patterns:

> Lead with the outcome. Your first sentence after finishing should answer "what happened" or "what did you find": the thing the user would ask for if they said "just give me the TLDR." Supporting detail and reasoning come after. Being readable and being concise are different things, and readability matters more.
>
> The way to keep output short is to be selective about what you include (drop details that don't change what the reader would do next), not to compress the writing into fragments, abbreviations, arrow chains like A → B → fails, or jargon.

**Communication addendum** — for agents that work long stretches unwatched:

> Terse shorthand is fine between tool calls (that's you thinking out loud, and brevity there is good). Your final summary is different: it's for a reader who didn't see any of that. Write it as a re-grounding, not a continuation of your working thread: the outcome first, then the one or two things you need from them, each explained as if new. The vocabulary you built up while working is yours, not theirs; leave it behind unless you re-introduce it. When you write the summary, drop the working shorthand. Write complete sentences. Spell out terms. If you have to choose between short and clear, choose clear.

**Bilingual outputs:** when the deliverable's audience is Brazilian (reports, slides, meeting artifacts), specify PT-BR for the content and keep the instructions/scaffolding in English — stating the audience is what makes the model hold the split consistently.

## Memory systems

Fable 5 uses recorded lessons well. Give any recurring agent a place to write notes — a directory of Markdown files is enough:

> Store one lesson per file with a one-line summary at the top. Record corrections and confirmed approaches alike, including why they mattered. Don't save what the repo or chat history already records; update an existing note rather than creating a duplicate; delete notes that turn out to be wrong.

To bootstrap from existing history:

> Reflect on the previous sessions we've had together. Use subagents to identify core themes and lessons, and store them in [X]. Make sure you know to reference [X] for future use.
