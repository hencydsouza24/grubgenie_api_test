---
title: Bash Scripts
description: The 14 bash helper scripts under scripts/ — one per API operation or E2E flow.
type: module
tags:
  - wiki
  - module
---
## Summary

`scripts/` holds 14 bash scripts, each wrapping one auth-gated API operation or a full E2E flow. Every script reads `BASE` from the environment (set by `env.sh`) and most expect `PARTNER_TOKEN` / `DINER_TOKEN` / `DINER_ID` / `TABLE_ID` already exported by `auth.sh`. This is the primary execution surface [Script-First Methodology](../concepts/script-first-methodology.md) points an agent at.

## Responsibilities

- Environment selection and authentication (`env.sh`, `auth.sh`)
- Cart + order CRUD and full checkout (`create_cart.sh`, `order_item.sh`, `order_combo.sh`, `flow_dine_in_pay.sh`)
- Menu browsing (`fetch_menu.sh`)
- Petpooja POS testing (`get_pos_menu.sh`, `fetch_pos_items.sh`, `sync_pos_menu.sh`, `test_pos_validation.sh`, `branch_pos_config.sh`)
- AI agent chat (`agent_test.sh`)
- Test-data cleanup (`reset_tables.sh`)

## Public API / entry points

| Script | Purpose | Usage |
|---|---|---|
| [env.sh](../../../scripts/env.sh) | Select target environment | `eval "$(bash $SKILL/env.sh [local\|dev\|prod])"` |
| [auth.sh](../../../scripts/auth.sh) | Partner + diner auth, first table | `eval "$(bash $SKILL/auth.sh)"` |
| create_cart.sh | Create cart for session | `export CART_ID=$(bash $SKILL/create_cart.sh)` |
| order_item.sh | Order menu item | `bash $SKILL/order_item.sh <itemId> [qty]` |
| order_combo.sh | Order combo | `bash $SKILL/order_combo.sh [comboId] [qty]` |
| [flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) | Full E2E dine-in + pay | `bash $SKILL/flow_dine_in_pay.sh [itemId] [qty]` |
| get_pos_menu.sh | Fetch raw POS menu | `bash $SKILL/get_pos_menu.sh` |
| fetch_pos_items.sh | POS items + GrubGenie link status | `bash $SKILL/fetch_pos_items.sh [provider]` |
| sync_pos_menu.sh | Trigger POS menu sync job | `bash $SKILL/sync_pos_menu.sh [petpooja]` |
| test_pos_validation.sh | Test POS ID validation | `bash $SKILL/test_pos_validation.sh` |
| branch_pos_config.sh | Petpooja POS config | `bash $SKILL/branch_pos_config.sh [setup\|get\|disable]` |
| fetch_menu.sh | Browse menu | `bash $SKILL/fetch_menu.sh [items\|categories\|restaurant-info]` |
| agent_test.sh | Agent chat | `bash $SKILL/agent_test.sh "<message>" [dinerId]` |
| reset_tables.sh | Reset all tables | `bash $SKILL/reset_tables.sh` |

## Key files

- [scripts/env.sh](../../../scripts/env.sh) — 3-way case on `local`/`dev`/`prod`, echoes `export BASE=...`
- [scripts/auth.sh](../../../scripts/auth.sh) — partner signin, first table lookup, diner auth; echoes all four exports
- [scripts/flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) — self-contained 8-step flow (does its own auth, doesn't depend on `auth.sh` having run)

**Known inconsistency**: `auth.sh` line 15 authenticates the diner with `branchId=D13GZ`, while `flow_dine_in_pay.sh` line 27 and every documented example in `SKILL.md`/`references/` use `branchId=3XSJT` for the `munch2` tenant. One of these two scripts is authenticating against the wrong branch — see [Known Test Data](../concepts/known-test-data.md).

## Dependencies

- `bash`, `curl`, `jq` (native on macOS/Linux; Windows needs Git Bash + a manually-placed `jq.exe`)
- `BASE` env var (from `env.sh`)
- Token chain from `auth.sh`: `PARTNER_TOKEN` → `TABLE_ID` → `DINER_TOKEN`/`DINER_ID`

## Participates in

- [Dine-In + Pay E2E](../flows/dine-in-pay-e2e.md)
- [Order Approval / Rejection](../flows/order-approval-rejection.md)

## Related

- [PowerShell Scripts](./scripts-powershell.md) — partial mirror of this same surface
- [Script-First Methodology](../concepts/script-first-methodology.md)
