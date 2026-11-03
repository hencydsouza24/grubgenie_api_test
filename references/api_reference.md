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
| Admin password | *(ask a teammate — put in `scripts/config/credentials.env`, never commit)* |
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

### Platform Routes (admin-gated, but NOT under the `/v1/admin` prefix)

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
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

### POS Routes (Petpooja — see pos.sh / pos.ps1)

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/partner/pos/menu` | Bearer partner | query: `provider` — fetch raw POS menu (categories + items) |
| GET | `/v1/partner/pos/:provider/items` | Bearer partner | POS items enriched with GrubGenie link status |
| POST | `/v1/partner/pos/sync-menu` | Bearer partner | body: `{provider}` — trigger async menu import; 202 enqueued, 409 already running |
| GET | `/v1/partner/branch/pos-config` | Bearer partner | list POS provider configs (with credentials) |
| PUT | `/v1/partner/branch/pos-config` | Bearer partner | upsert provider config; body: `{provider, isEnabled, credentials:{...}}` |
| DELETE | `/v1/partner/branch/pos-config/:provider` | Bearer partner | remove provider config; 204 |
| POST | `/v1/partner/menu` | Bearer partner | create menu item; body may include `pos.petpooja.itemId` — validates no duplicate POS links (409) |
| POST | `/v1/partner/menu/add-variant/:itemId` | Bearer partner | create variant; may include `pos.petpooja.variationId` |

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

### Webhook Routes (inbound)

Stripe and PostHog webhooks are signature-verified — not practically testable by hand. The
Petpooja POS webhooks have **no auth middleware at all** (Petpooja calls them directly) and ARE
manually testable; see SKILL.md's POS webhook simulation section for full request examples.

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/webhooks/v1/stripe/diner-payment` | Signature | Stripe diner payment webhook |
| POST | `/webhooks/v1/stripe/partner-onboarding` | Signature | Stripe partner onboarding webhook |
| POST | `/webhooks/v1/stripe/subscription` | Signature | Stripe subscription webhook |
| POST | `/webhooks/v1/posthog/posthog-events` | Signature | PostHog event ingestion |
| POST | `/webhooks/v1/pos/menu_push` | **None** | Petpooja pushes full menu → invalidate cache + enqueue sync |
| POST | `/webhooks/v1/pos/get_store_status` | **None** | Petpooja queries store open/closed |
| POST | `/webhooks/v1/pos/update_store_status` | **None** | Petpooja updates store open/closed |
| POST | `/webhooks/v1/pos/item_off` | **None** | Petpooja marks item unavailable |
| POST | `/webhooks/v1/pos/item_on` | **None** | Petpooja marks item available |
| POST | `/webhooks/v1/pos/order_callback` | **None** | Petpooja sends order status update; `orderID` maps to `orderNumber`, not `_id` |

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
- **Order status flow (canonical — SKILL.md and advanced_flows.md reference this, not restate it)**:
  `pending` → `placed` (place-order call). If branch `orderAcceptanceMode` is `manual`, the order
  enters `pending_acceptance` **immediately on place-order, before the partner responds** — not
  after. The partner's accept/reject decision is what moves it OUT of `pending_acceptance`, into
  `preparing` → `ready` → `completed`, or into `rejected`. If `orderAcceptanceMode` is
  `automatic` (the default), placed orders skip `pending_acceptance` entirely and go straight to
  `preparing`.
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

## Admin: Settlement, WABA Flows, Genie, Dashboard, Partner Mgmt

All routes below require an admin bearer token (`gg_admin_token` / `Get-GgCachedAdminToken`,
which lazily logs in with `GG_ADMIN_EMAIL`/`GG_ADMIN_PASSWORD` from `credentials.env` and caches
the token in the session file). See `settlement.sh`/`.ps1`, `waba_flows.sh`/`.ps1`,
`genie_admin.sh`/`.ps1`, `dashboard.sh`/`.ps1`, `admin_partner.sh`/`.ps1`.

### Admin Settlement — base `/v1/admin/settlement`

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/` | list; query: `status`, `limit`, `page`, `partnerId`, `branchId`, `gateway`, `periodFrom`, `periodTo`, `sortBy`, `projectBy` — all optional |
| GET | `/summary` | no params |
| GET | `/partners/:partnerId` | query: `sortBy`, `limit`, `page` |
| GET | `/branches/:branchId` | query: `sortBy`, `limit`, `page` |
| POST | `/calculate` | preview only, writes nothing; body: `{partnerId, periodFrom, periodTo, branchId?}` |
| POST | `/batch/calculate` | body: `{periodFrom, periodTo, targets: [{partnerId, branchId?}, ...]}` (1-100 targets) |
| POST | `/` | create; body: `{partnerId, periodFrom, periodTo, branchId?, allowPartial?, notes?}` |
| POST | `/batch` | body: `{periodFrom, periodTo, targets: [...], allowPartial?, notes?}` |
| GET | `/:settlementId` | registered last in the route file so it doesn't shadow `/summary`/`/partners/:id`/`/branches/:id` |
| PUT | `/:settlementId/mark-settled` | body: `{notes?}` |

`periodFrom`/`periodTo` are plain `YYYY-MM-DD` strings (not full ISO datetimes) matched against
`DailyRevenue.localDate`. Permissions: `viewSettlement` for the GETs, `manageSettlement` for the
writes (both under the top-level `settlement` permission group, separate from the
partner-facing `partner.settlement.viewSettlement`).

### Admin Dashboard — base `/v1/admin/dashboard`

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/summary` | no params |
| GET | `/timeseries` | query: `metric` (`orders`\|`signups`\|`partners`\|`revenue`, required), `interval` (`day`\|`week`, required), `from`/`to` (ISO dates, optional) |
| GET | `/top` | query: `metric` (`partners-by-orders`\|`diners-by-orders`\|`dishes`\|`cuisines`\|`partners-by-revenue`, required), `limit` (default 10) |

Permission: `superAdmin.viewDashboard`.

### Admin WABA Flows — base `/v1/admin/waba/flows`

Unlike every sibling `admin/waba/*` route (which accepts an `X-Api-Key` service-account key),
`manageFlows` is deliberately excluded from the `wabaMiddleware` API-key role in
`src/config/roles.ts` — only `super-admin` has it. The route itself uses `authJwtOrApiKey`
(JWT-or-key), but in practice only an admin bearer token works here.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/definitions` | query: `key`, `sortBy`, `limit`, `page` |
| POST | `/definitions` | body: `{key, name, categories: [...], flowJson, autoProvision?}` |
| GET | `/definitions/:definitionId` | — |
| PATCH | `/definitions/:definitionId` | body: `{name?, categories?, flowJson?, autoProvision?}` |
| POST | `/definitions/:definitionId/release` | — |
| GET | `/deployments` | query: `wabaId`, `key`, `sortBy`, `limit`, `page` |
| POST | `/deployments/:deploymentId/retry` | — |
| POST | `/deployments/:deploymentId/deprecate` | — |

`categories` values: `SIGN_UP`, `SIGN_IN`, `APPOINTMENT_BOOKING`, `LEAD_GENERATION`,
`CONTACT_US`, and others — see `WABA_FLOW_CATEGORIES` in
`src/modules/waba/flows/wabaFlowDefinition.interfaces.ts`. `flowJson` is a JSON-encoded string
(max 1 MiB), not a nested object.

### Admin Genie — base `/v1/admin/genie`

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/fleet` | — |
| GET | `/sessions` | query: `page`, `limit`, `fromTimestamp`, `toTimestamp` |
| GET | `/threads` | list all active threads (not wired into `genie_admin.sh`/`.ps1` — only the `:threadId`-scoped routes below are) |
| GET | `/threads/:threadId` | — |
| GET | `/threads/:threadId/activity` | query: `limit` |
| DELETE | `/threads/:threadId` | evict |
| POST | `/threads/:threadId/signal` | body: `{signal: {...}}` — validation only requires an object; `{type, payload}` mirrors the `ParsedBehaviorSignal` shape |
| POST | `/threads/:threadId/chat` | body: `{message}` |
| POST | `/threads/:threadId/end` | — |
| POST | `/spawn` | body: `{dinerId, cartId, branchId, accountId, partnerId, tableId}` — all six are **required** (the task spec guessed some would be optional; the real Joi schema requires all of them) |

`threadId` is a composite `` `diner-agent:${cartId}:${dinerId}` `` (see `buildThreadId` in
`src/modules/genieV2/genie.helpers.ts` — note this is the **genieV2** module, not the deprecated
`modules/genie/`). Colons in a URL path segment pass through curl/`Invoke-WebRequest` unencoded
without issue, so neither script script URL-encodes it. Permission: `sysInfo.getSysInfo` (admin
bearer) for every route in this group.

### Admin Partner Mgmt — base `/v1/admin/partner`

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/` | list; query: `page`, `limit`, `sortBy`, `status` (`active`\|`inactive`), `plan`, `search` |
| GET | `/:accountId` | path param is **`accountId`**, not `partnerId` — confirmed against `partner.info.validation.ts`, which validates it as a plain required string (not `objectId`) |
| PATCH | `/:accountId` | free-form `$set` body, e.g. `{name: "..."}` — the route has **no request validation middleware at all**, so any field name is accepted |
| GET | `/agent-contexts` | all branches across all partners with an agent context |
| GET | `/:accountId/branches/agent-context` | one partner's branches with an agent context |
| GET | `/:accountId/branches/:branchId/agent-context` | — |
| PUT | `/:accountId/branches/:branchId/agent-context` | body: `{context: string}` |

Permissions: `superAdmin.viewPartners` for list/get, `partner.adminUpdatePartner` for the PATCH,
`partner.branch.updateBranchAgentContext` for every agent-context route.

## Admin: Config, Cuisine, Diner, KB Catalog, Migrations, ML, OpenViking, Order, Plan, QR Code, WABA Resolve, Templates, Agents, Debug

Covers two scripts: `admin_misc.sh`/`.ps1` (admin-bearer verbs — config, cuisine, diner,
genie-core sessions, kb-topic-catalog, migration, ml, openviking, order, plan, qrcode-extra,
waba-resolve, whatsapp-template) and `misc_tools.sh`/`.ps1` (non-admin-bearer verbs — agents
module, debug health/connections, redirect, voice tool webhook).

Several real routes and mount paths differ from this section's original audit — corrected below
and called out explicitly where it matters:

- `GET /v1/admin/config/:name` and both Cuisine routes (`GET /`, `GET /:cuisineId`) have **no**
  `auth()` middleware at all (only `validate()`) — confirmed in `config.route.ts`/
  `cuisine.route.ts`. `admin_misc.sh config get`/`cuisine list`/`cuisine get` call them with no
  token.
- KbTopicCatalog is mounted at `/v1/admin/kb-topic-catalog` (kebab-case), not
  `/v1/admin/kbTopicCatalog`.
- WhatsAppTemplate is mounted at `/v1/admin/whatsapp/templates`, not
  `/v1/admin/whatsapp-template` — so re-provision is `POST /v1/admin/whatsapp/templates/re-provision`.
- WABA resolve auth is `authJwtOrApiKey` — a Bearer JWT **or** an `X-Api-Key` header — not "no
  auth". This skill always uses the `X-Api-Key` path (`GG_WABA_MIDDLEWARE_API_KEY`), the same key
  reused by the agents knowledge-base topic route below.
- `GET /v1/debug/health` does not exist. `debug.route.ts`'s only routes are `/memory`, `/gc`,
  `/heap-snapshot`, `/heap-stats`, `/active-handles`, `/connections` — **all** behind
  `router.use(auth(permissions.sysInfo.getSysInfo))`. The actual zero-auth health check is a
  separate top-level route, `GET /v1/health` (`health.route.ts`). `misc_tools.sh debug health`
  calls that, not `/v1/debug/health`.
- `GET /v1/agents/partner/:partnerId` really does have zero auth middleware — confirmed, not an
  oversight in this doc.
- The WhatsApp click redirect (`GET /v1/redirect/:buttonIndex/:ref`) can't be contract-tested for
  its own 3xx through this skill's transport: `gg_http`/`Invoke-GgHttp` always follow redirects
  (curl's `-L` / `Invoke-WebRequest`'s default behavior), so the status observed is the **final**
  destination's, not the redirect route's. `misc_tools.sh redirect` reports the post-redirect
  status with a note to that effect instead of asserting a 3xx.
- The voice tool webhook's `:toolKey` path segment is a real per-partner provisioned secret
  (hashed and compared server-side), not a public test fixture — it's never a CLI argument here,
  only `GG_VOICE_TOOL_KEY` from `credentials.env`, the same way Petpooja's app secret is never
  typed on the command line for `pos.sh config setup`.

### Admin Config — base `/v1/admin/config`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/:name` | **None** (validate only) | single config by name |
| PUT | `/:name` | Bearer admin | body: `{value: "<string>"}` — `admin_misc.sh config update` only supports a string value (the real schema's `value` is `Joi.any()`, but this skill never shell-interpolates JSON bodies) |
| DELETE | `/:name` | Bearer admin | |

### Admin Cuisine — base `/v1/admin/cuisine`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/` | **None** | list |
| GET | `/:cuisineId` | **None** | single cuisine |

### Admin Diner — base `/v1/admin/diner`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/` | Bearer admin | query: `page`, `limit`, `sortBy`, `search`, `active` — all optional |
| GET | `/:id` | Bearer admin | |

### GenieCore sessions — base `/v1/admin/genie-core`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/sessions` | Bearer admin | no `validate()`, no query params — `result: {count, sessions}` |

### KbTopicCatalog — base `/v1/admin/kb-topic-catalog`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/` | Bearer admin | list |
| POST | `/` | Bearer admin | body: `{key, label, store, description?, featureFlag?, routeFlow?}` — `key` must match `KB_TOPIC_KEY_PATTERN` (`^[a-z][a-z0-9_]{1,39}$`); `store` ∈ `documents\|menu\|none` |
| PUT | `/:catalogId` | Bearer admin | body: same fields, all optional |
| DELETE | `/:catalogId` | Bearer admin | |

### Migration — base `/v1/admin/migration`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/run-all-pending` | Bearer admin | query: `tenantId?`, `override?` (`"true"\|"false"`) |

### ML — base `/v1/admin/ml`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/retrain/:accountId` | Bearer admin | no body |

### OpenViking (admin) — base `/v1/admin/openviking`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/inject-branch-context` | Bearer admin | body: `{accountId, branchId, content}` — plain strings, not ObjectIds |
| POST | `/upload-skill` | Bearer admin | body: `{accountId, branchId, content}` — same shape |

### Admin Order — base `/v1/admin/order`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/` | Bearer admin | query: `page`, `limit`, `sortBy`, `partnerId`, `branchId`, `status`, `type`, `from`, `to` — all optional |
| GET | `/:id` | Bearer admin | |

### Plan — base `/v1/admin/plan`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/slug/:slug` | Bearer admin | `admin_misc.sh plan slug <slug>` — slug pattern `^[a-z0-9-_]+$`, case-insensitive |

### QrCode (admin, extra) — base `/v1/admin/qr-code`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/available-partners` | Bearer admin | |
| GET | `/available-tables` | Bearer admin | query: `branchId`, `accountId` — both required |
| GET | `/details` | Bearer admin | query: `code` (string or array of strings) |

### WABA resolve — base `/v1/admin/waba`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/resolve-account` | `authJwtOrApiKey` — Bearer JWT **or** `X-Api-Key` | body: `{wabaId, callerKeyId}`; this skill always sends `X-Api-Key: $GG_WABA_MIDDLEWARE_API_KEY` |
| POST | `/resolve-platform-inbound` | `authJwtOrApiKey` — Bearer JWT **or** `X-Api-Key` | body: `{phoneNumberId, waId?}` |

### WhatsAppTemplate — base `/v1/admin/whatsapp/templates`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/re-provision` | Bearer admin | body: `{partnerId}` |

### Agents module — base `/v1/agents`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/knowledge-base/topics/:topicKey` | `authApiKey()` + `requireApiKeyPartnerAccess` — literal `X-Api-Key` header (passport-headerapikey, no prefix) | query: `partnerId` (required), `branchId?` — reuses `GG_WABA_MIDDLEWARE_API_KEY` |
| GET | `/partner/:partnerId` | **None** | query: `branchId?` — confirmed, not an oversight |

### Debug — base `/v1/debug`

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/connections` | Bearer admin (`router.use(auth(permissions.sysInfo.getSysInfo))`) | MongoDB connection cache stats |

Zero-auth health check (separate route, not under `/v1/debug`):

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/health` | **None** | `health.route.ts`, mounted directly in `src/routes/v1/index.ts` |

### Redirect — `GET /v1/redirect/:buttonIndex/:ref`

Public, no auth. WhatsApp campaign click-tracking redirect; `ref` is `` `${tenantId}.${token}` ``.
302s to the real destination and sets a cookie. See the transport caveat above — `misc_tools.sh
redirect` reports the post-redirect status, not a verified 3xx.

### Voice tool webhook — `GET /v1/voice/tools/:toolKey/:tool`

Public route; `:toolKey` is the auth (a secret, hashed and compared server-side by
`gatewayController.runTool`) — sourced from `GG_VOICE_TOOL_KEY`, never a CLI argument. Example
`:tool=availability` query params: `partnerId`, `branchId`, `date`, `partySize` (plus optional
`durationMin`, `session`, `format`).

## Partner: Voice, All-Outlets, Queue, Role, Table Actions

All routes below use partner bearer auth (`gg_session_get partnerToken` / `Get-GgSessionValue -Key 'partnerToken'`). Scripts: `voice.sh`/`voice.ps1` (Voice), `partner_ops.sh`/`partner_ops.ps1` (All-Outlets + Queue + Role), `table_actions.sh`/`table_actions.ps1` (the 4 new Table actions). Helper libs: `lib/api_partner_voice.sh` + `powershell/lib/ApiPartnerVoice.ps1`, and `lib/api_partner_ops.sh` + `powershell/lib/ApiPartnerOps.ps1`. These two lib pairs are not yet wired into `bootstrap.sh`/`Bootstrap.ps1` — the three scripts above dot-source them directly, after bootstrap.

### Voice (HeyKoala connection + call history)

Base `/v1/partner/voice`. Connection-mutating routes and `calls/sync` need `manageReservationSettings`; read-only `calls` routes need `getReservations`.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/voice/connection/options` | Re-validates the stored key; returns agent/number/call-flow lists |
| POST | `/v1/partner/voice/connection/validate-key` | body: `{apiKey}` |
| GET | `/v1/partner/voice/connection` | |
| PUT | `/v1/partner/voice/connection` | body: `{agentId, phoneNumberId, callFlowId, apiKey?}` — apiKey optional on save |
| POST | `/v1/partner/voice/connection/rotate-tool-key` | **not** `rotate-key` — confirmed exact path in voice.route.ts |
| POST | `/v1/partner/voice/connection/test` | body: `{branchId, date: "YYYY-MM-DD", partySize}` |
| POST | `/v1/partner/voice/connection/go-live` | |
| DELETE | `/v1/partner/voice/connection` | |
| GET | `/v1/partner/voice/calls` | query (all optional): `page, limit, direction, from, to, branchId, outcome, q` |
| GET | `/v1/partner/voice/calls/stats` | same query shape as `/calls` — one shared schema, no separate stats schema |
| POST | `/v1/partner/voice/calls/sync` | no body |
| GET | `/v1/partner/voice/calls/linked` | query: exactly one of `reservationId` XOR `inquiryId` |
| GET | `/v1/partner/voice/calls/:callId` | |

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

bash $SKILL/voice.sh connection options
bash $SKILL/voice.sh connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]
bash $SKILL/voice.sh connection test <branchId> 2026-01-15 2
bash $SKILL/voice.sh calls list "page=1" "limit=20" "direction=inbound"
bash $SKILL/voice.sh calls linked reservationId <reservationId>
```

### All-Outlets (cross-branch rollup reads)

Base `/v1/partner/all-outlets`. Simple reads plus one write.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/all-outlets/outlets` | |
| GET | `/v1/partner/all-outlets/inquiries` | query (all optional): `branchId, page, limit, status, inquiryType, q` |
| GET | `/v1/partner/all-outlets/reservations` | query: `branchId, page, limit` optional; `after, before` (ISO dates) **required**; `status, source, q` optional |
| GET | `/v1/partner/all-outlets/queue` | query: `branchId` optional |
| GET | `/v1/partner/all-outlets/notifications` | no query |
| PUT | `/v1/partner/all-outlets/notifications/read` | body **is required**: `{items: [{branchId, notificationIds: [...]}]}` — not a bare mark-all-read call |

```bash
bash $SKILL/partner_ops.sh outlets
bash $SKILL/partner_ops.sh inquiries "status=open" "page=1"
bash $SKILL/partner_ops.sh reservations "after=2026-01-01" "before=2026-01-31"
bash $SKILL/partner_ops.sh notifications-read <branchId> <notificationId> [notificationId...]
```

### Queue (walk-in queue CRUD + transitions)

Base `/v1/partner/queue`. 10 endpoints: 5 CRUD + 5 state-transition actions, each `POST /:queueId/<action>` with its own body shape (not all empty):

| Method | Route | Body |
|--------|-------|------|
| POST | `/v1/partner/queue` | `{guestName, guestPhone, partySize}` required; `quotedWaitMin, preferenceNote` optional |
| GET | `/v1/partner/queue` | query (optional): `include=all, status, joinedAfter, joinedBefore, q, limit` |
| GET | `/v1/partner/queue/:queueId` | |
| PUT | `/v1/partner/queue/:queueId` | any of the create fields, min 1 required |
| DELETE | `/v1/partner/queue/:queueId` | |
| POST | `/v1/partner/queue/:queueId/notify` | **empty body** |
| POST | `/v1/partner/queue/:queueId/table-ready` | `{tableId?}` |
| POST | `/v1/partner/queue/:queueId/seat` | `{tableId?}` — same shape as `table-ready` |
| POST | `/v1/partner/queue/:queueId/abandon` | `{reason?: "staff"\|"converted"}` |
| POST | `/v1/partner/queue/:queueId/reopen` | **empty body** |

```bash
bash $SKILL/partner_ops.sh queue create "Jane Doe" "+15551234567" 4
bash $SKILL/partner_ops.sh queue list "status=waiting"
bash $SKILL/partner_ops.sh queue table-ready <queueId> <tableId>
bash $SKILL/partner_ops.sh queue abandon <queueId> staff
```

### Role (custom partner roles)

**Mounted at `/v1/partner/roles` (plural)** — not `/v1/partner/role`; confirmed in `src/routes/v1/partner/index.ts`.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/roles/permission-catalog` | query: `roleKey` optional |
| GET | `/v1/partner/roles` | list |
| POST | `/v1/partner/roles` | body: `{name, permissions: [...]}` — permissions must be real leaf values from `src/config/roles.ts` (e.g. `readBranch`, `getQueue`, `createQueueEntry`); the server 400s on anything else |
| PUT | `/v1/partner/roles/:roleId` | body: at least one of `{name, permissions}` |
| DELETE | `/v1/partner/roles/:roleId` | |

```bash
bash $SKILL/partner_ops.sh role permission-catalog
bash $SKILL/partner_ops.sh role create "Front Desk" readBranch getQueue createQueueEntry
bash $SKILL/partner_ops.sh role update <roleId> - getQueue updateQueueEntry
```

### Table actions (split / merge / borrow-chair / return-chair)

Additional to the basic `GET /v1/partner/table` list and `PUT /v1/partner/table/table-status/:tableId` already covered by `reset_tables.sh`. Confirmed directly against `table.route.ts`/`table.validation.ts`/`table.controller.ts` on this branch — all under the same `/v1/partner/table` base:

| Method | Route | Body |
|--------|-------|------|
| POST | `/v1/partner/table/:tableId/split` | `{segments: number[]}` — 2 to 4 seat counts |
| POST | `/v1/partner/table/:tableId/merge` | no body |
| POST | `/v1/partner/table/:tableId/borrow-chair` | `{fromTableId, count?}` (count defaults to 1) |
| DELETE | `/v1/partner/table/:tableId/borrow-chair/:borrowId` | **DELETE, not POST** — both `tableId` and `borrowId` are path params |

`borrow-chair`'s response is the updated table document; each entry in `result.borrowedChairs[]` carries its own `_id`, which is the `borrowId` the return-chair call needs. The script does not auto-chain this — read the id out of the borrow response and pass it explicitly, matching this skill's existing style of explicit-id args (e.g. `pos_config_disable <provider>`).

```bash
bash $SKILL/table_actions.sh split <tableId> 2 2
bash $SKILL/table_actions.sh borrow-chair <tableId> <fromTableId> 1
# then, using the borrowId from the previous call's result.borrowedChairs[]._id:
bash $SKILL/table_actions.sh return-chair <tableId> <borrowId>
bash $SKILL/table_actions.sh merge <tableId>
```

## Partner: Guest/Inquiry/Insights, Menu/Combo Mgmt, Settlement

All routes below use partner bearer auth (`PARTNER_TOKEN` / `gg_session_get partnerToken` /
`Get-GgSessionValue -Key 'partnerToken'`). Scripts: `crm.sh`/`crm.ps1` (Guest sub-resources,
Inquiry, Insights), `menu_manage.sh`/`menu_manage.ps1` (Combo CRUD, Menu bulk/duplicate),
`partner_settlement.sh`/`partner_settlement.ps1` (Settlement reads).

### Corrections vs. the original route audit

A few things changed/were mis-stated in the audit this section was scoped from — verified
directly against the route/controller/validation source on this branch:

- **Guest base path is `/v1/partner/guests` (plural), not `/v1/partner/guest`.**
  `src/routes/v1/partner/index.ts` mounts `guest.route.ts` at `/guests`.
- **`promote-dish` is `POST /v1/partner/insights/weekly/promote-dish/:itemId`, not
  `POST /v1/partner/insights/promote-dish`.** `itemId` is a URL param, not a body field —
  confirmed against `insights.route.ts` and `insightValidation.promoteDish`.
- **`menu-performance-details` and `category-rollup` do NOT use the standard `{status, success,
  message, result}` envelope.** Their controllers (`insights.controller.ts`) call `res.json(...)`
  directly: `menu-performance-details` returns `{success, message, data: {summary, items},
  pagination}`; `category-rollup` returns `{success, message, currency, data}`. Every other
  endpoint in this section uses the standard envelope with `.result`.
- **`weekly` and `hourly-demand` both REQUIRE `branchId` as a query param**
  (`insightValidation.getWeeklyInsights` / `getHourlyDemand`) — most other insights reads don't.
- **Combo `POST /` (create) requires `foodCategoryId` and `foodTypeId`** per
  `comboValidation.createCombo`. The older "Combo Fetching" section's curl example below omits
  both — that example would 400 against the current validation; the new `gg_combo_create` /
  `New-GgCombo` functions include them.

### Guest Sub-Resources

Reads on an existing Guest record. Base Guest CRUD (list/create/get/update/delete/restore/
sync-from-orders/import) predates this section and is out of scope here.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/guests/:guestId/whatsapp-thread` | query: `limit?`, `before?` (ISO date) |
| GET | `/v1/partner/guests/:guestId/campaigns` | campaign history |
| GET | `/v1/partner/guests/:guestId/inquiries` | inquiries linked to this guest |
| GET | `/v1/partner/guests/:guestId/calls` | call history |
| GET | `/v1/partner/guests/:guestId/engagement-summary` | rollup summary |

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

bash $SKILL/crm.sh guest whatsapp-thread 69f8757fd475a8cf66ed94f2
bash $SKILL/crm.sh guest campaigns 69f8757fd475a8cf66ed94f2
bash $SKILL/crm.sh guest inquiries 69f8757fd475a8cf66ed94f2
bash $SKILL/crm.sh guest calls 69f8757fd475a8cf66ed94f2
bash $SKILL/crm.sh guest engagement-summary 69f8757fd475a8cf66ed94f2
```

### Inquiry

Base `/v1/partner/inquiry`.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/inquiry` | query: `status, inquiryType, source, q, after, before, sortBy, page, limit` (all optional, CSV for enum filters) |
| POST | `/v1/partner/inquiry` | body: `{guestName, guestPhone, inquiryType, summary?}` |
| GET | `/v1/partner/inquiry/:inquiryId` | |
| PUT | `/v1/partner/inquiry/:inquiryId` | body: any subset of `{guestName, guestPhone, inquiryType, summary}`, min 1 field |
| DELETE | `/v1/partner/inquiry/:inquiryId` | → HTTP 204 |
| POST | `/v1/partner/inquiry/:inquiryId/status` | body: `{status, reservationId?}` — note: POST, not PUT |

```bash
bash $SKILL/crm.sh inquiry list
bash $SKILL/crm.sh inquiry create "Jane Doe" "+15551234567" "reservation" "Table for 4, 8pm"
bash $SKILL/crm.sh inquiry get 69f8757fd475a8cf66ed94f2
bash $SKILL/crm.sh inquiry update 69f8757fd475a8cf66ed94f2 "" "" "" "Updated summary"
bash $SKILL/crm.sh inquiry status 69f8757fd475a8cf66ed94f2 resolved
bash $SKILL/crm.sh inquiry delete 69f8757fd475a8cf66ed94f2
```

### Insights

Base `/v1/partner/insights`. `item-names`, `item-graph-data`, `menu-performance`,
`order-performance` already exist/are covered elsewhere — only the 6 below are new here.
`front-desk`/`front-desk/export` are a separate route file, out of scope.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/insights/order-graph-data` | query: `fromDate?, toDate?, page?, limit?, sortBy?, search?, orderStatus?, type?` |
| GET | `/v1/partner/insights/menu-performance-details` | query: `fromDate?, toDate?, categoryId?, itemId?, status?, sortBy?, sortOrder?, page?, limit?` — response is `{success, message, data:{summary,items}, pagination}`, not `.result` |
| GET | `/v1/partner/insights/category-rollup` | query: `fromDate?, toDate?` — response is `{success, message, currency, data}`, not `.result` |
| GET | `/v1/partner/insights/weekly` | query: `branchId` (**required**) |
| POST | `/v1/partner/insights/weekly/promote-dish/:itemId` | no body |
| GET | `/v1/partner/insights/hourly-demand` | query: `branchId` (**required**), `fromDate?, toDate?` |

```bash
bash $SKILL/crm.sh insights order-graph-data
bash $SKILL/crm.sh insights menu-performance-details
bash $SKILL/crm.sh insights category-rollup
bash $SKILL/crm.sh insights weekly 3XSJT
bash $SKILL/crm.sh insights promote-dish 691bf10018f1d3c34db1db00
bash $SKILL/crm.sh insights hourly-demand 3XSJT
```

### Combo CRUD (partner)

Base `/v1/partner/combo`. List (`GET /`) is already documented in "Combo Fetching" above — this
adds create/get-by-id/update/delete.

| Method | Route | Notes |
|--------|-------|-------|
| POST | `/v1/partner/combo` | body: `{comboName, foodCategoryId, foodTypeId, items:[{menuItemId,quantity,variantId?}], description?, dPrice?, isActive?}` — `foodCategoryId`/`foodTypeId` are **required** |
| GET | `/v1/partner/combo/:comboId` | |
| PATCH | `/v1/partner/combo/:comboId` | body: any subset of the create fields |
| DELETE | `/v1/partner/combo/:comboId` | |

```bash
bash $SKILL/menu_manage.sh combo create "Lunch Deal" <foodCategoryId> <foodTypeId> 691bf10018f1d3c34db1db00 2 20
bash $SKILL/menu_manage.sh combo get 69f8757fd475a8cf66ed94f2
bash $SKILL/menu_manage.sh combo update 69f8757fd475a8cf66ed94f2 "" false
bash $SKILL/menu_manage.sh combo delete 69f8757fd475a8cf66ed94f2
```

### Menu Bulk/Duplicate

Base `/v1/partner/menu`.

| Method | Route | Notes |
|--------|-------|-------|
| PUT | `/v1/partner/menu/bulk` | body: `{ids:[menuItemId...], changes:{...}, customizationMode?}` — `changes` matches `bulkEditChangesSchema` (e.g. `foodCategoryId, dineIn, chefsChoice, spicinessLevel, servingSize, dietaryPreference, allergens, mealTiming, customization`) |
| DELETE | `/v1/partner/menu/bulk` | body: `{ids:[menuItemId...]}` |
| POST | `/v1/partner/menu/:menuItemId/duplicate` | body: `{foodCategoryId}` |

```bash
bash $SKILL/menu_manage.sh bulk-edit "id1,id2" '{"chefsChoice":true}'
bash $SKILL/menu_manage.sh bulk-delete "id1,id2"
bash $SKILL/menu_manage.sh duplicate 691bf10018f1d3c34db1db00 <foodCategoryId>
```

### Partner Settlement (read-only)

Base `/v1/partner/settlement`. `branchId` is auto-scoped server-side for non-admin partner users
(admins may override via query).

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/settlement` | query: `branchId?, status?(pending\|settled), gateway?(stripe\|razorpay\|cash\|mixed), periodFrom?, periodTo?, sortBy?, page?, limit?` |
| GET | `/v1/partner/settlement/summary` | pending amount summary for the current partner |

```bash
bash $SKILL/partner_settlement.sh list
bash $SKILL/partner_settlement.sh list status=pending
bash $SKILL/partner_settlement.sh summary
```

## Partner: Staff Order, Reservation Widget + Public Reservation, Diner Extensions, Front Desk/WhatsApp Misc

Use `staff_order.sh`/`staff_order.ps1` for the full staff flow, `reservation.sh`/`.ps1` for the
widget embed + public reservation flow, `partner_misc.sh`/`.ps1` for front-desk-report/WhatsApp
misc/order-history reads, and `diner_ext.sh`/`.ps1` for the diner genie extensions. All four
source `lib/api_partner_misc.sh` / `lib/ApiPartnerMisc.ps1` directly (alongside `lib/bootstrap.sh`
/ `lib/Bootstrap.ps1`) — that lib isn't wired into bootstrap/Bootstrap yet.

### Staff Order (partner bearer)

Its own route file (`src/routes/v1/partner/order.route.ts`, mounted at `/v1/partner/order`) —
NOT a reuse of the diner-facing `/v1/genie/cart` + `/v1/genie/order` routes under a different
token, though it reuses the same underlying write paths (tagged `actorType: 'staff'`).

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| POST | `/v1/partner/order/table/:tableId/cart` | Bearer partner | starts/joins a cart for that table; body: none; id is `result._id` (NOT `result.cartId` — unlike the diner cart response) |
| POST | `/v1/partner/order/cart/:cartId/items` | Bearer partner | starts a new order on the cart; body: `{items:[{itemId\|comboId,quantity}, ...]}` (required, non-empty); orderId is `result.currentActiveOrder` |
| PUT | `/v1/partner/order/order/:orderId/items` | Bearer partner | edits an existing order; query: `cartId`; body: `{items?:[...], note?}` |
| PUT | `/v1/partner/order/order/:orderId/place` | Bearer partner | query: `cartId`; body: `{note?}`; status read from `result.orders[]`, same as the diner flow |

```bash
SKILL=/path/to/grubgenie-api-test/scripts
bash $SKILL/staff_order.sh <tableId> <itemId> [qty]
```

### Reservation Widget Embed (X-Api-Key auth — NOT partner bearer)

`src/routes/v1/partner/reservationWidget.route.ts`. `GET /embed` is gated by
`authJwtOrApiKey`, which technically also accepts a Bearer JWT with the right permission, but the
embed script's real caller (the restaurant's own public website) only ever holds the widget's own
API key — that's the credential this skill wires up. The old `/reservation-widget/public/:key`
route some references mention is dead; `/embed` is the current replacement.

| Method | Route | Auth | Notes |
|--------|-------|------|-------|
| GET | `/v1/partner/reservation-widget/embed` | `X-Api-Key` | requires `GG_WIDGET_EMBED_KEY` (see credentials.example.env); returns the widget's public config |

```bash
bash $SKILL/reservation.sh embed
```

### Public Reservation (no auth — signed `ref` token, not a plain id)

`src/routes/v1/genie/reservation.route.ts`, backed by `reservationPublicController`. Genuinely no
auth middleware, only rate limiters. `ref` is a signed `xxx.yyy`-shaped token (partner+branch+
reservation), not a Mongo `_id` — there's no known-good fixture, so it's a required positional arg.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/genie/reservation/review/:ref` | redirects to the review platform; registered before `/:ref` so it isn't swallowed by it |
| GET | `/v1/genie/reservation/:ref` | reservation details |
| GET | `/v1/genie/reservation/:ref/availability` | query: `date` (YYYY-MM-DD), `partySize` |
| PATCH | `/v1/genie/reservation/:ref` | body: `{startAt?, partySize?}`, `.min(1)` — guest self-service, only these two fields |
| POST | `/v1/genie/reservation/:ref/cancel` | body: `{reason?}` — its own endpoint, separate from modify |

```bash
bash $SKILL/reservation.sh public get <ref>
bash $SKILL/reservation.sh public review <ref>
bash $SKILL/reservation.sh public availability <ref> 2026-11-01 2
bash $SKILL/reservation.sh public modify <ref> 2026-11-01T19:00:00.000Z 4
bash $SKILL/reservation.sh public cancel <ref> "plans changed"
```

### Front Desk Report (partner bearer)

Its own route file/controller (`src/routes/v1/partner/frontDeskReport.route.ts`), mounted at
`/v1/partner/insights/front-desk` — distinct from the general `insights.route.ts`.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/insights/front-desk` | query: `from, to` (YYYY-MM-DD, required), `scope` (`single`\|`all`, default `single`), `branchId?` |
| GET | `/v1/partner/insights/front-desk/export` | same query plus `format=xlsx` (required); returns a binary XLSX, not JSON |

```bash
bash $SKILL/partner_misc.sh front-desk-report 2026-10-01 2026-10-31
bash $SKILL/partner_misc.sh front-desk-report --export 2026-10-01 2026-10-31
```

### WhatsApp Agent Settings + Audience Segments (partner bearer)

Mount path is `/v1/partner/whatsapp/agent-settings` (kebab-case — not `/agentSettings`); see
`src/routes/v1/partner/whatsapp/index.ts`. Audience segments live under the campaigns sub-route.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/whatsapp/agent-settings` | current settings |
| PATCH | `/v1/partner/whatsapp/agent-settings` | body: any one or more of ~10 optional fields (`assistantName, greetingOptions, catering, privateBooking, website, style, showReferenceNumbers, bookingNote, gstPercent, dishImages, managerNumbers`), `.min(1)` |
| GET | `/v1/partner/whatsapp/campaigns/audience-segments` | result: `{options:[...]}` |

```bash
bash $SKILL/partner_misc.sh agent-settings get
bash $SKILL/partner_misc.sh agent-settings update assistantName "Nova"
bash $SKILL/partner_misc.sh audience-segments
```

### Order History: Active Order By Table (partner bearer)

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/partner/order-history/active-by-table/:tableId` | `result.cart` is null if the table has no active order |

```bash
bash $SKILL/partner_misc.sh active-order <tableId>
```

### Diner Extensions (Bearer diner)

`GET /v1/genie/combo` + `/v1/genie/combo/:comboId` match the shape already documented above under
"Combo Fetching" — included here again for completeness since they're part of this update pass.

| Method | Route | Notes |
|--------|-------|-------|
| GET | `/v1/genie/combo` | list; query: `comboId, comboName, isActive, sortBy, limit, page` |
| GET | `/v1/genie/combo/:comboId` | single combo detail |
| GET | `/v1/genie/order/:orderId` | order detail (same controller the partner side uses) |
| POST | `/v1/genie/profile/link-identity` | body: `{field:"phone", value, code}` — `field` only accepts `"phone"` today, `value` must be E.164, `code` is a 6-digit OTP string |

```bash
bash $SKILL/diner_ext.sh combo list
bash $SKILL/diner_ext.sh combo get 69f8757fd475a8cf66ed94f2
bash $SKILL/diner_ext.sh order-detail <orderId>
bash $SKILL/diner_ext.sh link-identity phone +15551234567 123456
```
