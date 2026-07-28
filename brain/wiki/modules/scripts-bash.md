---
title: Bash Scripts
description: The 16 bash scripts under scripts/ (9 primary + 7 back-compat shims), built on a shared scripts/lib/ layer.
type: module
tags:
  - wiki
  - module
---
## Summary

`scripts/` holds 16 bash scripts: 9 primary scripts (`env`, `auth`, `create_cart`, `order`,
`flow_dine_in_pay`, `fetch_menu`, `pos`, `agent_test`, `reset_tables`) plus 7 back-compat shims
(`order_item`, `order_combo`, `get_pos_menu`, `fetch_pos_items`, `sync_pos_menu`,
`branch_pos_config`, `test_pos_validation`) that `exec` into the primary scripts. All of them
source a shared library at `scripts/lib/` instead of hand-rolling curl and auth per script — this
is the result of a July 2026 refactor (see `REFACTOR_SUMMARY.md` / the git history for the
`hencydsouza24/pinniped` branch) that replaced the previous "every script does its own curl and
auth" design.

## Responsibilities

- Environment selection and idempotent session auth (`env.sh`, `auth.sh` — reuses a session file
  under 15 minutes old instead of re-authenticating every call)
- Cart + order CRUD and full checkout (`create_cart.sh`, `order.sh` item|combo, `flow_dine_in_pay.sh`)
- Menu browsing, 17 subcommands (`fetch_menu.sh`)
- Petpooja POS: menu/items/sync/config/validate, all under one script (`pos.sh`)
- AI agent chat (`agent_test.sh`)
- Test-data cleanup (`reset_tables.sh`)

## The shared library (`scripts/lib/`)

| Module | Responsibility |
|---|---|
| `bootstrap.sh` | sole entry point every script sources; sets strict mode, sources the rest |
| `constants.sh` | canonical fixtures — `branchId=3XSJT`, test IDs, exit codes. Pure, no I/O |
| `env.sh` | environment name → BASE URL resolution |
| `log.sh` | narration (stderr only) + `gg_die`/`gg_require` for usage errors |
| `http.sh` | the HTTP transport — owns status-code → exit-code mapping (see below) |
| `json.sh` | field extraction with validation, JSON body construction |
| `auth.sh` | idempotent session acquisition + session-file persistence |
| `api.sh` | GrubGenie domain verbs (cart/order/pos operations) built on the above |

Every script's own exit status follows one contract: `0` success, `2` usage error, `4`/`5`
unexpected HTTP status, `6` response missing an expected field (contract violation, distinct from
a transport failure), `7` unreachable. This is enforced mechanically, not just documented —
`evals/offline/04_conventions.sh` fails the suite if a migrated script uses bare `curl` outside
`lib/http.sh`, and `evals/offline/07_contract_mock.sh` asserts the exact exit code for each HTTP
status class against a local stub server.

## Public API / entry points

| Script | Purpose | Usage |
|---|---|---|
| [env.sh](../../../scripts/env.sh) | Select target environment | `eval "$(bash $SKILL/env.sh [local\|dev\|prod])"` |
| [auth.sh](../../../scripts/auth.sh) | Idempotent partner + diner auth | `eval "$(bash $SKILL/auth.sh [--force])"` |
| [create_cart.sh](../../../scripts/create_cart.sh) | Create cart for session's table | `export CART_ID=$(bash $SKILL/create_cart.sh)` |
| [order.sh](../../../scripts/order.sh) | Order item/combo, then place | `bash $SKILL/order.sh item\|combo <id> [qty]` |
| [flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) | Full E2E: cart→order→place→approve→pay→confirm | `bash $SKILL/flow_dine_in_pay.sh [itemId] [qty]` |
| [fetch_menu.sh](../../../scripts/fetch_menu.sh) | Browse menu (17 subcommands) | `bash $SKILL/fetch_menu.sh [command] [arg]` |
| [pos.sh](../../../scripts/pos.sh) | Petpooja: menu/items/sync/config/validate | `bash $SKILL/pos.sh menu\|items\|sync\|config\|validate` |
| [agent_test.sh](../../../scripts/agent_test.sh) | Agent chat (unauthenticated) | `bash $SKILL/agent_test.sh "<message>" [dinerId]` |
| [reset_tables.sh](../../../scripts/reset_tables.sh) | Reset all tables | `bash $SKILL/reset_tables.sh` |

Shims (`order_item.sh`, `order_combo.sh`, `get_pos_menu.sh`, `fetch_pos_items.sh`,
`sync_pos_menu.sh`, `branch_pos_config.sh`, `test_pos_validation.sh`) are 3-line `exec` wrappers
kept for back-compat with docs/muscle memory; they carry no logic of their own.

## Key files

- [scripts/lib/http.sh](../../../scripts/lib/http.sh) — the transport layer; `gg_http`'s
  `--expect SPEC` lets a caller treat a specific non-2xx status as success (e.g. `pos.sh sync`
  treats 409 "already running" as success from a single request)
- [scripts/lib/auth.sh](../../../scripts/lib/auth.sh) — writes a session file
  (`$TMPDIR/grubgenie-session-<env>.json`) that bash AND PowerShell both read/write, using the
  same path convention — this is what lets a bash `auth.sh` run and a PowerShell `order.ps1` run
  share one session on the same machine
- [scripts/flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) — now ~30 lines of pure
  orchestration calling `lib/api.sh` functions; the July 2026 refactor's flagship example, down
  from 88 lines of inline curl + duplicated auth

**branchId**: previously a real inconsistency (`auth.sh` used `D13GZ`, everything else used
`3XSJT`) — resolved. `3XSJT` is now the single source of truth in `lib/constants.sh`
(`GG_BRANCH_ID`); no script has its own literal to drift out of sync. See
[Known Test Data](../concepts/known-test-data.md).

## Dependencies

- `bash`, `curl`, `jq` (native on macOS/Linux; Windows needs Git Bash + a manually-placed `jq.exe`)
- `BASE` env var (from `env.sh`) or the session file's `.base` field
- Session file from `lib/auth.sh`, not raw exported tokens — scripts auth themselves
  automatically if no session exists yet

## Participates in

- [Dine-In + Pay E2E](../flows/dine-in-pay-e2e.md)
- [Order Approval / Rejection](../flows/order-approval-rejection.md)

## Related

- [PowerShell Scripts](./scripts-powershell.md) — full parity, same lib architecture, same exit codes
- [Script-First Methodology](../concepts/script-first-methodology.md)
