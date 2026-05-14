# GrubGenie Auth & Security Reference

Auth system uses role-based access control (RBAC) via middleware. This document covers implementation details and known fixes.

## Auth Middleware Implementation

`src/modules/token/token.middleware.ts` — `authMiddleware(...requiredRights)`

### Flow

1. Passport JWT strategy validates Bearer token → resolves `user` + `payload`
2. `hasAccess(user, requiredRights, req.params)` — checks role rights OR ownership
3. `applyPayloadToRequest` — sets `req.tenantId`, `req.conn`, `req.branchId`, `req.accountId`
4. `applyPartnerInfoToRequest` — loads partner doc into `req.partner` (only if `req.partnerId` set)

### `hasAccess` Logic

```ts
function hasAccess(user, requiredRights, params) {
  const userRights = roleRights.get(user.role);
  const hasRequiredRights = requiredRights.every(r => userRights.includes(r));
  return hasRequiredRights || params['userId'] === (user._id?.toString() ?? user.id);
}
```

**Pass conditions:**
- **Role check**: all `requiredRights` in user's role rights
- **Ownership bypass**: `params['userId']` matches user's ID (for self-service routes)

Routes with no `:userId` param have `params['userId'] = undefined`.

## Role → Rights Map

File: `src/config/roles.ts`, `roleRights: Map<string, string[]>`

| Role | Key rights |
|------|-----------|
| `admin` | All partner + menu + order + subscription + insights + meta rights |
| `staff` | Subset of admin — no billing, no delete-branch, no invite |
| `super-admin` | Super-admin CRUD, feature flags, prompts, plans, config, migration |
| `diner` | Menu read, cart CRUD, order CRUD, rating, recommendation, getConfig |

Permission strings in `permissions` object:
```ts
permissions.partner.orderHistory.updateOrder = 'partnerUpdateOrder'
permissions.diner.order.updateOrder = 'updateOrder'
```

---

## Known Bugs and Fixes

### Bug 1: Permission Collision (`updateOrder`)

**Symptom:** Diner token accepted on partner-only routes that require `'updateOrder'`.

**Root cause:** Both `permissions.partner.orderHistory.updateOrder` and `permissions.diner.order.updateOrder` were the string `'updateOrder'`. The diner role has `'updateOrder'` in its rights list. So `hasAccess` passed the role check for partner-only routes when using a diner token.

**Fix:** Renamed partner permission string to `'partnerUpdateOrder'`:
```ts
// src/config/roles.ts
orderHistory: {
  getOrderHistory: 'getOrderHistory',
  getOrderDetails: 'getOrderDetails',
  updateOrder: 'partnerUpdateOrder',  // was 'updateOrder'
},
```

The diner role still has `'updateOrder'` for diner order routes. Partner routes now require `'partnerUpdateOrder'` which diners don't have.

**Affected routes** (use `auth(permissions.partner.orderHistory.updateOrder)`):
- `PUT /v1/partner/order-history/update-status/:orderId`
- `PUT /v1/partner/order-history/update-payment-status/:cartId`
- `PUT /v1/partner/order-history/mark-completed/:cartId`
- `PATCH /v1/partner/order-history/respond/:orderId`

**How to verify fix works:** Diner token on `PATCH /v1/partner/order-history/respond/:orderId` → `403 Forbidden` (not 200 or 404).

---

### Bug 2: Lean Object Auth Bypass

**Symptom:** Diner token gets `200 OK` instead of `403 Forbidden` on partner routes — but only on routes with no `:userId` param.

**Root cause (two parts):**

1. `getDinerById` uses `.lean()` — returns a plain JS object, not a Mongoose Document. Lean objects have no Mongoose virtuals, including the `.id` virtual (which is just `_id.toString()`). So `user.id = undefined`.

2. Routes with no `:userId` param in the URL have `req.params['userId'] = undefined`.

When both are undefined: `undefined === undefined → true` — the ownership bypass in `hasAccess` fires incorrectly, granting access to any diner.

**Fix:** Use `user._id?.toString()` with `?? user.id` fallback:
```ts
// token.middleware.ts line 29 — hasAccess
return hasRequiredRights || params['userId'] === (user._id?.toString() ?? user.id);
```

`_id` is always present on both lean objects and Mongoose documents. The `?? user.id` fallback preserves behavior for any other user types that might not have `_id`.

**How to verify fix works:** Diner token on any partner route with no `:userId` param → `403 Forbidden`.

**How to diagnose similar issues:**
1. Check if the auth middleware is calling `.lean()` on user lookup
2. Check if the route URL has a `:userId` param — if not, `params['userId']` is always `undefined`
3. If user lookup returns lean, `user.id` will be undefined → any route without `:userId` bypasses auth
4. Fix: always use `user._id?.toString()` in the ownership comparison

---

## Diagnosing Auth Issues

### Unexpected 403 (should be allowed)

1. Decode the token: `python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); print(json.loads(base64.b64decode(p)))" "$TOKEN"`
2. Check `role` field in decoded payload
3. Look up `allRoles[role]` in `roles.ts` — does it include the required permission string?
4. Check `auth(...)` call on the route — what permission string is passed?
5. Verify the permission string in `permissions` object matches what's in `allRoles`

### Unexpected 200 (should be blocked)

1. Check if the route has a `:userId` param — if not, lean object bypass may apply
2. Check if the permission string has a collision with another role's permission

### Unexpected 404 on partner route with diner token

Pre-fix behavior of the lean object bypass: `undefined === undefined` would pass `hasAccess`, then the handler runs but may fail with a 404 because the diner's data doesn't match. Post-fix: should be `403` before reaching the handler.

---

## Subscription Middleware

Many partner routes also require a subscription check:
```ts
subscriptionMiddleware(config.subscription.features.dineIn)
```

This fires after auth. If the partner's subscription doesn't include the required feature, returns `403` with a subscription error message (distinct from auth 403).

Order approval/rejection route requires `dineIn` subscription feature.

---

## JWT Payload Structure

### Partner JWT

```json
{
  "partnerId": "<objectId>",
  "accountId": "<accountId>",
  "branchId": "3XSJT",
  "userType": "restaurant-partner",
  "role": "admin" | "staff",
  "iat": ...,
  "exp": ...
}
```

### Diner JWT

```json
{
  "_id": "<objectId>",
  "userType": "diner",
  "role": "diner",
  "iat": ...,
  "exp": ...
}
```

Decode any JWT:
```bash
python3 -c "
import base64, json, sys
p = sys.argv[1].split('.')[1]
p += '=' * (-len(p) % 4)
print(json.dumps(json.loads(base64.b64decode(p)), indent=2))
" "$TOKEN"
```
