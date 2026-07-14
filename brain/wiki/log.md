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
