---
title: Petpooja POS Integration
description: POS config endpoints, credentials, validation rules, and current test-data limitations.
type: module
tags:
  - wiki
  - module
---
## Summary

GrubGenie integrates with Petpooja as its (currently only) POS provider. Config is managed via three dedicated endpoints on the branch — never through `add-branch`/`update-branch`. As of the last check, the test Petpooja restaurant (`i4fwyk7e`) has 33 categories mapped but 0 items, so full item-linking tests need items added on the Petpooja side first (see Gotchas below).

## Responsibilities

POS credential storage (partner-only visibility), POS ID validation on menu-item create/update (409 on duplicate link), menu sync trigger, and Petpooja→GrubGenie inbound webhooks (order status, item on/off, store status).

## Public API / entry points

| Method | Route | Purpose |
|---|---|---|
| GET | `/v1/partner/branch/pos-config` | List POS configs (credentials included, partner-only) |
| PUT | `/v1/partner/branch/pos-config` | Upsert a provider config (merges by provider) |
| DELETE | `/v1/partner/branch/pos-config/:provider` | Remove a provider config — 204, idempotent |
| GET | `/v1/partner/pos/*` items | `bash $SKILL/fetch_pos_items.sh [provider]` |
| POST | `/v1/partner/pos/sync-menu` | Trigger async menu import (BullMQ `petpoojaOrderPush`-adjacent job) |

PUT body: `{ provider: "petpooja", isEnabled, credentials: { appKey, appSecret, accessToken, restId } }` — all 4 credential fields required.

## Key files

- [scripts/get_pos_menu.sh](../../../scripts/get_pos_menu.sh), [scripts/branch_pos_config.sh](../../../scripts/branch_pos_config.sh), [scripts/test_pos_validation.sh](../../../scripts/test_pos_validation.sh), [scripts/sync_pos_menu.sh](../../../scripts/sync_pos_menu.sh)
- [references/petpooja_setup.md](../../../references/petpooja_setup.md) — full source doc with credentials, validation table, and multi-provider upsert semantics

## Dependencies

Petpooja test account (`munch2` restaurant, `restId: i4fwyk7e`); Mongoose `select: false` on credential fields so diner APIs never see them; BullMQ for async sync.

## Participates in

- [Petpooja Webhook Callbacks](../flows/petpooja-webhook-callbacks.md)

## Validation rules

- `provider` must be the enum value `'petpooja'`; all 4 credential fields required.
- Linking the same Petpooja `itemId` or `variationId` to a second menu item → `409 Conflict`.
- Invalid/non-existent POS `itemId` on menu-item create — `400 "POS item not found"`.
- DELETE on a non-existent provider config — `204`, idempotent.
- Diner token on any POS-config route — `403`.

## Gotchas

- **Test restaurant menu is empty** (33 categories, 0 items as last checked) — always fetch real item IDs via `get_pos_menu.sh` before testing item-linking; never hardcode a dummy `itemId`.
- **Socket channels are separate per feature**: `menuOcr` (OCR upload), `posMenuImport` (POS sync progress), `imageGen` (AI image gen) — don't cross-wire them.
- **Webhook path drift**: the callback URLs documented in `SKILL.md`/`petpooja_setup.md` (`$BASE/webhooks/v1/pos/...`) do not match the backend's actual mount point. See [API Reference & Drift](./api-reference.md) and [Petpooja Webhook Callbacks](../flows/petpooja-webhook-callbacks.md).

## Related

- [API Reference & Drift](./api-reference.md)
- [Petpooja Webhook Callbacks](../flows/petpooja-webhook-callbacks.md)
