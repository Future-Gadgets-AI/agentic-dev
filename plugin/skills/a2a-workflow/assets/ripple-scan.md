# P1 — Ripple / Blast-Radius Scan

A change rarely touches one site. Find the siblings before you commit, so the PR states what it changed, what it *didn't*, and why — and nobody discovers a half-applied fix later.

## Procedure

1. **Anchor.** Identify the symbols the change centers on (the function, flag, config key, table, route).
2. **Find siblings.** `grep` for code that branches on the *same axis* — other call sites of the symbol, other places the same flag / default is read, parallel handlers for sibling cases.
3. **Classify each sibling:**
   - **In-scope** — extending the change *implies* this sibling changes too (a shared default, a second path with the same defect). Fix it in this PR.
   - **Latent / defense-in-depth** — not reached today, but a footgun for a future caller. Fix it, but describe it **honestly as defensive** — don't inflate it into a second live bug (a sharp reviewer catches the overstatement, and it costs you credibility).
   - **SPLIT** — genuinely separate. Open a follow-up issue, link it, move on.
4. **Emit `## Ripple / blast radius`** in the PR: components changed · siblings deliberately *not* changed + why · follow-up issues opened.

## Worked example — the `--backend` fix

- **Anchor:** the CLI `--backend` default + the `gloss_and_align(backend=…)` signature default.
- **Siblings found:** the function's *sole* caller passed `backend` explicitly → the signature default was **latent**, not a second live bug (so the issue described it as defense-in-depth, not "a second silent leak"). The web UI was safe *only because* it passed `--backend` explicitly → the CLI default was effectively its fallback.
- **Second-order effect:** flipping the CLI default to the safe path **also** closed the web UI's "empty knob → silent paid path" hole. Surfacing that is exactly why the ripple scan exists.
