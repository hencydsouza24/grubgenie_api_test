# Petpooja POS Integration Setup

Complete guide for integrating Petpooja POS into GrubGenie. Includes credentials, validation, and full workflow.

## Important: Test Data Setup

### Current State
- **Restaurant**: i4fwyk7e (from Petpooja)
- **Menu**: Empty (33 categories, 0 items)
- **Status**: POS integration working, structure verified, just needs data

### To Enable Full POS Integration Testing

#### Option A: Add Test Items to Petpooja (RECOMMENDED)
1. Log into Petpooja partner portal (https://www.petpooja.com)
2. Navigate to restaurant i4fwyk7e
3. Add test menu items to categories
4. Run: `bash $SKILL/get_pos_menu.sh`
5. Extract real `itemId` values from response
6. Use these IDs for menu item creation and testing

**Benefits:**
- Tests validate real POS integration
- Detects issues with actual Petpooja API
- Ensures item linking works end-to-end

#### Option B: Wait for Production Data
- Once Petpooja restaurant is populated with actual items
- Menu endpoints will return real item data
- Full integration testing becomes possible

### Verification That It's Working

Test the POS menu endpoint (works even with empty menu):

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

# Fetch menu structure
bash $SKILL/get_pos_menu.sh | jq '.categories | length'
# Expected: 33

# Verify categories are mapped
bash $SKILL/get_pos_menu.sh | jq '.categories[0:3] | map(.categoryname)'
```

**This proves:**
- ✅ POS client is initialized correctly
- ✅ Authentication with Petpooja works
- ✅ Menu structure is fetched properly
- ✅ 33 categories mapped from Petpooja
- ⏳ Just waiting for menu items to be added

### Validation Rules (Currently Enforced)

#### When POS Item ID is Invalid
```bash
# Try to create menu item with non-existent POS itemId
curl -X POST "http://localhost:3000/v1/partner/menu" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Test Item",
    "oPrice": 100,
    "pos": {
      "petpooja": {
        "itemId": "does_not_exist_123"
      }
    }
  }'

# Response: 400 Bad Request
# Message: "POS item not found"
```

**This is correct behavior!** It proves:
- ✅ System validates POS IDs
- ✅ Invalid IDs are rejected
- ✅ Prevents bad data linking

#### When POS Item ID is Valid
```bash
# Extract real itemId from menu
ITEM_ID=$(bash $SKILL/get_pos_menu.sh | jq '.categories[0].items[0].itemid' -r)

# Create menu item with real ID
curl -X POST "http://localhost:3000/v1/partner/menu" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Samosa",
    "oPrice": 50,
    "pos": {
      "petpooja": {
        "itemId": "'$ITEM_ID'"
      }
    }
  }'

# Response: 201 Created
# Item is linked to POS
```

### Testing Without Menu Items

Use the validation test to confirm the system is enforcing rules:

```bash
bash $SKILL/test_pos_validation.sh

# Output:
# Testing: Invalid POS itemId should be rejected...
# {
#   "status": 400,
#   "message": "POS item not found"
# }
```

This validates that:
- Endpoints are responsive
- Validation is enforced
- Security is working (bad data rejected)

---

## Quick Setup

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

# Enable Petpooja POS on branch (uses test credentials)
bash $SKILL/branch_pos_config.sh setup

# View config
bash $SKILL/branch_pos_config.sh get

# Disable
bash $SKILL/branch_pos_config.sh disable
```

---

## Test Credentials

### Petpooja Account (munch2 restaurant)

| Field | Value |
|-------|-------|
| **appKey** | `xz8swugh0vp9oymdab2tkne1qr5c3i67` |
| **appSecret** | `1c54ca0d1f1f84bc9bfec49b9a2efd7852bdef59` |
| **accessToken** | `c6038984b2ce7e1797f7ddc5b73641e1add36bf4` |
| **restId** | `i4fwyk7e` |
| **baseUrl** | `https://qle1yy2ydc.execute-api.ap-southeast-1.amazonaws.com/V1` |

### Live Petpooja Setup

1. Create account at https://www.petpooja.com
2. Create a restaurant
3. Generate API credentials in POS settings
4. Note: `appKey` + `restId` are public; `appSecret` + `accessToken` are sensitive

---

## API Contract

### PUT (Upsert) Body

```json
{
  "provider": "petpooja",
  "isEnabled": true,
  "credentials": {
    "appKey": "string (required)",
    "appSecret": "string (required)",
    "accessToken": "string (required)",
    "restId": "string (required)"
  }
}
```

### Field Validation

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| provider | string | ✅ yes | Enum: `'petpooja'` only |
| isEnabled | boolean | ❌ no | Defaults to `true` |
| credentials.appKey | string | ✅ yes | Petpooja API key |
| credentials.appSecret | string | ✅ yes | Petpooja secret |
| credentials.accessToken | string | ✅ yes | OAuth token |
| credentials.restId | string | ✅ yes | Restaurant ID |

### Response

Successful upsert returns 200:
```json
{
  "success": true,
  "message": "POS config upserted successfully",
  "result": {
    "provider": "petpooja",
    "isEnabled": true,
    "credentials": {
      "appKey": "...",
      "restId": "..."
    }
  }
}
```

**Note**: `appSecret` and `accessToken` are stripped from response for security.

### Endpoints

| Method | Route | Purpose |
|--------|-------|---------|
| GET | `/v1/partner/branch/pos-config` | List all POS configs on branch |
| PUT | `/v1/partner/branch/pos-config` | Create/update provider config |
| DELETE | `/v1/partner/branch/pos-config/:provider` | Remove provider config |

---

## Full Integration Example

### Step 1: Enable POS on Branch

```bash
SKILL=/path/to/grubgenie-api-test/scripts
eval "$(bash $SKILL/auth.sh)"

# Upsert Petpooja config
curl -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "petpooja",
    "isEnabled": true,
    "credentials": {
      "appKey": "xz8swugh0vp9oymdab2tkne1qr5c3i67",
      "appSecret": "your_secret",
      "accessToken": "your_token",
      "restId": "i4fwyk7e"
    }
  }'
```

### Step 2: Verify Configuration

```bash
curl -s http://localhost:3000/v1/partner/branch/pos-config \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | {provider, isEnabled, credentials}'

# Response shows all configured providers
# Credentials appear in full for partner (striped from diner APIs)
```

### Step 3: Sync Menu Items to Petpooja

After POS is configured, menu items can be synced. Integration details depend on Petpooja SDK (see implementation).

```bash
# Example: Get all menu items
curl -s "http://localhost:3000/v1/genie/menu?branchId=3XSJT" \
  -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name, category}'

# Then sync to Petpooja via POS service
```

### Step 4: Disable POS (if needed)

```bash
curl -X DELETE "http://localhost:3000/v1/partner/branch/pos-config/petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"

# Response: HTTP 204 No Content (empty body, idempotent)
```

---

## Security Considerations

### Credential Storage

- Credentials stored in MongoDB with `select: false` on schema
- Credentials **hidden** from diner APIs (middleware blocks access)
- Credentials **visible** to partner APIs (token owner only)
- Never log credentials to stdout

### Access Control

| Role | Can Read | Can Write |
|------|----------|-----------|
| Diner | ❌ No | ❌ No |
| Partner (own branch) | ✅ Yes | ✅ Yes |
| Partner (other branch) | ❌ No | ❌ No |
| Admin | ✅ Yes (audit only) | ❌ No |

### Best Practices

1. **Rotate credentials regularly** — change `appSecret` + `accessToken` every 90 days
2. **Use environment variables** — never hardcode in scripts
3. **Audit access** — log all POS config changes
4. **Secure transmission** — always use HTTPS in production

---

## Validation Rules & Edge Cases

### Missing Required Field

```bash
# Error: appSecret missing
curl -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "petpooja",
    "credentials": {
      "appKey": "only_key"
    }
  }'

# Response: HTTP 400
# {
#   "success": false,
#   "message": "\"credentials.appSecret\" is required"
# }
```

### Invalid Provider

```bash
# Error: provider not in enum
curl -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "provider": "invalid-pos",
    "credentials": { ... }
  }'

# Response: HTTP 400
# {
#   "success": false,
#   "message": "\"provider\" must be one of [petpooja]"
# }
```

### Delete Non-Existent Provider (Idempotent)

```bash
# Delete same provider twice — both succeed
curl -X DELETE "http://localhost:3000/v1/partner/branch/pos-config/petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
# Response: HTTP 204 (first delete)

curl -X DELETE "http://localhost:3000/v1/partner/branch/pos-config/petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
# Response: HTTP 204 (second delete, still OK)
```

### Diner Tries to Access

```bash
curl -s http://localhost:3000/v1/partner/branch/pos-config \
  -H "Authorization: Bearer $DINER_TOKEN"

# Response: HTTP 403
# {
#   "success": false,
#   "message": "Forbidden"
# }
```

---

## Upsert Behavior (Multi-Provider)

When multiple providers are configured, upsert **merges by provider**.

### Example: Multiple Providers

```bash
# Add Petpooja
curl -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"provider": "petpooja", "credentials": {...}}'

# Add future provider (hypothetical)
curl -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"provider": "zomato-pos", "credentials": {...}}'

# Both providers now configured
curl -s http://localhost:3000/v1/partner/branch/pos-config \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | .provider'
# ["petpooja", "zomato-pos"]

# Update only Petpooja
curl -X PUT "http://localhost:3000/v1/partner/branch/pos-config" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"provider": "petpooja", "credentials": {...new...}}'

# Zomato still present, Petpooja updated
```

### Delete Specific Provider

```bash
# Remove only Petpooja, preserve others
curl -X DELETE "http://localhost:3000/v1/partner/branch/pos-config/petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"

# Other providers unaffected
```

---

## Implementation Status

✅ **POS Configuration Endpoints**: GET, PUT, DELETE — fully working
✅ **Validation**: All required fields, enum, type checks
✅ **Security**: Credentials hidden from diner APIs, partner-only access
✅ **Multi-Provider Ready**: Upsert-by-provider, no duplicates
✅ **Test Credentials**: Available for munch2 restaurant

⏳ **Future**: Menu sync to Petpooja, order push-back from POS
