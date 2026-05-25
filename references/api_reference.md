# GrubGenie API Reference

Base URL: `http://localhost:3000`

## Test Credentials

| Role | Value |
|------|-------|
| Partner email | `munchuser@yopmail.com` |
| Partner password | `Test@123` |
| Partner customDomain | `munch2` |
| Partner branchId | `3XSJT` (in JWT payload) |
| Diner fingerprint | `grubgenie-stripe-test-002` |
| Admin email | `hello@grubgenie.ai` |
| Admin password | `$$grubgod123` |
| **Petpooja appKey** | **xz8swugh0vp9oymdab2tkne1qr5c3i67** |
| **Petpooja restId** | **i4fwyk7e** |

## Known Test Data (munch2 tenant)

| Item | ID | Notes |
|------|----|-------|
| Snack Combo | `69f8757fd475a8cf66ed94f2` | 24 AED, active |
| Ulli Vada (menu item, no variant) | `691bf10018f1d3c34db1db00` | 12 AED |
| Existing diner | `69f89034e0a784fea33a0d12` | fingerprint: grubgenie-stripe-test-002 |

## Token Extraction Patterns

```bash
# Partner login → accessToken
PARTNER_TOKEN=$(curl -s -X POST http://localhost:3000/v1/partner/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"munchuser@yopmail.com","password":"Test@123"}' | jq -r '.result.accessToken')

# Diner auth → accessToken + dinerId
DINER_RESPONSE=$(curl -s "http://localhost:3000/v1/genie/diner?customDomain=munch2&branchId=3XSJT&fingerprint=grubgenie-stripe-test-002")
DINER_TOKEN=$(echo $DINER_RESPONSE | jq -r '.result.accessToken')
DINER_ID=$(echo $DINER_RESPONSE | jq -r '.result._id')

# Decode JWT branchId from partner token
python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); print(json.dumps(json.loads(base64.b64decode(p)), indent=2))" "$PARTNER_TOKEN"
```

## Route Map

### Auth Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/v1/partner/auth/signin` | None | body: `{email, password}` → `result.accessToken` |
| GET | `/v1/partner/auth/details` | Bearer partner | get partner info |
| POST | `/v1/partner/auth/refresh` | None | body: `{refreshToken}` |
| POST | `/v1/partner/auth/signup` | None | new partner signup |
| GET | `/v1/genie/diner` | None | query: `customDomain, branchId, fingerprint` → `result.accessToken`, `result.diner._id` |
| POST | `/v1/genie/diner/refresh-token` | None | body: `{refreshToken}` |
| POST | `/v1/admin/auth/signin` | None | body: `{email, password}` |

### Diner Flow Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/genie/menu` | Bearer diner | query: `branchId` |
| GET | `/v1/genie/menu/food-category` | Bearer diner | |
| GET | `/v1/genie/menu/restaurant-info` | Bearer diner | |
| GET | `/v1/genie/menu/offers` | Bearer diner | |
| GET | `/v1/genie/menu/allergens` | Bearer diner | |
| GET | `/v1/genie/menu/dietary-preference` | Bearer diner | |
| GET | `/v1/genie/menu/food-type` | Bearer diner | |
| GET | `/v1/genie/menu/item-by-id` | Bearer diner | query: `ids[]` (array of objectIds) |
| GET | `/v1/genie/menu/item-by-media-id` | Bearer diner | query: `mediaId` |
| GET | `/v1/genie/menu/reels` | Bearer diner | |
| GET | `/v1/genie/menu/stories` | Bearer diner | |
| POST | `/v1/genie/cart` | Bearer diner | body: `{tableId}` → `result.cartId` |
| GET | `/v1/genie/cart/:cartId` | Bearer diner | query: `tableId, dinerId` |
| PUT | `/v1/genie/cart/:cartId/update-diner-count` | Bearer diner | body: `{count:N}` |
| POST | `/v1/genie/order` | Bearer diner | query: `?cartId=:cartId&dinerId=:dinerId`; body: `{items:[{itemId,quantity}]}` — for menu items; body: `{items:[{comboId,quantity}]}` — for combos |
| PUT | `/v1/genie/order/place-order/:orderId` | Bearer diner | query: `?cartId=:cartId` — locks the order |
| PUT | `/v1/genie/order/:orderId` | Bearer diner | query: `?cartId=:cartId&dinerId=:dinerId`; body: `{items:[...]}` — update order |
| PUT | `/v1/genie/order/clear-order/:orderId` | Bearer diner | query: `?cartId=:cartId`; body: `{items:[...]}` |
| GET | `/v1/genie/order-history` | Bearer diner | |
| POST | `/v1/genie/cart/:cartId/payment/initiate` | Bearer diner | creates Stripe PaymentIntent → `result.clientSecret` |
| POST | `/v1/genie/cart/:cartId/payment/pay-in-person` | Bearer diner | body: `{dinerId}` — cash payment |
| POST | `/v1/genie/cart/:cartId/payment/cancel` | Bearer diner | body: `{paymentIntentId}` — cancel Stripe |
| POST | `/v1/genie/cart/:cartId/splits/create-intent` | Bearer diner | |
| POST | `/v1/genie/cart/:cartId/splits/initiate` | Bearer diner | body: `{splitType:"split-amount"}` |
| PUT | `/v1/genie/cart/:cartId/splits/cancel` | Bearer diner | |
| GET | `/v1/genie/cart/success/:cartId` | Bearer diner | check post-payment state |
| PUT | `/v1/genie/rating` | Bearer diner | body: `{cartId, items:[{itemId,liked}]}` |
| GET | `/v1/genie/qr-code/:code` | Bearer diner | |
| POST | `/v1/genie/order/get-receipt-by-email` | Bearer diner | body: `{email, receiptURL, restaurantName}` |

### Partner Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/partner/info/` | Bearer partner | get partner info |
| GET | `/v1/partner/info/brief` | Bearer partner | |
| PUT | `/v1/partner/info/:id` | Bearer partner | update partner info |
| PUT | `/v1/partner/info/currency` | Bearer partner | body: `{currency}` |
| GET | `/v1/partner/branch` | Bearer partner | list branches |
| GET | `/v1/partner/branch/rights` | Bearer partner | |
| POST | `/v1/partner/branch/switch-branch` | Bearer partner | body: `{branchId}` |
| POST | `/v1/partner/branch/add-branch` | Bearer partner | body: full branch data with validations (see schema below) |
| PUT | `/v1/partner/branch/update-branch/:branchId` | Bearer partner | body: partial branch data with validations (see schema below) |
| GET | `/v1/partner/branch/pos-config` | Bearer partner | Get POS config with credentials |
| PUT | `/v1/partner/branch/pos-config` | Bearer partner | Upsert POS provider config; body: `{provider, isEnabled, credentials:{...}}` |
| DELETE | `/v1/partner/branch/pos-config/:provider` | Bearer partner | Remove POS provider config; returns 204 |
| POST | `/v1/partner/branch/migrate-menu` | Bearer partner | body: `{sourceBranch, targetBranch}` |
| GET | `/v1/partner/branch/users` | Bearer partner | |
| POST | `/v1/partner/branch/invite-users/:branchId` | Bearer partner | body: `{emails:[...]}` |
| GET | `/v1/partner/table` | Bearer partner | list tables |
| POST | `/v1/partner/table` | Bearer partner | body: `{tableSequence, numberOfSeats}` |
| DELETE | `/v1/partner/table/:tableId` | Bearer partner | |
| PUT | `/v1/partner/table/:tableId` | Bearer partner | body: `{numberOfSeats}` |
| PUT | `/v1/partner/table/table-status/:tableId` | Bearer partner | |
| GET | `/v1/partner/menu` | Bearer partner | list menu items |
| GET | `/v1/partner/menu/search` | Bearer partner | query: `q` |
| POST | `/v1/partner/menu` | Bearer partner | create menu item |
| GET | `/v1/partner/menu/:itemId` | Bearer partner | |
| PUT | `/v1/partner/menu/:itemId` | Bearer partner | update menu item |
| DELETE | `/v1/partner/menu/:itemId` | Bearer partner | |
| GET | `/v1/partner/menu/get-customizations/:itemId` | Bearer partner | |
| GET | `/v1/partner/menu/category/:categoryId` | Bearer partner | items by category |
| GET | `/v1/partner/combo` | Bearer partner | list combos |
| GET | `/v1/partner/food-category` | Bearer partner | |
| POST | `/v1/partner/food-category` | Bearer partner | body: `{food_category}` |
| GET | `/v1/partner/food-category/count` | Bearer partner | |
| PUT | `/v1/partner/food-category/category-sequence` | Bearer partner | body: `{categories:[{_id,sequence}]}` |
| GET | `/v1/partner/food-type` | Bearer partner | |
| POST | `/v1/partner/food-type` | Bearer partner | body: `{food_type, locales:{ar:...}}` |
| GET | `/v1/partner/order-history` | Bearer partner | |
| GET | `/v1/partner/order-history/details/:orderId` | Bearer partner | |
| GET | `/v1/partner/order-history/search` | Bearer partner | |
| PUT | `/v1/partner/order-history/update-status/:orderId` | Bearer partner | body: `{orderStatus:"preparing"}` |
| PUT | `/v1/partner/order-history/update-payment-status/:orderId` | Bearer partner | body: `{paymentStatus:"done",paymentMode:"card",confirmed:true}` |
| PUT | `/v1/partner/order-history/mark-completed/:orderId` | Bearer partner | |
| PATCH | `/v1/partner/order-history/respond/:orderId` | Bearer partner | body: `{action:"accept"\|"reject", rejectionReason?:string, modifications?:[...]}` — accept/reject placed orders |
| GET | `/v1/partner/notification` | Bearer partner | |
| PUT | `/v1/partner/notification/read-all` | Bearer partner | |
| PUT | `/v1/partner/notification/:notifId` | Bearer partner | body: `{isRead:false}` |
| GET | `/v1/partner/insights/order-performance` | Bearer partner | |
| GET | `/v1/partner/insights/menu-performance` | Bearer partner | |
| GET | `/v1/partner/insights/revenue` | Bearer partner | |
| GET | `/v1/partner/insights/customer` | Bearer partner | |
| GET | `/v1/partner/meta/instagram/media` | Bearer partner | list Instagram media |
| GET | `/v1/partner/meta/instagram/media/bulk` | Bearer partner | bulk fetch media |
| GET | `/v1/partner/offer` | Bearer partner | |
| POST | `/v1/partner/offer` | Bearer partner | |
| GET | `/v1/partner/subscription/plans` | Bearer partner | |
| POST | `/v1/partner/subscription/create-subscription` | Bearer partner | body: `{planName}` |
| POST | `/v1/partner/subscription/cancel-subscription` | Bearer partner | body: `{subscriptionId, resubscribe, immediateCancellation}` |
| GET | `/v1/partner/gpt` | Bearer partner | |

### Admin Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/v1/admin/auth/signin` | None | body: `{email, password}` |
| POST | `/v1/admin/auth/signin` | None | body: `{email, password}` |
| GET | `/v1/admin/config` | Bearer admin | list configs |
| POST | `/v1/admin/config` | Bearer admin | body: `{name, value}` |
| GET | `/v1/admin/config/:name` | Bearer admin | single config by name |
| PUT | `/v1/admin/config/:name` | Bearer admin | body: `{value:{...}}` |
| DELETE | `/v1/admin/config/:name` | Bearer admin | |
| GET | `/v1/admin/establishment` | Bearer admin | |
| POST | `/v1/admin/establishment` | Bearer admin | |
| GET | `/v1/admin/establishment/:establishmentId` | Bearer admin | |
| PUT | `/v1/admin/establishment/:establishmentId` | Bearer admin | |
| DELETE | `/v1/admin/establishment/:establishmentId` | Bearer admin | |
| GET | `/v1/admin/cuisine` | Bearer admin | |
| POST | `/v1/admin/cuisine` | Bearer admin | body: `{cuisine_type}` |
| GET | `/v1/admin/cuisine/:cuisineId` | Bearer admin | |
| PUT | `/v1/admin/cuisine/:cuisineId` | Bearer admin | |
| DELETE | `/v1/admin/cuisine/:cuisineId` | Bearer admin | |
| GET | `/v1/admin/service` | Bearer admin | |
| POST | `/v1/admin/service` | Bearer admin | body: `{service_type}` |
| GET | `/v1/admin/service/:serviceId` | Bearer admin | |
| PUT | `/v1/admin/service/:serviceId` | Bearer admin | |
| DELETE | `/v1/admin/service/:serviceId` | Bearer admin | |
| GET | `/v1/admin/plan` | Bearer admin | |
| POST | `/v1/admin/plan` | Bearer admin | |
| GET | `/v1/admin/qr-code` | Bearer admin | |
| POST | `/v1/admin/qr-code` | Bearer admin | |
| POST | `/v1/admin/migration` | Bearer admin | run DB migrations |
| GET | `/v1/admin/migration` | Bearer admin | list migrations |
| PUT | `/v1/admin/migration/:migrationId` | Bearer admin | |
| DELETE | `/v1/admin/migration/:migrationId` | Bearer admin | |
| POST | `/v1/admin/onboarding/create-session` | Bearer admin | |
| GET | `/v1/feature-flags` | Bearer admin | |
| POST | `/v1/feature-flags` | Bearer admin | body: `{name, enabled, environment:{local,production}}` |
| GET | `/v1/feature-flags/name/:featureFlagName` | Bearer admin | lookup by name |
| GET | `/v1/feature-flags/:featureFlagId` | Bearer admin | |
| PUT | `/v1/feature-flags/:featureFlagId` | Bearer admin | |
| DELETE | `/v1/feature-flags/:featureFlagId` | Bearer admin | |
| GET | `/v1/prompt` | Bearer admin | list prompts |
| POST | `/v1/prompt` | Bearer admin | body: `{name, content}` |
| GET | `/v1/prompt/:promptId` | Bearer admin | |
| PUT | `/v1/prompt/:promptId` | Bearer admin | |
| DELETE | `/v1/prompt/:promptId` | Bearer admin | |

### Agent / Recommendation Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/v1/test/agent-chat/:dinerId` | None | body: `{message}` — test agent directly |
| POST | `/v1/test/send-sdui-event/:dinerId` | None | body: `{displayContext, componentId, props, trigger}` — fire `sdui-render` socket event to a specific diner (dev-only) |
| GET | `/v1/genie/recommendation/generate` | Bearer diner | query: `recommendationId` (required) |
| POST | `/v1/genie/recommendation/generate` | Bearer diner | body: `{hungerLevel,foodType,foodTypeScale,dietaryPreference,dinerCount,time,weather}` — see schema below |
| GET | `/v1/genie/recommendation/get-by-diner` | Bearer diner | |
| PUT | `/v1/genie/recommendation/interaction/:recId` | Bearer diner | |

**POST `/v1/genie/recommendation/generate` body schema (all fields required):**
```json
{
  "hungerLevel": 3,
  "foodType": "savory|sweet|spicy",
  "foodTypeScale": 3,
  "dietaryPreference": "vegetarian|non-vegetarian|vegan|hot-drink|cold-drink|halal",
  "dinerCount": 2,
  "time": "<ISO 8601 datetime>",
  "weather": "sunny"
}
```
Response: `{ _id, userId, context, recommendations: [{ name, description, items: [...full menu item objects with quantity] }] }`
Note: `type` and `timestamp` are NOT valid fields — omit them.
| POST | `/v1/genie/insights/track` | Bearer diner | body: `{event, properties}` |

### Agents Routes (AI agent mesh)

> **Note:** All `/agents/*` routes are mounted under `/v1/agents/`. These are internal agent-to-agent or backend routes, not diner-facing.

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/agents/menu` | Bearer | list menu items for agent context |
| GET | `/v1/agents/menu/food-category` | Bearer | food categories for agent |
| GET | `/v1/agents/menu/filter` | Bearer | filter menu items |
| GET | `/v1/agents/menu/:menuId` | Bearer | single menu item |
| GET | `/v1/agents/partner/:partnerId` | Bearer | partner info for agent |
| GET | `/v1/agents/diner/verify-diner` | Bearer | verify diner identity |

### AI Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/v1/ai/image/image-generate` | Bearer | body: `{prompt}` — generate image from text |

### Analytics Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/v1/analytics/track` | None | body: `{event, properties, userId}` |

### Webhook Routes (inbound, not for manual testing)

| Method | Route | Notes |
|--------|-------|-------|
| POST | `/webhooks/v1/stripe/diner-payment` | Stripe diner payment webhook |
| POST | `/webhooks/v1/stripe/partner-onboarding` | Stripe partner onboarding webhook |
| POST | `/webhooks/v1/stripe/subscription` | Stripe subscription webhook |
| POST | `/webhooks/v1/posthog/posthog-events` | PostHog event ingestion |

### SDUI Test Endpoint

`POST /v1/test/send-sdui-event/:dinerId` — fires an `sdui-render` socket event directly to a connected diner. Dev-only, no auth required.

**Body schema:**
```json
{
  "displayContext": "bottom_sheet | post_add | combo",
  "componentId": "ItemSpotlight | ComboCard",
  "props": { ... },
  "trigger": "menu_end_reached | add_to_cart | ..."
}
```

**ItemSpotlight props:**
```json
{ "title": "string", "reason": "string", "badge": "string | null" }
```

**Example — fire ItemSpotlight to a diner:**
```bash
eval "$(bash $SKILL/auth.sh)"

curl -s -X POST "$BASE/v1/test/send-sdui-event/$DINER_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "displayContext": "bottom_sheet",
    "componentId": "ItemSpotlight",
    "props": {
      "title": "Ulli Vada",
      "reason": "Popular at this time of day",
      "badge": "Chef'\''s Pick"
    },
    "trigger": "menu_end_reached"
  }' | jq .
```

**SDUIPayload shape emitted on socket (`sdui-render` event):**
```json
{
  "spec": {
    "root": "spotlight",
    "elements": {
      "spotlight": { "type": "ItemSpotlight", "props": { ... } }
    }
  },
  "trigger": "menu_end_reached",
  "displayContext": "bottom_sheet",
  "componentId": "ItemSpotlight",
  "timestamp": "<ISO 8601>"
}
```

**Use with socket-listener:** Run `bash scripts/listen.sh dev` in `grubgenie_agent_prompts/` to watch the `sdui-render` event live.

---

### Debug / Test Routes

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/debug/memory` | None | memory usage |
| GET | `/v1/debug/connections` | None | active DB connections |
| GET | `/v1/debug/heap-stats` | None | heap stats |
| GET | `/v1/debug/active-handles` | None | active handles |
| POST | `/v1/debug/gc` | None | force GC |
| GET | `/v1/test/cache` | None | test Redis cache |
| GET | `/v1/test/error` | None | test error handler |
| GET | `/v1/test/auth-test` | Bearer | test auth middleware |

## Branch API Schemas (Create & Update)

### POST `/v1/partner/branch/add-branch` — Create Branch

Full body schema with complete validations:

```json
{
  "branchName": "string (2-100 chars)",
  "logoURL": "string (valid URI)",
  "bannerURL": "string (valid URI, optional)",
  "restaurantPhotos": [
    {
      "url": "string (valid URI)"
    }
  ],
  "deliveryRadius": "string (optional)",
  "deliveryFee": "string (optional)",
  "deliveryTime": "string (optional)",
  "establishmentType": ["string (required)"],
  "serviceType": ["string (required)"],
  "cuisineType": ["string (required)"],
  "dineInPayment": "boolean (required)",
  "orderAcceptanceMode": "string (valid: 'automatic', 'manual', optional)",
  "workingHours": [
    {
      "day": "string (required)",
      "isClosed": "boolean (required)",
      "schedule": [
        {
          "fromTime": "string (required when isClosed=false)",
          "toTime": "string (required when isClosed=false)"
        }
      ]
    }
  ],
  "description": "string (3-500 chars, required)",
  "locationURL": {
    "url": "string (valid URI, required)",
    "lat": "string (required)",
    "long": "string (required)",
    "placeId": "string (optional, allow empty)",
    "placeName": "string (optional, allow empty)"
  },
  "address": {
    "addressLine1": "string (required)",
    "addressLine2": "string (optional)",
    "city": "string (required)",
    "state": "string (required)",
    "zip": "string (optional, allow empty)",
    "country": "string (required)"
  },
  "instagramURL": "string (optional)",
  "googleBusinessURL": "string (optional)",
  "facebookURL": "string (optional)",
  "youtubeURL": "string (optional)",
  "zomatoURL": "string (optional)"
}
```

> **Note:** `posConfig` is NOT part of the branch create/update schema. Use dedicated POS endpoints instead:
> `GET/PUT /v1/partner/branch/pos-config`, `DELETE /v1/partner/branch/pos-config/:provider`

### PUT `/v1/partner/branch/update-branch/:branchId` — Update Branch

All fields optional (same schema as create, all fields become optional for update).

**Key validation rules:**
- `branchName`: 2-100 characters
- `description`: 3-500 characters  
- URLs must be valid URIs (logoURL, bannerURL, etc.)
- `workingHours[].schedule`: empty array when `isClosed=true`; must have `fromTime`/`toTime` when `isClosed=false`
- `orderAcceptanceMode`: valid values are `'automatic'` | `'manual'`
- `posConfig` is **NOT** allowed in this schema -- use dedicated `/pos-config` endpoints
- Modify `orderAcceptanceMode` to `'manual'` to enable order approval flow (see Order Approval/Rejection section)

### POS Configuration (Dedicated Endpoints)

POS config is managed via dedicated endpoints, NOT through branch create/update.

**Endpoints:**
- `GET /v1/partner/branch/pos-config` -- list POS configs (with credentials for partner)
- `PUT /v1/partner/branch/pos-config` -- upsert provider config
- `DELETE /v1/partner/branch/pos-config/:provider` -- remove provider (204 No Content)

**PUT body (single provider object, NOT array):**
```json
{
  "provider": "petpooja",
  "isEnabled": true,
  "credentials": {
    "appKey": "YOUR_PETPOOJA_APP_KEY",
    "appSecret": "YOUR_PETPOOJA_APP_SECRET",
    "accessToken": "YOUR_PETPOOJA_ACCESS_TOKEN",
    "restId": "YOUR_PETPOOJA_RESTAURANT_ID"
  }
}
```

**Validation:** Provider must be `petpooja` (enum). All 4 credential fields required for petpooja.
**Security:** Credentials use `select: false` in Mongoose. Partner endpoints explicitly select credentials; diner APIs never expose them.
**Merge behavior:** Upsert merges by provider key -- updating petpooja preserves other providers.

**Usage:**

Setup POS config:
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

Get POS config:
```bash
curl -s "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result'
```

Delete POS config:
```bash
curl -s -w "\nHTTP %{http_code}" -X DELETE \
  "http://localhost:3000/v1/partner/branch/pos-config/petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
# Returns: HTTP 204 (empty body)
```

## Key Business Rules

- **Cart**: Created per table session. One cart per active table.
- **Order**: Multiple orders per cart. Must call `place-order` before payment can be initiated.
- **Pay-in-person**: Sets `serviceFee=0`, `completeCartTotal=cartSubTotal` — cash skips service fee by design (`cart.service.ts` lines 493-497).
- **Stripe payment**: Amount in fils (×100). e.g. 72 AED subtotal + 5% service fee = 75.60 AED = 7560 fils.
- **Redis cache**: Combo + menu items cached. Cart, Order, Table — direct DB, no cache.
- **Partner token shape**: `result.accessToken` (NOT `result.tokens.access.token`).
- **branchId location**: In JWT payload, not in login response body. Decode with python3 snippet above.
- **Diner branchId**: Same as partner branchId for that tenant — `3XSJT` for munch2 tenant.
- **Cart status flow**: `open` → `payment_in_progress` → `payment_done` (Stripe) or direct → `payment_done` (pay-in-person).
- **Order status flow**: `pending` → `placed` (after place-order) → `pending_acceptance` (after partner responds, if accepted) → `preparing` → `ready` → `completed`. Rejected orders land in `rejected` status.
- **Payment blocked**: All payment routes (`payment/initiate`, `pay-in-person`, `splits/*`) throw 400 if any order in the cart has status `pending_acceptance`. Partner must respond to all pending orders first.
- **Order history visibility**: `getOrderHistory` and `getDinerOrderHistory` now include `pending_acceptance` and `rejected` orders (previously filtered out).

## Common curl Patterns

```bash
BASE=http://localhost:3000

# GET with Bearer token
curl -s -X GET $BASE/v1/partner/info/ \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq .

# POST with JSON body + auth
curl -s -X POST $BASE/v1/genie/order \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"itemId":"691bf10018f1d3c34db1db00","quantity":2}]}' | jq .

# PUT with query param
curl -s -X PUT "$BASE/v1/genie/order/place-order/$ORDER_ID?cartId=$CART_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq .

# Extract nested field
curl -s ... | jq -r '.result._id'
curl -s ... | jq -r '.result[0]._id'
```

## E2E Dine-In + Pay-In-Person Flow

```bash
BASE=http://localhost:3000

# 1. Partner login
PARTNER_TOKEN=$(curl -s -X POST $BASE/v1/partner/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"munchuser@yopmail.com","password":"Test@123"}' | jq -r '.result.accessToken')
echo "Partner token: ${PARTNER_TOKEN:0:20}..."

# 2. Get a table
TABLE_ID=$(curl -s $BASE/v1/partner/table \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq -r '.result[0]._id')
echo "Table ID: $TABLE_ID"

# 3. Diner auth
DINER_RESPONSE=$(curl -s "$BASE/v1/genie/diner?customDomain=munch2&branchId=3XSJT&fingerprint=grubgenie-stripe-test-002")
DINER_TOKEN=$(echo $DINER_RESPONSE | jq -r '.result.accessToken')
DINER_ID=$(echo $DINER_RESPONSE | jq -r '.result._id')
echo "Diner ID: $DINER_ID"

# 4. Create cart
CART_ID=$(curl -s -X POST $BASE/v1/genie/cart \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"tableId\":\"$TABLE_ID\"}" | jq -r '.result.cartId')
echo "Cart ID: $CART_ID"

# 5. Create order — cartId+dinerId as query params
ORDER_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"itemId":"691bf10018f1d3c34db1db00","quantity":2}]}')
ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.result.currentActiveOrder')
echo "Order ID: $ORDER_ID"

# 6. Place order
curl -s -X PUT "$BASE/v1/genie/order/place-order/$ORDER_ID?cartId=$CART_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '{status: .result.status}'

# 7. Pay in person
curl -s -X POST $BASE/v1/genie/cart/$CART_ID/payment/pay-in-person \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"dinerId\":\"$DINER_ID\"}" | jq '{payment_status: .result.payment_status, status: .result.status}'

# 8. Partner confirms payment (find order in order-history first)
HIST_ORDER_ID=$(curl -s $BASE/v1/partner/order-history \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq -r '.result[0]._id')
curl -s -X PUT $BASE/v1/partner/order-history/update-payment-status/$HIST_ORDER_ID \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"paymentStatus":"done","paymentMode":"cash","confirmed":true}' | jq .
```

## E2E Stripe Payment Flow

```bash
BASE=http://localhost:3000
# (steps 1-6 same as pay-in-person flow above)

# 7. Initiate Stripe payment
PAYMENT_RESPONSE=$(curl -s -X POST $BASE/v1/genie/cart/$CART_ID/payment/initiate \
  -H "Authorization: Bearer $DINER_TOKEN")
echo $PAYMENT_RESPONSE | jq '{clientSecret: .result.clientSecret, paymentIntentId: .result.paymentIntentId, amount: .result.amount}'

# 8. Check cart state (should be payment_in_progress)
curl -s "$BASE/v1/genie/cart/$CART_ID?tableId=$TABLE_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '{status: .result.status, payment_status: .result.payment_status}'

# 9. Cancel payment (if needed)
PAYMENT_INTENT_ID=$(echo $PAYMENT_RESPONSE | jq -r '.result.paymentIntentId')
curl -s -X POST $BASE/v1/genie/cart/$CART_ID/payment/cancel \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"paymentIntentId\":\"$PAYMENT_INTENT_ID\"}" | jq .
```

## Menu Fetching

Use `fetch_menu.sh` for all menu browsing. Requires `DINER_TOKEN` (diner-side routes) or `PARTNER_TOKEN` (partner-side routes).

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

# List all items (grouped by category)
bash $SKILL/fetch_menu.sh items

# Items in a specific category
bash $SKILL/fetch_menu.sh items <categoryId>

# List categories
bash $SKILL/fetch_menu.sh categories

# List food types
bash $SKILL/fetch_menu.sh food-types

# Restaurant info (name, logo, address)
bash $SKILL/fetch_menu.sh restaurant-info

# Restaurant branches — no auth needed
bash $SKILL/fetch_menu.sh branches munch2

# Single item by ID (partner token)
bash $SKILL/fetch_menu.sh item 691bf10018f1d3c34db1db00

# Search items by name (partner token)
bash $SKILL/fetch_menu.sh items-search "vada"

# All items via partner route (partner token)
bash $SKILL/fetch_menu.sh partner-items

# Dietary preferences and allergens
bash $SKILL/fetch_menu.sh dietary
bash $SKILL/fetch_menu.sh allergens

# Active offers
bash $SKILL/fetch_menu.sh offers
```

### Menu endpoint quick reference

| Endpoint | Auth | Key query params |
|----------|------|-----------------|
| `GET /v1/genie/menu` | diner | `foodCategoryId`, `query`, `foodTypeId`, `spicinessLevel`, `allergens`, `preferences`, `chefsChoice`, `limit`, `page` | Returns paginated flat array: `{result:[...], totalResults, totalPages, limit, page}`. Item fields: `item_name`, `oPrice`, `dPrice`, `foodCategoryId` |
| `GET /v1/genie/menu/food-category` | diner | `foodTypeId`, `allergens`, `preferences` |
| `GET /v1/genie/menu/food-type` | diner | — |
| `GET /v1/genie/menu/restaurant-info` | diner | `attachMedia` |
| `GET /v1/genie/menu/restaurant-branches/:customDomain` | none | — |
| `GET /v1/genie/menu/item-by-id` | diner | `ids[]` (array) |
| `GET /v1/genie/menu/dietary-preference` | diner | — |
| `GET /v1/genie/menu/allergens` | diner | — |
| `GET /v1/genie/menu/offers` | diner | — |
| `GET /v1/partner/menu/item` | partner | `page`, `limit` |
| `GET /v1/partner/menu/item/search` | partner | `q` |
| `GET /v1/partner/menu/item/:menuItemId` | partner | — |
| `GET /v1/partner/menu/item/category/:categoryId` | partner | — |

### Raw curl examples

```bash
BASE=http://localhost:3000

# All menu items — paginated flat array
curl -s "$BASE/v1/genie/menu" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '{total: .totalResults, pages: .totalPages, items: [.result[] | {_id, name: .item_name, price: .oPrice, category: .foodCategoryId}]}'

# Items in a category
curl -s "$BASE/v1/genie/menu?foodCategoryId=<categoryId>" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .item_name, price: .oPrice}'

# Search by text
curl -s "$BASE/v1/genie/menu?query=vada" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .item_name}'

# Fetch specific items by ID (ids as repeated query params)
curl -s "$BASE/v1/genie/menu/item-by-id?ids[]=691bf10018f1d3c34db1db00" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .itemName, price}'

# Partner: list all items
curl -s "$BASE/v1/partner/menu/item" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | {_id, name: .itemName, price, isActive}'

# Partner: search
curl -s "$BASE/v1/partner/menu/item/search?q=vada" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | {_id, name: .itemName}'
```

## E2E Order Approval/Rejection Flow

```bash
BASE=http://localhost:3000
# prereq: auth + create cart + create order + place order (steps 1-6 from pay-in-person flow)

# Accept order (no modifications)
curl -s -X PATCH "$BASE/v1/partner/order-history/respond/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"accept"}' | jq '{message: .message, status: .result.orderStatus}'

# Accept with quantity modification (itemId XOR comboId required per modification)
curl -s -X PATCH "$BASE/v1/partner/order-history/respond/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "accept",
    "modifications": [
      {"itemId": "691bf10018f1d3c34db1db00", "quantity": 1}
    ]
  }' | jq '{message: .message, status: .result.orderStatus}'

# Reject order (rejectionReason required; modifications FORBIDDEN)
curl -s -X PATCH "$BASE/v1/partner/order-history/respond/$ORDER_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"reject","rejectionReason":"Item out of stock"}' | jq '{message: .message, status: .result.orderStatus}'
```

**Request body schema:**
```json
{
  "action": "accept" | "reject",          // required
  "rejectionReason": "string",            // required if action=reject, optional if accept
  "modifications": [                       // optional if action=accept, FORBIDDEN if action=reject
    {
      "itemId": "objectId",               // XOR with comboId — exactly one required
      "comboId": "objectId",              // XOR with itemId
      "quantity": 1,                      // integer >= 1, optional
      "customization": [...]              // optional
    }
  ]
}
```

**Response:** `200 OK` — `result` is the updated order object. Message: `"Order accepted successfully"` or `"Order rejected successfully"`.
**Side effects:** Emits socket events — `cartUpdate` to diner's table, `orderUpdate` + `tableUpdate` to partner. On reject: `currentActiveOrder` in cart is cleared.

**Edge case HTTP responses (verified):**

| Scenario | Status | Body |
|----------|--------|------|
| Diner token used on this endpoint | 403 Forbidden | `{message:"Forbidden"}` — auth correctly blocks, NOT 404 |
| Order not in `pending_acceptance` state | 404 Not Found | `{message:"Order not found or not pending acceptance"}` |
| `modifications` sent with `action=reject` | 400 Bad Request | Joi validation error — `modifications` is forbidden on reject |
| `rejectionReason` missing when `action=reject` | 400 Bad Request | Joi validation error — `rejectionReason` is required on reject |
| Both `itemId` + `comboId` in one modification | 400 Bad Request | Joi XOR validation error |
| Neither `itemId` nor `comboId` in modification | 400 Bad Request | Joi XOR validation error |

**Prerequisite:** Branch must have `orderAcceptanceMode: "manual"` set, otherwise placed orders skip `pending_acceptance` and go straight to `preparing`.

```bash
# Enable manual approval on branch
curl -s -X PUT "$BASE/v1/partner/branch/update-branch/3XSJT" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"orderAcceptanceMode":"manual"}' | jq '.message'

# Disable (back to auto-accept)
curl -s -X PUT "$BASE/v1/partner/branch/update-branch/3XSJT" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"orderAcceptanceMode":"automatic"}' | jq '.message'
```

## Combo Fetching

Use `fetch_menu.sh` combo commands. Diner routes require `DINER_TOKEN`; partner routes require `PARTNER_TOKEN`.

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

# List all combos (diner)
bash $SKILL/fetch_menu.sh combos

# Single combo by ID (diner)
bash $SKILL/fetch_menu.sh combo 69f8757fd475a8cf66ed94f2

# List combos (partner — includes inactive)
bash $SKILL/fetch_menu.sh partner-combos

# Single combo (partner)
bash $SKILL/fetch_menu.sh partner-combo 69f8757fd475a8cf66ed94f2
```

### Combo endpoint quick reference

| Method | Endpoint | Auth | Query params | Notes |
|--------|----------|------|-------------|-------|
| GET | `/v1/genie/combo` | diner | `comboId`, `comboName`, `isActive`, `sortBy`, `limit`, `page` | List combos for branch |
| GET | `/v1/genie/combo/:comboId` | diner | — | Single combo detail |
| GET | `/v1/partner/combo` | partner | `comboId`, `comboName`, `isActive`, `sortBy`, `limit`, `page` | List combos (includes inactive) |
| GET | `/v1/partner/combo/:comboId` | partner | — | Single combo detail |
| POST | `/v1/partner/combo` | partner | — | body: `{comboName, description?, items:[{menuItemId,quantity}], dPrice?, isActive?}` |
| PATCH | `/v1/partner/combo/:comboId` | partner | — | body: same fields as create (all optional) |
| DELETE | `/v1/partner/combo/:comboId` | partner | — | |

### Raw curl examples

```bash
BASE=http://localhost:3000

# List active combos (diner)
curl -s "$BASE/v1/genie/combo?isActive=true" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .comboName, price: .dPrice}'

# Filter by name (diner)
curl -s "$BASE/v1/genie/combo?comboName=Snack" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .comboName}'

# Single combo with item breakdown
curl -s "$BASE/v1/genie/combo/69f8757fd475a8cf66ed94f2" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result | {name: .comboName, price: .dPrice, items: .items}'

# Create combo (partner)
curl -s -X POST "$BASE/v1/partner/combo" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"comboName":"Lunch Deal","items":[{"menuItemId":"691bf10018f1d3c34db1db00","quantity":2}],"dPrice":20}' | jq '{_id: .result._id, name: .result.comboName}'

# Update combo (partner)
curl -s -X PATCH "$BASE/v1/partner/combo/69f8757fd475a8cf66ed94f2" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"isActive":false}' | jq '.message'
```

## Combo Testing (with order)

```bash
# Order with combo — cartId+dinerId as query params, use comboId (NOT itemId)
ORDER_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"comboId":"69f8757fd475a8cf66ed94f2","quantity":1}]}')
echo $ORDER_RESPONSE | jq '{orderNumber: .result.orders[-1].orderNumber, item: .result.orders[-1].orderDetails[0].itemName, total: .result.cartSubTotal}'

# List partner combos
curl -s $BASE/v1/partner/combo \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | {_id, name, price, isActive}'
```
