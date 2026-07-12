# Integration prompting — SDK and CLI applications

For system prompts and harness design in applications that call Claude Fable 5 through the Anthropic SDK or by shelling out to the `claude` CLI. API parameter mechanics (adaptive thinking, effort values, streaming, caching, model IDs, pricing) belong to the **claude-api skill** — this file covers the prompting and reliability layer on top.

## Plan for longer turns

Hard tasks at higher effort run for many minutes per request; autonomous runs extend for hours. Before shipping: raise client timeouts, stream, show progress in the UX, and prefer checking on runs asynchronously (scheduled jobs, polling a run record) over blocking a request thread. If the task is ambiguous, the anti-overplanning snippet (SKILL.md) keeps the model from spending that time surveying.

## Effort selection

Default `high`. Use `xhigh` only where capability is the bottleneck (hardest synthesis, judgment). Drop to `medium`/`low` for routine or interactive work — lower-effort Fable 5 still commonly beats prior models' maximum. Reduce effort when a task completes correctly but takes longer than it should. Exact parameter shapes: claude-api skill.

## The long-run reliability trio

Three failure modes dominate autonomous pipelines; each has an Anthropic-tested counter-snippet. Put them in the system prompt of any unattended run:

**1. Fabricated progress → ground claims in tool results.** In Anthropic's testing this nearly eliminated fabricated status reports:

> Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for; if something is not yet verified, say so explicitly. Report outcomes faithfully: if tests fail, say so with the output; if a step was skipped, say that; when something is done and verified, state it plainly without hedging.

**2. Early stopping / permission-asking → autonomous-pipeline reminder:**

> You are operating autonomously. The user is not watching in real time and cannot answer questions mid-task, so asking "Want me to…?" or "Shall I…?" will block the work. For reversible actions that follow from the original request, proceed without asking. Before ending your turn, check your last paragraph. If it is a plan, an analysis, a question, a list of next steps, or a promise about work you have not done ("I'll…", "let me know when…"), do that work now with tool calls. End your turn only when the task is complete or you are blocked on input only the user can provide.

Pair with the checkpoint snippet (SKILL.md) so "blocked" has a definition.

**3. Context anxiety → don't show countdowns; reassure if you must:**

> You have ample context remaining. Do not stop, summarize, or suggest a new session on account of context limits. Continue the work.

Root cause is usually the harness surfacing a remaining-token countdown — hide it from the model where possible.

## Verification cadence for long builds

Separate fresh-context verifiers outperform self-critique. For long-running construction tasks, make it explicit:

> Establish a method for checking your own work at an interval of [X] as you build. Run this every [X interval], verifying your work with subagents against the specification.

For evals and judged comparisons, prefer a cross-model (non-Claude) judge as the adversarial second opinion — same-family judges share blind spots with the producer.

## send_to_user: verbatim delivery mid-run

Long async agents need a way to put content in front of the user *exactly as written* without ending the turn — partial deliverables, specific numbers, direct answers. Tool inputs are never summarized, so route such content through a client-side tool:

```json
{
  "name": "send_to_user",
  "description": "Display a message directly to the user. Use this for progress updates, partial results, or content the user must see exactly as written before the task finishes.",
  "input_schema": {
    "type": "object",
    "properties": {
      "message": {
        "type": "string",
        "description": "The content to display to the user."
      }
    },
    "required": ["message"]
  }
}
```

Render the input directly in the UI; return a simple acknowledgement. Defining the tool is not enough — without system-prompt elicitation the model rarely calls it:

> Between tool calls, when you have content the user must read verbatim (a partial deliverable, a direct answer to their question), call the send_to_user tool with that content. Use send_to_user only for user-facing content, not for narration or reasoning.

Skip the tool for agents that only narrate routine progress — over-calling it for narration defeats the purpose.

## Structured output

- Define the contract as a **Pydantic v2 model**; validate at the boundary (the API response), not throughout internal code.
- On validation failure, **retry once with the validation error appended** to the request; if it fails again, surface the error — endless retry loops hide real contract problems.
- Strip markdown fences defensively before parsing when not using tool-schema output; better, use tool/structured-output modes so there's nothing to strip.
- **Two-tier prompt sizing:** capable models get the verbose prompt with examples; small local models get a lean variant with examples removed — small models over-fit to examples and parrot them. Keep both variants in code as named constants so the tiers stay visibly in sync.

## Refusals and fallback

Fable 5 returns `stop_reason: "refusal"` from safety classifiers (offensive-cyber, biology/life-science, reasoning extraction). Benign work in adjacent territory — dependency audits, authz reviews, bio-adjacent data — can trip them. Production pipelines should configure server-side or client-side **fallback to Claude Opus 4.8** rather than treating refusal as fatal. Also audit your own system prompts for reasoning-echo instructions (migration-audit.md smell #1) — they're a self-inflicted refusal source.

## Calling via the claude CLI

When integrating through `claude -p` instead of the SDK (fine for tools that already live next to Claude Code):

- **Gate the spend.** Paid backends are explicit opt-in flags with a printed cost warning; never silently fall back from a local model to a paid call.
- **Test the gate for free:** stub a fake `claude` binary on PATH in tests to prove the spend-gate and warning fire without real spend.
- The system-prompt guidance above applies unchanged — pass it with the prompt; don't assume the CLI's own defaults cover your pipeline's failure modes.
