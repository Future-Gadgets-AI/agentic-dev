# P1 — Adversarial Requirement Expansion (6 lenses)

Before drafting the issue, interrogate the request through six lenses. **An empty answer is a failure, not a pass** — if a lens yields nothing, say *why* it doesn't apply; don't skip it. The output becomes `## Scope & interpretation` in the issue, so the human reviews the *reasoning*, not just the conclusion.

The reflex this defends against: a request names a single thing that is secretly a **set** ("Chinese" = simplified + traditional + pinyin), and the naive implementation silently covers one member and calls it done.

| Lens | The question | Example catch |
|---|---|---|
| **PLURALITY** | Does this term hide a set? | "Chinese" → simplified + traditional. "a date" → with / without timezone. |
| **VARIANT / LOCALE** | Script, dialect, regional, encoding variants? | half-width vs full-width kana; en-US vs en-GB; CRLF vs LF. |
| **SYMMETRY** | The codebase does X for A — what's the A→B map, and what has no B-equivalent yet? | there's a JA tokenizer + JA dict loader → a new language needs both, plus the reading-annotation path. |
| **INVERSE / EDGE** | empty / missing / off / both / zero / huge? | no subtitles found; backend unreachable; both flags set at once. |
| **USER STORY** | What does a real user expect that the prompt didn't say? | "add a backend" → they expect it to *not* silently cost money. |
| **PRIOR ART** | How did the closest existing feature solve this? `grep` it first. | copy the existing backend's flag + error-handling pattern; don't reinvent. |

## Output shape (goes in the issue)

```
## Scope & interpretation
- In scope: <the set members this change covers>
- PLURALITY / VARIANT / SYMMETRY / INVERSE / USER STORY / PRIOR ART: <one line each, or "n/a because…">
- Deliberately out of scope (SPLIT → #NN): <…>
```

The value isn't the table — it's that the human sees the *interpretation* and can correct a wrong reading before any code is written.
