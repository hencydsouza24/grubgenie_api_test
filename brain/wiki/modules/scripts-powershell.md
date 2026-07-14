---
title: PowerShell Scripts
description: The 5-script PowerShell mirror of the bash toolkit for Windows users.
type: module
tags:
  - wiki
  - module
---
## Summary

`scripts/powershell/` mirrors only the five highest-traffic bash scripts, dot-sourced instead of `eval`'d. No extra dependencies — PowerShell's built-in `Invoke-RestMethod` replaces `curl` + `jq`.

## Responsibilities

Environment selection, auth, cart creation, single-item ordering, and the full dine-in E2E flow — the minimum needed to exercise the primary flow without Git Bash.

## Public API / entry points

| Script | Purpose | Usage |
|---|---|---|
| `env.ps1` | Select target environment | `. $SKILL\env.ps1 [local\|dev\|prod]` |
| `auth.ps1` | Partner + diner auth, first table | `. $SKILL\auth.ps1` |
| `create_cart.ps1` | Create cart for session | `. $SKILL\create_cart.ps1` |
| `order_item.ps1` | Order menu item | `. $SKILL\order_item.ps1 -ItemId <id> [-Qty 2]` |
| `flow_dine_in_pay.ps1` | Full E2E dine-in + pay | `. $SKILL\flow_dine_in_pay.ps1 [-ItemId <id>] [-Qty 2]` |

## Key files

- [scripts/powershell/env.ps1](../../../scripts/powershell/env.ps1)
- [scripts/powershell/auth.ps1](../../../scripts/powershell/auth.ps1)
- [scripts/powershell/flow_dine_in_pay.ps1](../../../scripts/powershell/flow_dine_in_pay.ps1)

## Dependencies

PowerShell 5.1+ (Windows-native) or PowerShell Core; no `jq`/`curl` install needed.

## Participates in

- [Dine-In + Pay E2E](../flows/dine-in-pay-e2e.md) — same flow, PowerShell transport

## Related

- [Bash Scripts](./scripts-bash.md) — the full 14-script surface this only partially mirrors. `order_combo.ps1`, `fetch_menu.ps1`, and all POS-testing scripts have **no** PowerShell equivalent — Windows users need Git Bash for those.
