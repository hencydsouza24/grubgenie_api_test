---
title: Debugging & Context-Mode Patterns
description: Common error-status playbook plus context-mode sandbox patterns for large API responses.
type: module
tags:
  - wiki
  - module
---
## Summary

Two things folded into one page because `references/debugging_guide.md` treats them as one workflow: a status-code-keyed troubleshooting table, and the context-mode sandbox patterns used to keep large API responses out of the agent's context window.

## Responsibilities

Fast triage of 401/403/404/400 responses; safe handling of >10KB responses; a pre-commit testing checklist.

## Public API / entry points

Not an API surface — this is a diagnostic reference. Entry point is `references/debugging_guide.md` plus the `mcp_context_mode_ctx_execute` / `ctx_batch_execute` / `ctx_search` tools referenced in `SKILL.md` Core Rule 2.

## Key files

- [references/debugging_guide.md](../../../references/debugging_guide.md)

## Dependencies

context-mode MCP tools (`ctx_execute`, `ctx_batch_execute`, `ctx_search`) — declared in `SKILL.md` frontmatter `allowed-tools`.

## Participates in

Every flow in this wiki, as the fallback when a flow script fails.

## Status-code playbook

| Status | Common cause | Fix |
|---|---|---|
| 401 | Token expired | Re-run `eval "$(bash $SKILL/auth.sh)"` |
| 403 (diner on partner route) | Expected — role lacks permission | n/a, working as intended |
| 403 (partner on diner route) | User-type mismatch | Check `token.middleware.ts` |
| 403 (missing permission) | RBAC gap | Check `src/config/roles.ts` |
| 404 (order not found) | Used `result._id` instead of `result.currentActiveOrder` | Use the right field from the order response |
| 404 ("not pending acceptance") | Branch not in `orderAcceptanceMode: "manual"` | Set manual mode first |
| 400 ("cartId is required") | Passed as body instead of query | Use `?cartId=...&dinerId=...` query params |
| 400 ("modifications not allowed with reject") | Sent `modifications` on a reject | Use `rejectionReason` instead |
| Payment blocked | An order in the cart is `pending_acceptance` | Partner must accept/reject all pending orders first |

## Other known edge cases

- **"Table already has an active cart"** — previous session left a cart open → `bash $SKILL/reset_tables.sh`.
- **Redis cache stale menu** — check `GET /v1/test/cache`; bypass by restarting the server or waiting out the 1hr TTL.
- **Unicode/JSON parse errors in shell substitution** — write the response to a file and parse with Python instead of inline `jq`/shell expansion.
- **`tsx watch` stalls** — `lsof -ti:3000 | xargs kill -9 && npm run dev` (note: verify port against [Backend API Architecture](../architecture/backend-api-architecture.md)'s `PORT=3002` default).

## Context-mode patterns

1. **Fetch + search** — batch-execute auth + a large GET, then `ctx_search` targeted questions against the indexed result instead of reading the raw 35KB response.
2. **Process without context bloat** — pipe a large menu response through a `python3` one-liner inside `ctx_execute` so only a summary (item count + first 10 names) returns to the agent.
3. **Multi-step flow in sandbox** — run an entire order-approval chain inside one `ctx_execute` call; only the final status line re-enters context.

## Related

- [Script-First Methodology](../concepts/script-first-methodology.md)
- [Cart & Order Lifecycle](../concepts/cart-order-lifecycle.md)
