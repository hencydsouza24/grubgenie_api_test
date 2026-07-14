---
title: Auth Tokens & JWT
description: PARTNER_TOKEN / DINER_TOKEN extraction, JWT payload shapes, and branchId decoding.
type: concept
tags:
  - wiki
  - concept
---
## Definition

The skill authenticates two token types per session: `PARTNER_TOKEN` (from `/v1/partner/auth/signin`, body `{email,password}`, path `result.accessToken`) and `DINER_TOKEN` (from `GET /v1/genie/diner?customDomain&branchId&fingerprint`, path `result.accessToken` + `result._id`). Both are decoded JWTs whose `branchId` lives in the **payload**, not the response body.

## Why it matters

Almost every script depends on `auth.sh` having exported `PARTNER_TOKEN`/`DINER_TOKEN`/`DINER_ID`/`TABLE_ID` first. A 401 anywhere in a session means one thing: re-run auth. `branchId` specifically can't be read from the login response — it has to be decoded out of the JWT payload, which trips people up.

## Where it lives

- [scripts/auth.sh](../../../scripts/auth.sh) — does the two logins + table lookup, echoes exports for `eval`
- Decode snippet (works for either token):
  ```bash
  python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); print(json.dumps(json.loads(base64.b64decode(p)), indent=2))" "$PARTNER_TOKEN"
  ```
- Partner JWT: `{partnerId, accountId, branchId, userType:"restaurant-partner", role, iat, exp}`
- Diner JWT: `{_id, userType:"diner", role:"diner", iat, exp}`

## Related

- [Auth & Security](../modules/auth-security.md)
- [Known Test Data](./known-test-data.md) — the `branchId` mismatch between scripts
