---
name: grubgenie-api-test
description: |
  GrubGenie API testing skill. Provides ready-to-run helper scripts (bash + PowerShell, full
  parity) for all GrubGenie API flows. Supports local (localhost:3000), dev
  (dev-backend.grubgenie.ai), and prod (backend.grubgenie.ai) environments via env.sh / env.ps1.
  Works on macOS, Linux, Windows (Git Bash), and Windows (PowerShell). Includes test credentials,
  a shared session model, and complete E2E flows (dine-in, pay-in-person, Stripe payment, partner
  management, admin, agent testing, combo ordering, order approval/rejection, Petpooja POS sync
  and webhook simulation). Use when testing GrubGenie APIs, verifying new features, debugging
  endpoint behavior, walking through the diner/partner/admin flows interactively, or reproducing
  auth/permission bugs.
allowed-tools: "Bash(python:*) Bash(npm:*) Bash(bash:*) Bash(pwsh:*) WebFetch mcp__plugin_context-mode_context-mode__ctx_execute mcp__plugin_context-mode_context-mode__ctx_search mcp__plugin_context-mode_context-mode__ctx_batch_execute"
---

# GrubGenie API Test Skill

Ready-to-run bash + PowerShell scripts for every GrubGenie API flow — auth, cart, orders,
payments, menu browsing, Petpooja POS, admin, and the AI agent chat endpoint. Both languages
share the same architecture (`scripts/lib/` / `scripts/powershell/lib/`) and produce identical
exit codes and output shapes — see `references/setup.md` for the full per-OS onboarding walkthrough.

## Quick Start

```bash
SKILL=~/.claude/skills/grubgenie-api-test/scripts

eval "$(bash $SKILL/env.sh local)"   # local | dev | prod
eval "$(bash $SKILL/auth.sh)"        # idempotent — reuses a session under 15 min old

# Full E2E in one command
bash $SKILL/flow_dine_in_pay.sh 691bf10018f1d3c34db1db00 2
```

```powershell
$SKILL = "$HOME\.claude\skills\grubgenie-api-test\scripts\powershell"

. $SKILL\env.ps1 -Env local
. $SKILL\auth.ps1

pwsh -File $SKILL\flow_dine_in_pay.ps1 -ItemId 691bf10018f1d3c34db1db00 -Qty 2
```

First time on this machine? Read **[Onboarding](./references/setup.md)** — dependency install per
OS, PowerShell notes, Git Bash setup on Windows.

## Core Rules

### 1. Script-first — never write curl/Invoke-RestMethod by hand

Every operation has a script. Use it:

```bash
eval "$(bash $SKILL/auth.sh)"
export CART_ID=$(bash $SKILL/create_cart.sh)
bash $SKILL/order.sh item <itemId> [qty]         # or: order.sh combo [comboId] [qty]
bash $SKILL/flow_dine_in_pay.sh                  # full E2E: place → approve → pay → confirm
bash $SKILL/pos.sh menu|items|sync|config|validate
bash $SKILL/fetch_menu.sh [command]
bash $SKILL/agent_test.sh "<message>"
bash $SKILL/reset_tables.sh
```

Scripts handle token extraction, request formatting, and error handling correctly — hand-rolled
curl reliably gets one of those wrong (see `references/api_reference.md` "Key Business Rules"
for the mistakes this actually catches).

### 2. Exit codes are the contract — check them

Every script (both languages) uses the same exit-code scheme, whether it succeeds or fails:

| Code | Meaning |
|---|---|
| `0` | success |
| `2` | usage error — bad argument, missing required value |
| `4` | unexpected 4xx from the API |
| `5` | unexpected 5xx from the API |
| `6` | response didn't have the field a script needed (contract violation, not an HTTP error) |
| `7` | unreachable — DNS/connection-refused/timeout |

In bash, a script that calls another script's functions internally already handles this — but if
you write a new one-off check, use `if cmd; then ... else ... fi` or `cmd || rc=$?`, not a bare
call. `set -e` does not reliably propagate through a failing `${VAR:?msg}` or nested
`$(command substitution)` — see `scripts/lib/log.sh`'s `gg_require` for the safe pattern.

### 3. Non-standard operations → context-mode sandbox, not raw curl

If no script covers what you need, use context-mode rather than hand-writing curl — output stays
out of your context window and you still get correct auth via `auth.sh`:

```bash
mcp_context_mode_ctx_execute(
  language: "shell",
  code: """
    SKILL=/path/to/grubgenie-api-test/scripts
    eval "$(bash $SKILL/auth.sh 2>/dev/null)"
    curl -s -X PATCH "$BASE/v1/partner/order-history/respond/ORDER_ID" \\
      -H "Authorization: Bearer $PARTNER_TOKEN" -H 'Content-Type: application/json' \\
      -d '{"action":"accept","modifications":[{"itemId":"<id>","quantity":2}]}'
  """
)
```

### 4. 401 → re-auth; anything else → check Key API Facts below

```bash
eval "$(bash $SKILL/auth.sh --force)"   # --force skips the session-freshness check
```

## Script Inventory

Every script exists in both `scripts/*.sh` and `scripts/powershell/*.ps1` — same name, same
behavior, same exit codes. `order_item`/`order_combo`/`get_pos_menu`/`fetch_pos_items`/
`sync_pos_menu`/`branch_pos_config`/`test_pos_validation` are back-compat shims over `order`/`pos`
(kept because docs and muscle memory reference them by name).

| Script | Purpose | Usage |
|---|---|---|
| `env` | Select environment | `eval "$(bash $SKILL/env.sh local\|dev\|prod)"` |
| `auth` | Partner + diner auth (idempotent) | `eval "$(bash $SKILL/auth.sh [--force])"` |
| `create_cart` | Create cart for the session's table | `export CART_ID=$(bash $SKILL/create_cart.sh)` |
| `order` | Order an item or combo, then place it | `bash $SKILL/order.sh item\|combo <id> [qty]` |
| `flow_dine_in_pay` | Full E2E: cart → order → place → approve → pay → confirm | `bash $SKILL/flow_dine_in_pay.sh [itemId] [qty]` |
| `fetch_menu` | Browse items/categories/combos/offers/etc (17 subcommands) | `bash $SKILL/fetch_menu.sh [command] [arg]` |
| `pos` | Petpooja POS: menu, items, sync, config, validate | `bash $SKILL/pos.sh menu\|items\|sync\|config\|validate` |
| `agent_test` | Chat with the AI agent (unauthenticated) | `bash $SKILL/agent_test.sh "<message>" [dinerId]` |
| `reset_tables` | Reset all tables to available | `bash $SKILL/reset_tables.sh` |

`create_cart`, `order`, and `flow_dine_in_pay` auth themselves automatically if no session
exists yet — you don't strictly need to run `auth` first, but it's useful to see the tokens.

## Common Workflows

### Basic order (dine-in, pay-in-person)

```bash
eval "$(bash $SKILL/auth.sh)"
export CART_ID=$(bash $SKILL/create_cart.sh)
bash $SKILL/order.sh item 691bf10018f1d3c34db1db00 2
bash $SKILL/flow_dine_in_pay.sh
```

### Menu exploration

```bash
bash $SKILL/fetch_menu.sh items                # all items
bash $SKILL/fetch_menu.sh categories
bash $SKILL/fetch_menu.sh restaurant-info
bash $SKILL/fetch_menu.sh items-search "vada"
```

### Petpooja POS integration testing

**Always use real POS menu IDs** — never hardcode dummy item IDs when testing POS integration.

```bash
bash $SKILL/pos.sh menu                        # raw POS menu structure
ITEM_ID=$(bash $SKILL/pos.sh items | jq -r '.result[0].itemid')

bash $SKILL/pos.sh validate                    # confirms invalid POS itemId/variationId → 400
                                                # (one request per case — not two; see Rule 2)
bash $SKILL/pos.sh sync                        # trigger async menu import (202 or 409, both OK)
bash $SKILL/pos.sh config setup|get|disable    # requires scripts/config/credentials.env — see
                                                # references/petpooja_setup.md
```

Duplicate POS ID linking is rejected with 409 — linking the same Petpooja `itemId` or variant
`variationId` to a second menu item fails, same rule for `variationId` in the `variants` array.

**Sync progress** is emitted over the `posMenuImport` socket channel (separate from `menuOcr` and
`imageGen` — a common mistake is listening on a combined channel):

```
Emit: { customDomain: "munch2", branchId: "3XSJT" } on posMenuImport
Receive: { syncing: true,  message: "[pos] Fetching categories..." }
         { syncing: false, message: "[pos] Menu sync complete", refreshMenuData: true }
```

**Petpooja inbound webhooks** have no auth middleware — Petpooja calls these directly, no token
needed. Useful for simulating POS-side events without a live Petpooja sandbox:

```bash
REST_ID="i4fwyk7e"
ORDER_NUM="your-order-number-here"   # GrubGenie orderNumber, NOT the order's _id

# Order status callback — status: -1 cancelled, 1/2/3 accepted, 4 dispatched, 5 food ready, 10 delivered
curl -s -X POST "$BASE/webhooks/v1/pos/order_callback" -H 'Content-Type: application/json' \
  -d "{\"restID\":\"$REST_ID\",\"orderID\":\"$ORDER_NUM\",\"status\":\"5\"}"

# Item availability toggle
curl -s -X POST "$BASE/webhooks/v1/pos/item_off" -H 'Content-Type: application/json' -d "{\"restID\":\"$REST_ID\"}"
curl -s -X POST "$BASE/webhooks/v1/pos/item_on"  -H 'Content-Type: application/json' -d "{\"restID\":\"$REST_ID\"}"

# Store open/closed
curl -s -X POST "$BASE/webhooks/v1/pos/get_store_status"    -H 'Content-Type: application/json' -d "{\"restID\":\"$REST_ID\"}"
curl -s -X POST "$BASE/webhooks/v1/pos/update_store_status" -H 'Content-Type: application/json' -d "{\"restID\":\"$REST_ID\"}"
```

Full endpoint list, request/response shapes, and validation rules: `references/api_reference.md`
("POS Routes" + "Webhook Routes"). Credential setup: `references/petpooja_setup.md`.

**Order push (GrubGenie → Petpooja)** happens async via BullMQ queue `petpoojaOrderPush` when an
order is placed/accepted — the API returns before the push completes; check server logs for
`[petpoojaOrderPush]` entries to confirm it fired.

### Order approval/rejection (manual acceptance mode)

```bash
curl -X PUT "$BASE/v1/partner/branch/update-branch/3XSJT" \
  -H "Authorization: Bearer $PARTNER_TOKEN" -H 'Content-Type: application/json' \
  -d '{"orderAcceptanceMode":"manual"}'
```

Placed orders now land in `pending_acceptance` immediately (see Key API Facts for the exact
state-machine correction). Accept or reject:

```bash
curl -X PATCH "$BASE/v1/partner/order-history/respond/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" -H 'Content-Type: application/json' \
  -d '{"action":"accept","modifications":[{"itemId":"<id>","quantity":2}]}'
```

`action` is required (`accept`/`reject`); `rejectionReason` required on reject, forbidden on
accept; `modifications` allowed only on accept; each modification needs exactly one of
`itemId`/`comboId`. Full validation table and edge cases: `references/advanced_flows.md`.

## Key API Facts (Common Mistakes)

| Mistake | Fix |
|---|---|
| Partner token at `result.tokens.access.token` | Use `result.accessToken` |
| Cart ID at `result._id` | Use `result.cartId` |
| Order route takes body params | Use query params: `?cartId=&dinerId=` |
| Combo order uses `itemId` key | Use `comboId` key |
| Place-order route has no query param | Add `?cartId=` |
| munch2 branchId | `3XSJT` (single source of truth: `scripts/lib/constants.sh`) |
| Payment blocked | Partner must accept/reject all pending orders first |
| POS config via branch create/update | Use dedicated `/v1/partner/branch/pos-config` endpoints |
| Sync-menu returns 404/500 | POS config not set — run `pos.sh config setup` first |
| Sync-menu returns 409 | Job already running — `pos.sh sync` treats this as success |
| Socket: one combined ocr/pos channel | Channels are separate: `menuOcr`, `posMenuImport`, `imageGen` |
| Webhook auth on `/webhooks/v1/pos/*` | No auth middleware — Petpooja calls these directly |
| `pending_acceptance` entered after partner responds | Entered immediately on place-order (manual mode); partner's decision moves it OUT, to `preparing`/`rejected` |
| Petpooja `orderID` maps to order `_id` | Maps to `orderNumber` field, not `_id` |

## References

- **[Onboarding](./references/setup.md)** — full per-OS setup, dependencies, Git Bash on Windows
- **[API Reference](./references/api_reference.md)** — full route map, test credentials, POS + webhook routes, schemas
- **[Auth & Security](./references/auth_security.md)** — auth middleware, permissions, known bugs
- **[Advanced Flows](./references/advanced_flows.md)** — order approval/rejection, variant selection, success pages
- **[Petpooja Setup](./references/petpooja_setup.md)** — credentials, POS config endpoints, validation rules
- **[Debugging Guide](./references/debugging_guide.md)** — common errors, context-mode patterns
- **[evals/](./evals/)** — offline smoke suite (`run_evals.sh --offline`); runs with no live API needed

## Status

Full bash/PowerShell parity across 16 scripts + shared lib, verified via `evals/run_evals.sh
--offline` (syntax, conventions, secret gate, cross-language exit-code parity). See `evals/` for
the live-API test suite. Refactor history: `REFACTOR_SUMMARY.md`.
