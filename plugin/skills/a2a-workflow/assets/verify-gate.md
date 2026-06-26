# G2 — Verify / Smoke Gate (the whole game)

The one non-negotiable gate. You cannot reach the PR until **all three** are done and **captured as a transcript**:

1. **Tests ran.** DETECT the runner — don't assume `pytest`. Look at the repo: a `tests/` script run via `uv run python tests/test_x.py`? a `Makefile` target? `npm test`? `cargo test`? Run what the repo actually uses.
2. **A real smoke of the changed path ran** with real or fixture input — the actual command, end to end, not a mental model of it.
3. **The specific behavior was demonstrated.** Fix → the original repro now behaves correctly. Feature → the new capability produced its output at least once.

## The shadow trick — smoke a paid / destructive path with ZERO spend

When the changed path would spend money, call a paid API, or mutate production, you still must prove the guard works — **without paying.** Shadow the real binary with a no-op stub on `PATH`:

```bash
mkdir -p /tmp/stub
printf '#!/bin/sh\necho "[stub: NOT spending]" >&2\nexit 7\n' > /tmp/stub/<binary>
chmod +x /tmp/stub/<binary>
PATH="/tmp/stub:$PATH" <the command that would hit the paid path>
```

Assert the **guard / disclaimer printed BEFORE the stub was reached** — proving the protection precedes any spend. (How the `--backend` fix was proven: bare run → clean "ollama unreachable" error, claude never reached; `--backend claude` → token-spend warning printed *first*, then the stub ran — not real claude. Zero tokens.)

When the fix makes the default path *stop* instead of spend, it's even simpler: run with no flag and assert it exits with guidance and never calls the paid binary.

## If it's genuinely unrunnable

Secrets you don't have, a GPU you lack, a live external service — then:
- Open the **PR as a draft**.
- Add `## Verification: BLOCKED — <reason>`, naming exactly which acceptance criterion couldn't run and why.
- Verify what you *can* by inspection (is the unchanged path genuinely unchanged?) and say so.
- **Never report it green.** The P7 blind-review and the other agent's `review-pr` re-run independently — they will catch a faked green.

## The required artifact

The P8 report carries a literal **`Smoke evidence:`** block — the transcript of the run, with exit codes. No transcript ⇒ not done.
