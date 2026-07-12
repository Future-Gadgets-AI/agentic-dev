# Auditing and migrating pre-Fable 5 prompts

Why this exists: Anthropic's guidance states that skills and prompts developed for prior models are often **too prescriptive for Fable 5 and can degrade output quality**, and that some previously-harmless instructions now trigger refusal classifiers. Migration is mostly *removal*, verified by testing — not a rewrite for its own sake.

## The smell checklist

Run these over a repo's `.claude/`, plugin, or prompt directories. Each smell lists the grep to find it, why it now hurts, and the fix.

### 1. Reasoning-echo instructions (highest priority — refusal risk)

```bash
grep -rniE "(explain|show|describe|transcribe|walk (me |us )?through).{0,40}(reasoning|thinking|thought process|chain of thought)" --include="*.md" --include="*.py" .
grep -rniE "think step[- ]by[- ]step and (show|explain|write)" --include="*.md" .
```

Why: instructions to reproduce internal reasoning in the response can trigger the `reasoning_extraction` refusal category, causing fallbacks or dead turns. Fix: delete the instruction; if the application needs reasoning visibility, read adaptive-thinking blocks via the API, or surface progress through a send-to-user tool (integration.md). Asking the model to *justify a conclusion with evidence* is fine; asking it to *transcribe its thinking* is not.

### 2. ALL-CAPS directive walls

```bash
grep -rcE "\b(MUST|NEVER|ALWAYS|CRITICAL|IMPORTANT)\b" --include="*.md" . | grep -v ":0" | sort -t: -k2 -rn | head
```

Why: enumerated hard directives were compensation for weak instruction-following; on Fable 5 they dilute the signal and read as noise. Fix: collapse each cluster into one principle plus the reason. A file with 10+ caps directives is a rewrite candidate; 1–2 well-chosen ones are fine.

### 3. Decorative agent templates

Look for: ASCII architecture diagrams, per-capability confidence scores (`0.85`), mission quotes, persona filler, mandatory N-section output templates for human-read output.

Why: decoration dilutes instructions and anchors the model to ritual over judgment. Fix: reduce the body to identity (2 lines), capabilities, boundaries with reasons, output contract. Keep hard templates only where a machine parses the output.

### 4. Stale model references

```bash
grep -rnE "claude-(2|3|instant)[.0-9-]*|claude-3-[57]-(sonnet|haiku|opus)|claude-(sonnet|opus|haiku)-4-[0-9]{8}" --include="*.md" --include="*.py" --include="*.json" --include="*.yaml" .
```

Why: hardcoded old IDs pin new work to old behavior, or break outright. Fix: check every hit against the current model table in the **claude-api skill** (it's date-stamped and maintained there — don't duplicate the list here). While you're in the frontmatter: add deliberate `model`/`effort` choices per the tiering rule.

### 5. Obsolete workaround scaffolding

Patterns that compensated for old-model weaknesses; each is now dead weight *by default* — test removal:

- "Do not stop until finished" / repeated anti-laziness exhortations → replace with one checkpoint snippet if early stopping actually occurs.
- Forced "think step by step" in the response body → adaptive thinking already reasons; forcing it into the response risks smell #1.
- Prescriptive step-by-step procedures where the model can navigate ambiguity → state the goal, constraints, and verification instead.
- Retry/parsing rituals baked into prompts for structured output → move to code-level validation (integration.md).
- Verbosity padding ("be extremely detailed and comprehensive") → usually produces bloat now; state who reads the output and what they need.

### 6. Prefilled-response reliance

If a pipeline uses assistant-message prefills to force formats, note that migration guidance covers moving off prefills (see the cross-model best-practices page, "Migrating away from prefilled responses"). Structured output via tool schemas is the durable replacement.

## Rewrite protocol

1. **Snapshot first.** Copy the artifact aside (or rely on git) so before/after is diffable.
2. **Delete before adding.** Strip smells #1–#5. Don't compensate with new instructions yet.
3. **Preserve the function.** The agent/skill's *purpose, inputs, and output contract* must survive. If the original encoded real domain knowledge (decision matrices, gotchas with issue numbers, checklists that map to compliance), keep that content — it's knowledge, not decoration.
4. **Test the stripped version** on a real task before deciding it needs anything back. Anthropic's guidance: default performance is often better; add back only what a failure demonstrates is needed. For a measured comparison, run the improve-skill loop (with-artifact vs without).
5. **One coherent commit** per artifact, noting what was removed and why — future readers will otherwise re-add the ritual.

## Prioritizing an estate

When many artifacts need auditing, order by blast radius:

1. **Public/shared artifacts** (published plugins, marketplace skills) — other people inherit their smells.
2. **High-frequency personal artifacts** — the ones that trigger daily compound the cost.
3. **Refusal-risk hits anywhere** (smell #1) — fix immediately regardless of frequency; they can dead-end a run.
4. Coursework, archives, and staging material last — or leave them as historical record.
