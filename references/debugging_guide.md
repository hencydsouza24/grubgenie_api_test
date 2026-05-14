# Debugging Guide

Troubleshoot common errors and edge cases. For complex workflows, use context-mode patterns.

## Common Errors

### 401 Unauthorized

**Cause**: Token expired or invalid
**Fix**: Re-run auth
```bash
eval "$(bash $SKILL/auth.sh)"
```

### 403 Forbidden

| Scenario | Fix |
|----------|-----|
| Diner token on partner route | Expected — diner role lacks permission |
| Partner token on diner route | Check `token.middleware.ts` — user type mismatch |
| Missing permission | Check RBAC in `src/config/roles.ts` |

### 404 Not Found

| Scenario | Fix |
|----------|-----|
| Order not found | Use `result.currentActiveOrder` from order response, not `result._id` |
| "Order not found or not pending acceptance" | Order is not in manual approval flow — check `orderAcceptanceMode: "manual"` on branch |
| Diner gets 404 on partner route (unexpected) | `token.middleware.ts` fallback: ensure `user._id?.toString()` is used, not `user.id` |

### 400 Bad Request

| Error | Cause | Fix |
|-------|-------|-----|
| "cartId is required" | Using body params instead of query | Use `?cartId=:cartId&dinerId=:dinerId` as query params |
| "Item not found" | Invalid itemId | Use `bash $SKILL/fetch_menu.sh items` to get valid IDs |
| "modifications not allowed with reject" | Sending modifications array on reject | Use `rejectionReason` instead |
| "rejectionReason required" | Missing reason on reject | Add `"rejectionReason": "reason"` |
| "Invalid variant" | Variant inactive or doesn't exist | Fetch item first, check `variants[].isActive` |

### Payment Blocked

**Message**: "Cannot initiate payment while orders are pending acceptance"

**Cause**: Order in `pending_acceptance` state

**Fix**: Partner must accept/reject all pending orders first
```bash
curl -X PATCH http://localhost:3000/v1/partner/order-history/respond/$ORDER_ID \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"action":"accept"}'
```

Then diner can initiate payment.

---

## Known Edge Cases

### Cart Conflict

**Problem**: "Table already has an active cart"

**Cause**: Previous session left cart open

**Fix**: Use different table or reset
```bash
bash $SKILL/reset_tables.sh
```

### Order Not Placed

**Problem**: Can't proceed to payment

**Cause**: Must call `place-order` before `payment/initiate`

**Flow:**
```
1. POST /v1/genie/order (create) → response.currentActiveOrder
2. PUT /v1/genie/order/place-order/:orderId (lock order)
3. POST /v1/genie/cart/:cartId/payment/initiate (create PaymentIntent)
```

### Redis Cache Stale

**Problem**: Menu items showing old data

**Test**: Check cache
```bash
curl -s http://localhost:3000/v1/test/cache
```

**Bypass**: Restart server or wait for TTL

### branchId Decoding

**Problem**: Don't know branchId for JWT

**Extract**: Decode partner token
```bash
python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); print(json.loads(base64.b64decode(p)))" "$PARTNER_TOKEN"
```

**Known**: munch2 branchId is `3XSJT`

### Unicode/JSON Parse Error

**Problem**: "Invalid JSON" when parsing response with unicode

**Cause**: Control chars in shell substitution

**Fix**: Use file instead
```bash
curl -s http://localhost:3000/... -o /tmp/resp.json
cat /tmp/resp.json | python3 -c "import sys, json; d=json.load(sys.stdin); print(d)"
```

Or use context-mode sandbox (preferred for large responses):
```bash
mcp_context_mode_ctx_execute(
  language: "shell",
  code: "curl -s http://localhost:3000/... | jq '.result'"
)
```

### Server Not Hot-Reloading

**Problem**: `tsx watch` stalls

**Fix**: Kill and restart
```bash
lsof -ti:3000 | xargs kill -9
npm run dev
```

---

## Context-Mode Patterns

Use context-mode for large API responses and complex workflows.

### Pattern 1: Fetch + Search (Minimal Context)

For large partner info (posConfig, branches, menu):
```bash
# Batch fetch auth + partner info
mcp_context_mode_ctx_batch_execute(
  commands: [
    "bash $SKILL/auth.sh",
    "curl -s http://localhost:3000/v1/partner/info -H 'Authorization: Bearer $PARTNER_TOKEN' | jq '.result'"
  ],
  queries: ["branchId", "posConfig", "branches"]
)

# Step 2: Search indexed results
mcp_context_mode_ctx_search(queries: [
  "what is the posConfig",
  "list all branch IDs",
  "show Petpooja credentials"
])
```

**Benefit**: Raw 35KB response never enters context. Only search summaries shown.

### Pattern 2: Process Large Response Without Context Bloat

For menu fetches (100+ items):
```bash
mcp_context_mode_ctx_execute(
  language: "shell",
  code: """
    SKILL=/path/to/grubgenie-api-test/scripts
    eval "$(bash $SKILL/auth.sh 2>/dev/null)"
    curl -s http://localhost:3000/v1/genie/menu?branchId=3XSJT \\
      -H "Authorization: Bearer $DINER_TOKEN" | python3 -c "import sys, json; d=json.load(sys.stdin); items=d.get('result', []); print(f'Found {len(items)} items'); print('\\n'.join(f'{i[\"name\"]}: {i[\"_id\"]}' for i in items[:10]))"
  """
)
```

**Benefit**: Only summary enters context, full response in sandbox.

### Pattern 3: Multi-Step Flow

For order approval chains:
```bash
mcp_context_mode_ctx_execute(
  language: "shell",
  code: """
    SKILL=/path/to/grubgenie-api-test/scripts
    eval "$(bash $SKILL/auth.sh 2>/dev/null)"
    export CART_ID=$(bash $SKILL/create_cart.sh)
    bash $SKILL/order_item.sh 691bf10018f1d3c34db1db00 2
    bash $SKILL/flow_dine_in_pay.sh
    # Output: Order: <id>, Cart: <id>, Status: <status>
  """
)
```

**Benefit**: Multi-step flow in isolated sandbox, only final output in context.

---

## Testing Checklist

Before committing API changes:

- [ ] Auth (partner + diner) working
- [ ] Token extraction from responses
- [ ] Cart CRUD (create, get, update)
- [ ] Order CRUD (create, place, clear)
- [ ] Menu fetch (items, categories)
- [ ] POS config CRUD (get, put, delete)
- [ ] Order approval flow (if `orderAcceptanceMode: manual`)
- [ ] Variant selection (if variants exist)
- [ ] Payment (pay-in-person, Stripe)
- [ ] Error responses (401, 403, 400, 404)
- [ ] Scripts still work after changes

## Performance Tips

- Use context-mode for responses > 10KB
- Cache menu data (Redis TTL: 1 hour)
- Batch auth calls (both users in one eval)
- Reuse tokens until 401
- Use `jq` for response filtering (faster than python)
