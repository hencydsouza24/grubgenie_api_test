---
title: API Reference & Drift
description: The skill's documented API surface (references/api_reference.md) vs. the live backend, with a full diff.
type: module
tags:
  - wiki
  - module
---
## Summary

`references/api_reference.md` is the skill's canonical route map: base URL, test credentials, token extraction patterns, a full route table by domain (auth / diner-genie / partner / admin / agent / webhooks), branch schemas, and business rules (cart/order status flow, payment blocking). Most of it still matches the live backend at `~/Desktop/grubgenie_api_refactor`. This page records where it has **drifted**, found by diffing the doc against the actual route source (`src/routes/v1/**`, `src/webhooks/v1/**`, `src/config/config.ts`) on 2026-07-14.

## Responsibilities

Single source of truth for: which routes exist, what auth they need, what their bodies/queries look like, and the cross-cutting business rules (cart status flow, payment-blocked-on-pending-acceptance, etc).

## Public API / entry points

See [references/api_reference.md](../../../references/api_reference.md) for the full route tables (auth, diner/genie, partner, admin, agent, webhook). Not duplicated here — this page is the diff, not a copy.

## Key files

- [references/api_reference.md](../../../references/api_reference.md) — the documented surface
- Backend `src/app.ts`, `src/routes/v1/**`, `src/webhooks/v1/**`, `src/config/config.ts` — the actual surface (outside this repo, read during the 2026-07-14 comparison; not directly linkable from here since they live in a different project)

## Dependencies

None — this is documentation, not code.

## Participates in

- [Sync Skill With Backend Changes](../guides/sync-skill-with-backend-changes.md) — the guide for closing gaps found here

## Drift found (2026-07-14)

### Base URL / port
Skill assumes local = `http://localhost:3000` (`scripts/env.sh`, `SKILL.md`, `README.md`). Backend's `src/config/config.ts` defaults `PORT=3002`. Verify the `.env` actually used for local dev — if it runs on `3002`, every `env.sh local` call in this skill is wrong out of the box.

### Webhook path prefix order (likely broken as documented)
`api_reference.md` documents webhook routes as `$BASE/webhooks/v1/...` (e.g. `/webhooks/v1/pos/order_callback`, `/webhooks/v1/stripe/diner-payment`, `/webhooks/v1/stripe/partner-onboarding`). The backend mounts webhooks at **`/v1/webhooks/**`** — `v1` before `webhooks`, the reverse order — with different leaf names: `/v1/webhooks/pos/petpooja/order_callback` (provider name inserted), `/v1/webhooks/stripe/diner` (not `diner-payment`), `/v1/webhooks/stripe/onboarding` (not `partner-onboarding`). The curl examples in `SKILL.md`'s POS Integration workflow and `references/petpooja_setup.md` would 404 as written.

### Undocumented: `/v1/admin/genie/*`
A full admin console for the LangGraph genie agent — fleet/session/thread listing, activity, delete/evict, `signal`, `chat`, `end` — added in commits `e3d7ee65`, `229e535d`, `af11160e` (2026-07-13/14). Zero mention in `api_reference.md`.

### Other routes missing from the doc
- `POST /v1/partner/auth/forgot-password`, `PUT /v1/partner/auth/reset-password/:token`, `GET /v1/partner/auth/check-email`
- `POST /v1/partner/branch/accept-invite`
- `/v1/partner/menu-ocr`
- `/v1/partner/meta/facebook-code-auth`, `/pages`, `/select-page`, `/disconnect`, `/post` (doc only covers `instagram/media` + `instagram/media/bulk`)
- `/v1/partner/subscription/features`, `/billing-history`
- `GET /v1/genie/menu/restaurant-branches/:customDomain`
- `GET /v1/genie/combo`, `GET /v1/genie/combo/:comboId` (the doc has no combo *fetch* route, even though `order_combo.sh` exists for *ordering* one)
- `/v1/genie/recommendation/get-dietary-tags`, `/restaurant-weather`
- `/v1/admin/ml/retrain*`, `/v1/admin/openviking/*`, `/v1/admin/langfuse/*`, `/v1/admin/langsmith/*`, `PATCH /v1/admin/partner/:accountId`
- `/v1/upload`, `/v1/upload/convert-format`
- `/v1/google-auth`, `/v1/health`, `/v1/mcp`, `/v1/docs` (swagger)

### Confirmed still accurate
Auth flow (partner/diner/admin signin, token shapes), diner/genie ordering + cart + payment routes, partner menu/branch/table/order-history/POS-config routes, and the documented business rules (cart status flow, order status flow, payment-blocked-on-`pending_acceptance`) all match current backend behavior.

## Update (2026-07-29 — skill-internal refactor, backend NOT re-verified)

A refactor of the skill itself (scripts + doc consolidation, `hencydsouza24/pinniped` branch)
touched `api_reference.md`'s **structure**, not its backend accuracy — this session had no
access to `~/Desktop/grubgenie_api_refactor` to re-check the drift findings above, so **all four
open findings above (base URL/port, webhook prefix order, `/v1/admin/genie/*`, the other missing
routes) remain exactly as unverified as they were on 2026-07-14.** Do not read the changes below
as resolving them.

What did change, self-consistently within this repo (SKILL.md ↔ advanced_flows.md ↔
api_reference.md agreeing with each other, not with the live backend):
- Added a "POS Routes" section (`/v1/partner/pos/menu`, `/:provider/items`, `/sync-menu`) that
  was previously undocumented in `api_reference.md` — sourced from the skill's own `pos.sh`
  implementation, itself derived from the pre-existing (unverified) script behavior.
- Added the six `/webhooks/v1/pos/*` rows to the webhook table and retitled it — it previously
  said "not for manual testing" while `SKILL.md` gave nine working manual curl examples for
  exactly those routes. Still using the `/webhooks/v1/...` prefix order throughout — if the
  2026-07-14 finding above is correct that the real backend expects `/v1/webhooks/...`, this
  newly-added section inherits the same unverified prefix as everything else in this repo.
- Removed a byte-identical duplicate `POST /v1/admin/auth/signin` row.
- Moved `/v1/feature-flags/*` and `/v1/prompt/*` out of "Admin Routes" into a new "Platform
  Routes" section — they don't carry the `/v1/admin` prefix despite being admin-gated.
- Corrected the order-status flow's stated sequencing: `pending_acceptance` is entered
  **immediately on place-order** (manual mode), not after the partner responds — the previous
  wording had this backwards, contradicting `SKILL.md` and `advanced_flows.md`'s own worked
  examples elsewhere in the same doc set.

**Still worth doing**: re-run the 2026-07-14 comparison against a current checkout of
`grubgenie_api_refactor` to actually resolve the base-URL/port and webhook-prefix questions —
see [Sync Skill With Backend Changes](../guides/sync-skill-with-backend-changes.md).

## Related

- [Backend API Architecture](../architecture/backend-api-architecture.md)
- [Sync Skill With Backend Changes](../guides/sync-skill-with-backend-changes.md)
- [Petpooja Webhook Callbacks](../flows/petpooja-webhook-callbacks.md) — affected by the path-prefix drift above
