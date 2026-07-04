---
description: Recommend which ready issue(s) to pick up next — ranked, with per-line rationale
---

# /recommend — what to pull next

Rank this repo's board into a short "pull this next" digest: the selector in front of the `/pickup` executor. Read-only — run every `gh` call as the invoking user's own auth (never source bot auth: the bot identity exists for writes, and this command makes none).

1. **Gather** — detect the repo (`gh repo view --json nameWithOwner`); fetch open issues in one read (`gh issue list --state open --limit 200 --json number,title,url,labels`); count `phase:in-progress` issues as WIP. For each `readiness:ready` issue, read its native sub-issues via GraphQL (`subIssues { nodes { number state } }`) — the count of OPEN ones is its unblocking power.
2. **Partition** — `readiness:ready` and not already in flight (`phase:in-progress` / `phase:review`) → candidates; `readiness:draft` / `readiness:needs-refinement` → "Needs refinement first"; `status:blocked` / `status:needs-decision` → "Waiting on a human". An issue never appears as a pickup candidate from the refinement or escalation groups, and an in-flight issue is WIP, not a candidate — recommending work that is already being executed invites a double pickup.
3. **Rank the candidates** — tiers, in order; no numeric scores (the stated rationale is the contract):
   - priority tier: `priority:high` > `medium` > `low` > unlabeled;
   - within a tier: higher open-dependent count first (unblocks the most work);
   - ties: the quicker, safer win first, read from the issue text (blast radius, size) — when this tier decides a position, print the reading in the rationale.
   Every line carries `#N · title · URL — <deciding tier>`, actionable as `/pickup #N`.
4. **Report** — one markdown digest: open with the WIP count (`N issue(s) in flight` — information for the caller, never a gate on recommending); then the ranked candidates; then the two non-candidate groups, each a short list or "none". An empty candidate list is stated plainly and precisely, never as an error — and the two empty states are different advice: if ready issues exist but are all in flight, say that and name them ("N ready issue(s) already in flight (#…) — nothing new to pull"); only when none exist at all, point at refinement ("no `readiness:ready` issues; refine one first (`/refine-issue`)").
