# contracts/

Canonical, machine-loadable **rules and data** the workflow honors — the single source of truth that multiple components must agree on. Distinct from:

- **`kb`-style domain knowledge** (reference an agent *reasons with*, e.g. "how to model SCD2") — we have none yet; if we add it, it lives elsewhere, not here.
- **`ARCHITECTURE.md`** (the prose design-of-record — "how it fits together now") — `contracts/` holds the *definitions* that doc describes.
- **ADRs** (the decision history — "why we chose it") — `contracts/` is the *current* canonical state, not the rationale.

Components reference these via `${CLAUDE_PLUGIN_ROOT}/contracts/…`.

## Files
| File | Defines |
|------|---------|
| `lifecycle.md` | the issue lifecycle state machine (columns, owners, procedures, transitions) |
| `dor-rubric.md` | the Definition-of-Ready autonomy-gate rubric |
| `labels.md` | the GitHub label scheme (type / priority / readiness / status / phase) |

## Enforcement honesty
**Every file states whether it is prompt-honored or hook-enforced.** Today they are all *prompt-honored forcing functions* — components are *told* to follow them; nothing deterministically blocks a violation. That is better than nothing, but it is **not a guarantee**. Real enforcement (hooks at the harness layer, especially for irreversible steps) is tracked as a backlog issue. Do **not** describe these as "enforced" until a hook makes them so — that overstatement is a known anti-pattern (agentspec's own contract files concede they are "best-effort") and we are explicitly avoiding it.
