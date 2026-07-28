---
title: Wiki Log
description: Append-only audit trail of wiki generation and refresh runs.
---

# Wiki Log

Append-only audit trail. Add one dated entry per generation or refresh run, recording the profile, the `source_commit` it was anchored to, and the coverage. The codebase-wiki skill describes the entry shape.

## 2026-07-14: generate

- Profile: internal/standard
- source_commit: 8e7a780 (skill repo HEAD at generation time)
- Coverage: full generate pass — OVERVIEW, 2 architecture pages, 6 module pages, 3 flow pages, 5 concept pages, 2 guide pages (19 pages total). Scope: primarily the `grubgenie-api-test` skill itself (SKILL.md, scripts/, references/), with the real backend (`grubgenie_api_refactor`) folded in as supporting architecture/context since the skill exists to test it.
- Pages: [Overview](./OVERVIEW.md), [Skill Architecture](./architecture/skill-architecture.md), [Backend API Architecture](./architecture/backend-api-architecture.md), [Bash Scripts](./modules/scripts-bash.md), [PowerShell Scripts](./modules/scripts-powershell.md), [API Reference & Drift](./modules/api-reference.md), [Auth & Security](./modules/auth-security.md), [Petpooja POS Integration](./modules/petpooja-pos.md), [Debugging & Context-Mode Patterns](./modules/debugging-context-mode.md), [Dine-In + Pay E2E](./flows/dine-in-pay-e2e.md), [Order Approval / Rejection](./flows/order-approval-rejection.md), [Petpooja Webhook Callbacks](./flows/petpooja-webhook-callbacks.md), [Environments & BASE URL](./concepts/environments-and-base-url.md), [Auth Tokens & JWT](./concepts/auth-tokens-and-jwt.md), [Script-First Methodology](./concepts/script-first-methodology.md), [Cart & Order Lifecycle](./concepts/cart-order-lifecycle.md), [Known Test Data](./concepts/known-test-data.md), [Add a New API Flow](./guides/add-a-new-api-flow.md), [Sync Skill With Backend Changes](./guides/sync-skill-with-backend-changes.md)
- Key finding surfaced during generation: real `branchId` inconsistency between `scripts/auth.sh` (`D13GZ`) and `scripts/flow_dine_in_pay.sh` (`3XSJT`) — flagged in [Known Test Data](./concepts/known-test-data.md), not yet fixed in the scripts themselves.
- Link audit: 0 dead links, all 19 authored pages appear in `hubs` (nonzero inbound), no unintended orphans.

## 2026-07-29: targeted refresh (not a full regenerate)

- Trigger: a SOLID/DRY refactor of the skill itself (branch `hencydsouza24/pinniped`) — new
  `scripts/lib/` (bash) + `scripts/powershell/lib/` (PowerShell) shared architecture, full
  bash/PowerShell parity across all 16 scripts (was 5 of 14), one shared exit-code contract
  (`0`/`2`/`4`/`5`/`6`/`7`), an offline eval harness (`evals/`), `SKILL.md` re-consolidated
  670→260 lines, `AGENTS.md` + `install.sh` added, and the `branchId` `D13GZ`/`3XSJT`
  inconsistency this wiki flagged in [Known Test Data](./concepts/known-test-data.md) resolved
  (`3XSJT` confirmed canonical, single source of truth in `lib/constants.sh`).
- Method: **manual targeted edits to the specific pages the refactor made stale**, not a full
  `codebase-wiki` regenerate pass — the OpenKnowledge project config (`.ok/config.yml`) for this
  repo lives in a separate git worktree from the one this refactor happened in, and running the
  automated wiki workflow would have analyzed the wrong checkout. Updated:
  [Bash Scripts](./modules/scripts-bash.md), [PowerShell Scripts](./modules/scripts-powershell.md),
  [Skill Architecture](./architecture/skill-architecture.md),
  [Dine-In + Pay E2E](./flows/dine-in-pay-e2e.md),
  [Script-First Methodology](./concepts/script-first-methodology.md),
  [Known Test Data](./concepts/known-test-data.md) (secret redacted, inconsistency marked
  resolved), [API Reference & Drift](./modules/api-reference.md) (append-only update — the
  2026-07-14 backend-drift findings were NOT re-verified this pass, see that page's own
  "Update" section for exactly what did and didn't change).
- Explicitly NOT touched: [Backend API Architecture](./architecture/backend-api-architecture.md),
  [Order Approval/Rejection](./flows/order-approval-rejection.md),
  [Petpooja Webhook Callbacks](./flows/petpooja-webhook-callbacks.md),
  [Auth Tokens & JWT](./concepts/auth-tokens-and-jwt.md),
  [Cart & Order Lifecycle](./concepts/cart-order-lifecycle.md),
  [Environments & BASE URL](./concepts/environments-and-base-url.md),
  [Backend API Architecture](./architecture/backend-api-architecture.md), both guides, and
  [Debugging & Context-Mode Patterns](./modules/debugging-context-mode.md) — these describe the
  GrubGenie backend's own API behavior or genuinely backend-facing debugging patterns, which this
  refactor didn't change and didn't re-verify.
- Follow-up still open: a real `codebase-wiki` regenerate pass from a worktree with a working
  `.ok/config.yml`, and a re-check of the 2026-07-14 backend-drift findings against a current
  `grubgenie_api_refactor` checkout (base URL/port, webhook path prefix order,
  `/v1/admin/genie/*`, the other undocumented routes listed in
  [API Reference & Drift](./modules/api-reference.md)).
