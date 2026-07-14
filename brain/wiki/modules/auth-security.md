---
title: Auth & Security
description: RBAC middleware, JWT payload shapes, and two documented historical auth bugs.
type: module
tags:
  - wiki
  - module
---
## Summary

Auth is role-based access control via `src/modules/token/token.middleware.ts` → `authMiddleware(...requiredRights)`. Passport's JWT strategy resolves a Bearer token to `user` + `payload`; `hasAccess` then checks the user's role rights OR an ownership bypass (`params.userId === user's own id`). Two real bugs were previously found and fixed in this path — both are documented here because their failure signatures (wrong 403/200/404) recur.

## Responsibilities

Token validation, role-rights checking, per-route permission enforcement, request enrichment (`req.tenantId`, `req.conn`, `req.branchId`, `req.accountId`, `req.partner`).

## Public API / entry points

`auth(...requiredRights)` middleware, applied per-route with permission strings from the `permissions` object (e.g. `permissions.partner.orderHistory.updateOrder`).

## Key files

- `src/modules/token/token.middleware.ts` — `authMiddleware`, `hasAccess`, `applyPayloadToRequest`, `applyPartnerInfoToRequest` (backend repo, outside this skill)
- `src/config/roles.ts` — `roleRights: Map<string, string[]>` and the `permissions` string map (backend repo)
- [references/auth_security.md](../../../references/auth_security.md) — this module's full source doc

## Dependencies

Passport JWT strategy; `src/config/roles.ts` for the role→rights map.

## Participates in

- [Order Approval / Rejection](../flows/order-approval-rejection.md) — the `partnerUpdateOrder` permission fix below directly gates this flow

## Role → rights map

| Role | Key rights |
|---|---|
| `admin` | All partner + menu + order + subscription + insights + meta rights |
| `staff` | Subset of admin — no billing, no delete-branch, no invite |
| `super-admin` | Super-admin CRUD, feature flags, prompts, plans, config, migration |
| `diner` | Menu read, cart CRUD, order CRUD, rating, recommendation, getConfig |

## Known bugs (fixed, but diagnostic pattern still useful)

**Bug 1 — permission string collision.** `permissions.partner.orderHistory.updateOrder` and `permissions.diner.order.updateOrder` were both the literal string `'updateOrder'`, so a diner token passed the role check on partner-only routes. Fixed by renaming the partner permission to `'partnerUpdateOrder'`. Verify: diner token on `PATCH /v1/partner/order-history/respond/:orderId` → must be `403`, not `200`/`404`.

**Bug 2 — lean-object ownership bypass.** `getDinerById` used `.lean()`, so `user.id` (a Mongoose virtual) was `undefined`; on routes with no `:userId` param, `params.userId` was also `undefined`; `undefined === undefined` incorrectly granted access to any diner. Fixed with `user._id?.toString() ?? user.id`. Verify: diner token on any partner route with no `:userId` param → must be `403`.

**Diagnosing similar issues:**
- Unexpected 403 → decode the token, check `role`, check `allRoles[role]` includes the required permission string, check the permission string matches what the route's `auth(...)` call passes.
- Unexpected 200 → check for a permission-string collision across roles, or a lean-object bypass on a route with no `:userId` param.

## JWT payload shapes

Partner: `{ partnerId, accountId, branchId, userType: "restaurant-partner", role: "admin"|"staff", iat, exp }`
Diner: `{ _id, userType: "diner", role: "diner", iat, exp }`

See [Auth Tokens & JWT](../concepts/auth-tokens-and-jwt.md) for the decode snippet and where `branchId` actually lives.

## Subscription middleware

Many partner routes also run `subscriptionMiddleware(config.subscription.features.dineIn)` after auth — a distinct `403` if the partner's subscription lacks the feature. Order approval/rejection specifically requires the `dineIn` subscription feature.

## Related

- [Auth Tokens & JWT](../concepts/auth-tokens-and-jwt.md)
- [Order Approval / Rejection](../flows/order-approval-rejection.md)
- [Debugging & Context-Mode Patterns](./debugging-context-mode.md)
