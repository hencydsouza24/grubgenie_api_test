# Advanced Flows & Order Management

This reference covers order approval/rejection, variant selection, success pages, and POS configuration edge cases.

## Order Approval/Rejection Flow

**STATUS**: ✅ **Fully Implemented** (Manual acceptance mode)

Requires branch `orderAcceptanceMode: "manual"`. When enabled, placed orders land in `pending_acceptance` instead of going straight to `preparing`.

### Setup: Enable Manual Approval

```bash
curl -X PUT http://localhost:3000/v1/partner/branch/update-branch/3XSJT \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"orderAcceptanceMode":"manual"}'
```

### Flow: Place → Approve → Pay

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"
export CART_ID=$(bash $SKILL/create_cart.sh)
bash $SKILL/order_item.sh 691bf10018f1d3c34db1db00 2

# Order placed → pending_acceptance state
ORDER_ID=$(curl -s -X POST "http://localhost:3000/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"itemId":"691bf10018f1d3c34db1db00","quantity":2}]}' | jq -r '.result.currentActiveOrder')

# Place order (stays in pending_acceptance)
curl -X PUT "http://localhost:3000/v1/genie/order/place-order/$ORDER_ID?cartId=$CART_ID" \
  -H "Authorization: Bearer $DINER_TOKEN"
# Response: "Order submitted for approval"

# Partner: Accept with optional modifications
curl -X PATCH "http://localhost:3000/v1/partner/order-history/respond/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "accept",
    "modifications": [
      {"itemId": "691bf10018f1d3c34db1db00", "quantity": 2}
    ]
  }'

# Now diner can proceed to payment
curl -X POST "http://localhost:3000/v1/genie/cart/$CART_ID/payment/pay-in-person" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"dinerId\":\"$DINER_ID\"}"
```

### Reject Flow

```bash
curl -X PATCH "http://localhost:3000/v1/partner/order-history/respond/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "reject",
    "rejectionReason": "Item out of stock"
  }'
# Response: Order moves to rejected; currentActiveOrder in cart is cleared
```

### Validation Rules

| Field | Rule |
|-------|------|
| `action` | Required: `"accept"` or `"reject"` |
| `rejectionReason` | Required if `action=reject`; forbidden if `action=accept` |
| `modifications` | Allowed only if `action=accept`; sending with `reject` → 400 |
| Modification item | Must have exactly one: `itemId` OR `comboId`; `quantity` ≥ 1 |

### Edge Cases

| Scenario | Response |
|----------|----------|
| Diner token on partner endpoint | 403 (not 404 — auth correctly blocks) |
| Order not in `pending_acceptance` | 404 "Order not found or not pending acceptance" |
| `modifications` sent with `action=reject` | 400 validation error |
| `rejectionReason` missing on reject | 400 validation error |

### Socket Events (Side Effects)

- **On accept**: `cartUpdate` to diner, `orderUpdate` + `tableUpdate` to partner
- **On reject**: Same events; `currentActiveOrder` in cart cleared

---

## Variant Selection in Orders

**STATUS**: ✅ **Fully Implemented**

Menu items can have multiple variants (sizes, options). Variants are selected at order time with pricing.

### Create Item with Variants

```bash
curl -X POST "http://localhost:3000/v1/partner/menu" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Pizza",
    "category": "Main Course",
    "image": "pizza.jpg",
    "description": "Delicious pizza",
    "oPrice": 250,
    "variants": [
      {"name": "Small", "oPrice": 200, "dPrice": 180, "isActive": true},
      {"name": "Large", "oPrice": 350, "dPrice": 300, "isActive": true}
    ]
  }'
```

### Order with Variant Selection

```bash
ITEM_ID="691bf10018f1d3c34db1db00"
VARIANT_ID="variant_id_from_item"

curl -X POST "http://localhost:3000/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "items": [
      {
        "itemId": "'$ITEM_ID'",
        "quantity": 2,
        "variant": {"variantId": "'$VARIANT_ID'"}
      }
    ]
  }'
```

### Response: Variant in Pricing

```json
{
  "result": {
    "currentActiveOrder": "order_id",
    "orderDetails": [
      {
        "itemId": "691bf10018f1d3c34db1db00",
        "itemName": "Pizza (Large)",
        "quantity": 2,
        "oPrice": 350,
        "variant": {
          "variantId": "variant_id",
          "name": "Large",
          "oPrice": 350
        }
      }
    ]
  }
}
```

### How It Works

1. **Variant Lookup**: Service finds variant in `item.variants[]` by `variantId`
2. **Price Override**: Uses `variant.oPrice` instead of item base price
3. **Display Name**: Shows `"Pizza (Large)"` with variant name
4. **Validation**: Inactive variants → 400 error (not 500)

---

## Success Page APIs (After Payment)

**STATUS**: ✅ **Ready to Implement**

Once payment completes, use these APIs to build order confirmation/receipt page.

### Get Order Details (Receipt Data)

```bash
curl -s "http://localhost:3000/v1/partner/order-history/details/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '{
    orderNumber: .result.orderNumber,
    orderStatus: .result.orderStatus,
    totalOrderValue: .result.totalOrderValue,
    currency: .result.currency,
    createdAt: .result.createdAt,
    items: .result.orderDetails[]
  }'
```

### Get Cart Status (Payment Summary)

```bash
curl -s "http://localhost:3000/v1/genie/cart/$CART_ID?tableId=$TABLE_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '{
    status: .result.status,
    paymentMode: .result.paymentMode,
    payment_status: .result.payment_status,
    cartSubTotal: .result.cartSubTotal,
    completeCartTotal: .result.completeCartTotal,
    closedAt: .result.closedAt,
    orders: .result.orders[]
  }'
```

### Success Page Data Structure

```json
{
  "header": {
    "title": "Order Confirmed!",
    "orderNumber": "DN-3XSJT-1-00102"
  },
  "summary": {
    "status": "payment_done",
    "paymentMethod": "cash",
    "totalPaid": 24,
    "currency": "aed"
  },
  "receipt": {
    "items": [
      {
        "name": "Ulli Vada (2 Pcs)",
        "quantity": 2,
        "price": 12,
        "total": 24
      }
    ],
    "subtotal": 24,
    "serviceFee": 0,
    "total": 24
  },
  "timestamps": {
    "orderPlaced": "2026-05-12T08:38:42.660Z",
    "paymentCompleted": "2026-05-12T08:38:44.537Z"
  }
}
```

### Test Success Page Flow

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh 2>/dev/null)"

# Run complete E2E
bash $SKILL/flow_dine_in_pay.sh 691bf10018f1d3c34db1db00 2

# Extract order ID from output (script prints "Order: <order_id>")
# Then build success page from receipt + cart APIs
curl -s "http://localhost:3000/v1/partner/order-history/details/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result | {orderNumber, totalOrderValue, orderStatus, createdAt}'
```

---

## POS Configuration Edge Cases

**STATUS**: ✅ **Fully Tested**

Branch POS config is managed via **dedicated endpoints**, NOT through `add-branch` or `update-branch`.

### Dedicated POS Endpoints

| Method | Route | Permission | Purpose |
|--------|-------|-----------|---------|
| GET | `/v1/partner/branch/pos-config` | `getBranchPosConfig` | List POS configs (with credentials) |
| PUT | `/v1/partner/branch/pos-config` | `upsertBranchPosConfig` | Create/update a provider config |
| DELETE | `/v1/partner/branch/pos-config/:provider` | `deleteBranchPosConfig` | Remove a provider config |

### Upsert (PUT) Request

```bash
curl -s -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "petpooja",
    "isEnabled": true,
    "credentials": {
      "appKey": "your_app_key",
      "appSecret": "your_app_secret",
      "accessToken": "your_access_token",
      "restId": "your_restaurant_id"
    }
  }' | jq '.message'
```

### Delete (204 No Content)

```bash
curl -s -w "\nHTTP %{http_code}\n" -X DELETE \
  "http://localhost:3000/v1/partner/branch/pos-config/petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
# Returns: HTTP 204 (empty body, idempotent)
```

### Validation Rules

| Rule | Details |
|------|---------|
| provider | Required, valid: `'petpooja'` only |
| credentials.appKey | Required string |
| credentials.appSecret | Required string |
| credentials.accessToken | Required string |
| credentials.restId | Required string |
| Upsert | Merges by provider — updating petpooja preserves other providers |
| Duplicate prevention | Enforced at Joi, Mongoose, and service layers |
| Security | Credentials hidden from diner APIs via `select: false` on schema |

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Missing required field | 400 validation error |
| Invalid provider | 400 validation error |
| DELETE non-existent provider | 204 (idempotent) |
| Diner calls endpoint | 403 (permission denied) |

### Quick Setup via Script

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

# Enable POS (uses test credentials from script)
bash $SKILL/branch_pos_config.sh setup

# View POS config
bash $SKILL/branch_pos_config.sh get

# Disable POS
bash $SKILL/branch_pos_config.sh disable
```

---

## Implementation Notes

- All flows tested and verified on `feature/petpooja` branch
- Order approval requires `dineIn` subscription type
- Variant pricing overrides base item price in all calculations
- POS config endpoints are multi-provider ready; Petpooja is first provider
