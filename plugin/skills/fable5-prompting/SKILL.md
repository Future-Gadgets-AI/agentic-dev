---
name: fable5-prompting
description: |-
  Use for any work on the words that steer a Claude model — read BEFORE writing or fixing them, because Fable 5 / Claude 5 changed prompting rules and habits learned on older models now backfire. Covers authoring, review, and repair of: system prompts for apps and long-running/overnight autonomous pipelines calling Claude via SDK or CLI; agent and subagent markdown (plugins included); skills and slash commands; CLAUDE.md and rules files; memory-system prompts; effort-level choice and subagent model tiering (haiku/sonnet fan-out vs Fable synthesis).
  Fixes prompt-caused symptoms: stop_reason refusal after wording like "explain your reasoning"; runs stalling mid-pipeline to ask permission; output bloated or degraded after a model upgrade; obsolete MUST/NEVER rule walls; PT-BR deliverables vs English code. Triggers on: "system prompt", "prompt de sistema", "agent markdown", "subagent", "agente", "CLAUDE.md", "refusal", "escrever prompt", "effort", upgrade regressions — even when Fable 5 isn't named.
  NOT for: API mechanics — pricing, model IDs, params, streaming, caching, SDK surfaces (claude-api skill); structural agent-file validation (agent-quality skill); skill A/B evals (improve-skill skill); prompts for non-Claude models, except the small-model sizing pattern in references/integration.md.
---

# Prompting Claude Fable 5

**Source of truth:** https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5 (snapshot 2026-07-02). Cross-model techniques live in [prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) — XML structure, examples, roles, long-context placement, tool use; link there, don't restate it. If observed behavior contradicts this file, or the flagship family has moved past Fable 5, re-fetch the live page before trusting this snapshot.

## What actually changed

Fable 5 follows brief instructions reliably, sustains multi-hour autonomous runs, dispatches parallel subagents well, and is strongest on problems *harder* than what you'd assign prior models. Two consequences drive everything below:

1. **Steering shifts from control to intent.** One short instruction with the reason behind it outperforms an enumerated list of cases. Over-specification now costs quality, not just tokens — Anthropic's own guidance is that skills written for prior models are often too prescriptive for Fable 5 and can degrade output.
2. **The unit of work got bigger.** Effective prompts describe goals, boundaries, and verification — not steps. Individual turns run longer by default; plan timeouts and progress surfacing accordingly.

## Core rules for any prompt or artifact

1. **Brief instruction + why, not enumerated cases.** If you're listing every behavior variant or reaching for ALL-CAPS MUST/NEVER walls, collapse them into one principle plus the reason it matters. Fable 5 generalizes from the why.
2. **Give the reason, not only the request.** `I'm working on [larger task] for [who it's for]. They need [what the output enables]. With that in mind: [request].` Stated intent lets the model connect the task to relevant context instead of inferring it.
3. **Never instruct the model to echo its reasoning in the response.** "Explain your thinking step by step", "show your reasoning", "transcribe your thought process" can trigger the `reasoning_extraction` refusal category on Fable 5 and cause elevated fallbacks. If you need reasoning visibility, read structured thinking blocks from adaptive thinking; surface progress via a send-to-user tool (references/integration.md).
4. **Prefer deleting instructions over adding them.** Capability jumps turn old guardrails into dead weight or active harm. When output disappoints, first try removing prescription; only then add the minimal counter-instruction.
5. **Effort is the primary quality/latency/cost lever.** Default `high`; `xhigh` for capability-sensitive work; `medium`/`low` for routine tasks (still strong — often above prior models' best). Parameter mechanics belong to the claude-api skill.
6. **Separate assessment from action.** When a request describes a problem or asks a question, the deliverable is the assessment. Bake this into artifacts: report findings and stop; apply fixes only when asked.

## Snippet library (Anthropic-tested; copy, then trim to fit)

The three most-reached-for, inline:

**Anti-overplanning** — for ambiguous tasks where the model surveys instead of acting:

> When you have enough information to act, act. Do not re-derive facts already established in the conversation, re-litigate a decision the user has already made, or narrate options you will not pursue in user-facing messages. If you are weighing a choice, give a recommendation, not an exhaustive survey.

**Scope discipline** — for high-effort tidying/refactor creep:

> Don't add features, refactor, or introduce abstractions beyond what the task requires. Do the simplest thing that works well. Don't add error handling, fallbacks, or validation for scenarios that cannot happen. Trust internal code and framework guarantees; only validate at system boundaries (user input, external APIs). Don't use feature flags or backwards-compatibility shims when you can just change the code.

**Checkpoint** — defines when pausing is legitimate, replacing case-by-case rules:

> Pause for the user only when the work genuinely requires them: a destructive or irreversible action, a real scope change, or input that only they can provide. If you hit one of these, ask and end the turn, rather than ending on a promise.

The rest, indexed by the failure they fix:

| Snippet | Fixes | Full text in |
|---|---|---|
| Progress audit | fabricated status reports in long runs | references/integration.md |
| Autonomous-pipeline reminder | turn ending on intent statements or permission-asking | references/integration.md |
| Context reassurance | model trimming its work over token-countdown anxiety | references/integration.md |
| Brevity / lead-with-outcome | rambling or fragment-compressed summaries | references/authoring.md |
| Communication addendum | arrow-chain shorthand in user-facing text | references/authoring.md |
| Delegation | under-use of parallel subagents | references/authoring.md |
| Memory rules + bootstrap | re-discovering lessons every session | references/authoring.md |
| send_to_user tool + elicitation | delivering verbatim content mid-run | references/integration.md |
| Verification interval | unverified output on long builds | references/integration.md |

## Routing

| Task at hand | Read |
|---|---|
| Write or review a skill, agent, CLAUDE.md, subagent prompt | references/authoring.md |
| Audit/migrate pre-Fable artifacts; quality regressed after upgrade | references/migration-audit.md |
| System prompts for SDK/CLI apps; structured output; long runs; refusals | references/integration.md |
| Model IDs, pricing, params, caching, thinking API | claude-api skill — defer, don't duplicate |
| Validate agent file structure | agent-quality skill |
| A/B test a skill change | improve-skill skill |

## Safety layer — design around it, don't fight it

Fable 5 runs classifiers targeting offensive-cyber techniques, biology/life-science methods, and extraction of its summarized thinking. Benign security or life-science work can still trip them (`stop_reason: "refusal"`). Authoring consequences: never bake reasoning-echo instructions into artifacts; for products, configure fallback to Claude Opus 4.8; for agents that touch security-adjacent code (dependency audits, authz reviews), state the fallback plan in the integration prompt (references/integration.md).

## House defaults (apply when authoring for this user)

- **Model tiering for subagents:** mechanical fan-out (fetch, extract, scan, verify) runs on Haiku/Sonnet; Fable only for synthesis, judgment, and hard planning. Don't burn flagship tokens on work a smaller model does equally well.
- **Structured output:** Pydantic v2 models, validated at the boundary; on parse failure retry once with the validation error appended rather than looping.
- **Two-tier prompt sizing:** verbose prompts with examples for capable models; stripped lean variants for small local models, which over-fit to examples.
- **Paid-call gating:** anything shelling out to `claude -p` gets an explicit opt-in flag and a printed spend warning; never silently fall back from a local model to a paid one.
- **Bilingual split:** deliverables for Brazilian audiences in PT-BR; instructions, code, and scaffolding in English.
- **Judging:** for evals, prefer a cross-model (non-Claude) judge for adversarial second opinions, avoiding same-family blind spots.
