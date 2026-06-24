# G1 — Clarification Gate (STOP vs ASSUME vs SPLIT)

Run after expansion + ripple (P1), before drafting the issue. For every open question the request leaves unanswered, classify it by **reversibility × blast-radius — NOT by how confident the model feels.** Confidence is the wrong axis: a confident-but-wrong assumption on an expensive-to-reverse choice is the expensive mistake.

## The three buckets

- **BLOCKING** — expensive to reverse AND no defensible default exists. The decision genuinely belongs to the human.
  - *Interactive:* ask via `AskUserQuestion` (concise, with a recommended option first).
  - *Headless:* record under `## Open decisions (needs human)` in the issue/PR, apply the `needs-decision` label, @-mention the decider, proceed on the **best documented assumption**, and open the **PR as draft**. Never block the whole run on it.
- **ASSUME** — a defensible default exists, OR the choice is cheap + local to reverse. Proceed; **log it** under `## Assumptions (review these)` so the human can veto it at merge in seconds.
- **SPLIT** — a *separate* capability rode in on the request. Open a linked follow-up issue, proceed with the core. Don't let scope-creep stall the main change.

## The test

> Would getting this wrong cost a rewrite / a migration / a public retraction (**BLOCKING**), or a one-line edit on a follow-up commit (**ASSUME**)?

## Worked example — "add Mandarin Chinese" to a JA/EN tool

| Question | Class | Why |
|---|---|---|
| Simplified **and** traditional? | BLOCKING | Two scripts; choosing one wrong means re-segmenting everything. No safe default. |
| Romanization (pinyin) shown? | BLOCKING | User-facing pedagogy decision; no defensible default. |
| Which segmenter (jieba vs …)? | ASSUME | Internal, swappable later; jieba is the sane default — log it. |
| Also fetch Chinese subtitles? | SPLIT | A separate capability — its own issue. |

## Calibration

A healthy run fires **0–1** BLOCKING questions. **>2 means the request is underspecified** — say so plainly to the user instead of firing a barrage. A wall of questions is a smell that the task isn't ready, not thoroughness.
