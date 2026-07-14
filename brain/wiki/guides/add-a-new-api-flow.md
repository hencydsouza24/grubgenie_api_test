---
title: Add a New API Flow
description: How to extend the skill when the backend gains a new endpoint or flow worth scripting.
type: guide
tags:
  - wiki
  - guide
  - how-to
---
## Goal

Add a new pre-built script (bash, and optionally PowerShell) for a backend operation that doesn't have one yet, so future sessions follow [Script-First Methodology](../concepts/script-first-methodology.md) instead of hand-writing curl for it.

## Steps

1. **Confirm the route actually exists and is current** — check it against the backend source (`src/routes/v1/**`), not just `references/api_reference.md`, which has known drift (see [API Reference & Drift](../modules/api-reference.md)).
2. **Write the bash script** in `scripts/`, following the existing pattern: `BASE=${BASE:-http://localhost:3000}` fallback, `set -euo pipefail`, `curl -s ... | jq -r '...'` for token/id extraction, `echo "export VAR=..."` if the script's output is meant to be `eval`'d (like `auth.sh`), or a direct `curl` + human-readable output if it's a one-shot action (like `order_item.sh`).
3. **Add it to `SKILL.md`'s Script Inventory table** (Helper Scripts Reference → Script Inventory) with purpose + usage, so the agent can discover it without reading the script file.
4. **Add it to `README.md`'s Script Reference table** if it's a common enough operation to surface to human installers.
5. **Optionally mirror in PowerShell** (`scripts/powershell/*.ps1`) — only the 5 highest-traffic scripts have PowerShell equivalents today; use `Invoke-RestMethod` instead of curl+jq (see [PowerShell Scripts](../modules/scripts-powershell.md) for the existing pattern).
6. **Document it in the right `references/*.md`** — route table entry in `api_reference.md` if it's a new endpoint, or a new section in `advanced_flows.md`/`petpooja_setup.md` if it's a multi-step flow.
7. **Update this wiki** — add/extend the relevant `modules/` or `flows/` page and re-link it from [OVERVIEW.md](../OVERVIEW.md) if it's a new top-level area.

## Relevant code

- [scripts/order_item.sh](../../../scripts/order_item.sh) — simplest pattern to copy (single auth-gated POST)
- [scripts/flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) — multi-step flow pattern with conditional branching
- [SKILL.md](../../../SKILL.md) — Script Inventory table location

## Gotchas

- Don't trust `references/api_reference.md` as ground truth for whether a route exists — verify against backend source first (see [API Reference & Drift](../modules/api-reference.md) for the categories of drift already found).
- Keep the `BASE=${BASE:-http://localhost:3000}` fallback consistent with whatever the real local port turns out to be — don't propagate the possible `3000` vs `3002` bug into new scripts.
- If the operation needs both partner and diner tokens, follow `auth.sh`'s ordering (partner → table → diner), don't invent a new token-acquisition order.

## Related

- [Sync Skill With Backend Changes](./sync-skill-with-backend-changes.md)
- [Script-First Methodology](../concepts/script-first-methodology.md)
