---
title: Known Test Data
description: Fixed test credentials and IDs the scripts rely on — including a real branchId inconsistency.
type: concept
tags:
  - wiki
  - concept
---
## Definition

The skill hardcodes a fixed set of test credentials and IDs for the `munch2` tenant, reused across `SKILL.md`, `references/*.md`, and every script:

| Role/Item | Value |
|---|---|
| Partner email / password | `munchuser@yopmail.com` / `Test@123` |
| Partner branchId | `3XSJT` (in JWT payload) |
| Diner fingerprint | `grubgenie-stripe-test-002` |
| Admin email / password | `hello@grubgenie.ai` / `$$grubgod123` |
| Petpooja appKey / restId | `xz8swugh0vp9oymdab2tkne1qr5c3i67` / `i4fwyk7e` |
| Snack Combo item | `69f8757fd475a8cf66ed94f2` (24 AED) |
| Ulli Vada item | `691bf10018f1d3c34db1db00` (12 AED, no variant) |
| Existing diner | `69f89034e0a784fea33a0d12` |

## Why it matters

**Real inconsistency found**: [scripts/auth.sh](../../../scripts/auth.sh) line 15 authenticates the diner with `branchId=D13GZ`, but [scripts/flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) line 27 and every documented example use `branchId=3XSJT`. These are presumably different branches under the same `munch2` custom domain — running `auth.sh` and then a script that assumes the `3XSJT` diner (or vice versa) authenticates against the wrong branch context without any error. Worth resolving: either `auth.sh` has a typo, or the two branch IDs are intentionally different test fixtures and that needs documenting explicitly.

These are internal-only test values — this page and everything linking to it should stay out of any `public`-profile refresh of this wiki.

## Where it lives

- `SKILL.md` — onboarding + "Key API Facts" cheat sheet
- `references/api_reference.md` — "Test Credentials" + "Known Test Data" tables
- `references/petpooja_setup.md` — Petpooja-specific credentials
- [scripts/auth.sh](../../../scripts/auth.sh), [scripts/flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) — the two conflicting `branchId` literals

## Related

- [Bash Scripts](../modules/scripts-bash.md)
- [Auth Tokens & JWT](./auth-tokens-and-jwt.md)
