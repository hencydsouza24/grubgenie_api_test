---
title: PowerShell Scripts
description: Full PowerShell parity with the bash toolkit — all 16 scripts, same shared-library architecture, same exit codes.
type: module
tags:
  - wiki
  - module
---
## Summary

`scripts/powershell/` now mirrors the **entire** bash surface — all 16 scripts, built on the same
shared-library architecture (`scripts/powershell/lib/*.ps1`, dot-sourced, mirroring
`scripts/lib/*.sh` module-for-module). This replaced a July-2026-era partial mirror that covered
only 5 of 14 bash scripts; Windows users no longer need Git Bash for POS testing, menu browsing,
or combo ordering. No extra dependencies for PowerShell 7+; PowerShell 5.1 works too (the lib
auto-negotiates TLS 1.2, which isn't always the Windows default).

## Responsibilities

Identical to [Bash Scripts](./scripts-bash.md) — same 9 primary scripts + 7 back-compat shims,
same exit-code contract (`0`/`2`/`4`/`5`/`6`/`7`), same session-file composition model.

## The shared library (`scripts/powershell/lib/`)

Module-for-module mirror of the bash `lib/`: `Bootstrap.ps1`, `Constants.ps1`, `Log.ps1`,
`Env.ps1`, `Json.ps1`, `Http.ps1`, `Auth.ps1`, `Api.ps1`. Two language-specific design points:

- **`Invoke-GgHttp` returns a string, never a deserialized object** — letting
  `Invoke-WebRequest`/`Invoke-RestMethod` auto-parse JSON would make `.result.cartId` (PS) and
  `jq -r '.result.cartId'` (bash) diverge structurally; both languages explicitly
  `ConvertFrom-Json` at the same point instead.
- **`$Script:GgHttpExitCode`, read immediately after each call** — PS functions run in-process
  (no subshell), so this doesn't need bash's file-backed status workaround, but the discipline is
  the same: check it before proceeding, same as bash's `|| exit $?`.

## Public API / entry points

Same table as [Bash Scripts](./scripts-bash.md), PowerShell usage column:

| Script | Usage |
|---|---|
| `env.ps1` | `. $SKILL\env.ps1 -Env local\|dev\|prod` (dot-source — persists `$env:BASE`) |
| `auth.ps1` | `. $SKILL\auth.ps1 [-Force]` (dot-source — persists session env vars) |
| `create_cart.ps1` | `$env:CART_ID = & "$SKILL\create_cart.ps1"` (normal invocation, not dot-sourced) |
| `order.ps1` | `pwsh $SKILL\order.ps1 item\|combo <id> [-Qty 2]` |
| `flow_dine_in_pay.ps1` | `pwsh $SKILL\flow_dine_in_pay.ps1 [-ItemId <id>] [-Qty 2]` |
| `fetch_menu.ps1` | `pwsh $SKILL\fetch_menu.ps1 [command] [arg]` |
| `pos.ps1` | `pwsh $SKILL\pos.ps1 menu\|items\|sync\|config\|validate` |
| `agent_test.ps1` | `pwsh $SKILL\agent_test.ps1 "<message>"` |
| `reset_tables.ps1` | `pwsh $SKILL\reset_tables.ps1` |

**Dot-source `env.ps1`/`auth.ps1` only.** Everything else is a normal invocation. This isn't
style preference — PowerShell's `exit` inside a dot-sourced script only terminates that script's
own execution, not the calling session (confirmed by direct testing, not assumption), so a
dot-sourced script that "fails" still leaves the caller's shell running — the right behavior for
an interactive session-setup script, wrong if you need a reliable process exit code. Scripts
meant to be checked programmatically (`create_cart.ps1`, `order.ps1`, ...) are invoked normally
(`&` or direct), where `exit` propagates correctly.

## Key files

- [scripts/powershell/lib/Http.ps1](../../../scripts/powershell/lib/Http.ps1) — the PS transport,
  parity partner to bash's `lib/http.sh`
- [scripts/powershell/lib/Auth.ps1](../../../scripts/powershell/lib/Auth.ps1) — reads/writes the
  **same session file path** bash uses (`Get-GgTempDir` honors `$env:TMPDIR` before falling back
  to `.NET`'s temp path, matching bash's `${TMPDIR:-/tmp}`) — a bash `auth.sh` run and a
  PowerShell `order.ps1` run on the same machine share one session, verified directly (bash
  writes a session, PowerShell reads it back correctly).
- [scripts/powershell/order_item.ps1](../../../scripts/powershell/order_item.ps1) — a shim that
  calls the same lib functions `order.ps1` calls **directly** (not via `&`/dot-sourcing another
  `.ps1` file), because that delegation style has the same exit-code-swallowing problem as
  dot-sourcing. `test_pos_validation.ps1` is the one exception — its logic was large enough that
  duplicating it wasn't worth it, so it spawns `pos.ps1` as a genuine subprocess (`pwsh -File`)
  instead, which does propagate exit codes correctly.

## Dependencies

PowerShell 7+ recommended; PowerShell 5.1 (Windows-native) works via a TLS 1.2 shim in
`Bootstrap.ps1`. No `jq`/`curl` install needed — everything goes through `Invoke-WebRequest`.

## Participates in

- [Dine-In + Pay E2E](../flows/dine-in-pay-e2e.md) — same flow, byte-identical output to bash for
  identical inputs (verified in `evals/offline/07_contract_mock.sh`)

## Related

- [Bash Scripts](./scripts-bash.md) — full parity now, not a partial mirror
- [Skill Architecture](../architecture/skill-architecture.md)
