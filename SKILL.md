---
name: grubgenie-api-test
description: |
  GrubGenie API testing skill. Provides ready-to-run helper scripts and curl commands for all
  GrubGenie API flows. Supports local (localhost:3000), dev (dev-backend.grubgenie.ai), and
  prod (backend.grubgenie.ai) environments via selectable env.sh / env.ps1. Works on macOS,
  Linux, Windows (Git Bash), and Windows (PowerShell). Includes test credentials, token
  extraction patterns, and complete E2E flows (dine-in, pay-in-person, Stripe payment, partner
  management, admin, agent testing, combo ordering, order approval/rejection). Use when testing
  GrubGenie APIs, verifying new features, debugging endpoint behavior, walking through the
  diner/partner/admin flows interactively, or reproducing auth/permission bugs.
allowed-tools: "Bash(python:*) Bash(npm:*) Bash(bash:*) WebFetch mcp__plugin_context-mode_context-mode__ctx_execute mcp__plugin_context-mode_context-mode__ctx_search mcp__plugin_context-mode_context-mode__ctx_batch_execute"
---

# GrubGenie API Test Skill

## Onboarding (First Time Setup)

### macOS / Linux

**Step 1 — Install dependencies:**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install -y jq curl
```

**Step 2 — Set your skill path:**
```bash
export SKILL=~/.claude/skills/grubgenie-api-test/scripts
```

**Step 3 — Pick environment, authenticate, test:**
```bash
eval "$(bash $SKILL/env.sh local)"   # http://localhost:3000
eval "$(bash $SKILL/env.sh dev)"     # https://dev-backend.grubgenie.ai
eval "$(bash $SKILL/env.sh prod)"    # https://backend.grubgenie.ai

eval "$(bash $SKILL/auth.sh)"
bash $SKILL/fetch_menu.sh restaurant-info
```

---

### Windows — Option A: PowerShell (recommended)

No extra dependencies — PowerShell ships with `Invoke-RestMethod` (JSON-native).

**Step 1 — Set your skill path:**
```powershell
$SKILL = "$HOME\.claude\skills\grubgenie-api-test\scripts\powershell"
```

**Step 2 — Pick environment, authenticate, test:**
```powershell
. $SKILL\env.ps1 local    # http://localhost:3000
. $SKILL\env.ps1 dev      # https://dev-backend.grubgenie.ai
. $SKILL\env.ps1 prod     # https://backend.grubgenie.ai

. $SKILL\auth.ps1
```

**Full E2E dine-in flow:**
```powershell
. $SKILL\flow_dine_in_pay.ps1 -ItemId 691bf10018f1d3c34db1db00 -Qty 2
```

**Step by step:**
```powershell
. $SKILL\auth.ps1
. $SKILL\create_cart.ps1
. $SKILL\order_item.ps1 -ItemId 691bf10018f1d3c34db1db00 -Qty 2
```

---

### Windows — Option B: Git Bash

Requires bash + curl + jq.

1. Install **Git for Windows**: https://git-scm.com/download/win
2. Install **jq**:
   - Download `jq-windows-amd64.exe` from https://github.com/jqlang/jq/releases
   - Rename to `jq.exe`, place in `C:\Program Files\Git\usr\bin\`
3. Open **Git Bash**
4. Run scripts exactly like macOS/Linux:
```bash
export SKILL="$HOME/.claude/skills/grubgenie-api-test/scripts"
eval "$(bash $SKILL/env.sh dev)"
eval "$(bash $SKILL/auth.sh)"
bash $SKILL/fetch_menu.sh restaurant-info
```

---

## Quick Start

All helper scripts live in `scripts/`. Choose your environment with `env.sh` before auth.

```bash
SKILL=/path/to/grubgenie-api-test/scripts

# Step 1: Set environment (local | dev | prod)
eval "$(bash $SKILL/env.sh local)"

# Step 2: Authenticate (sets PARTNER_TOKEN, DINER_TOKEN, DINER_ID, TABLE_ID, BASE)
eval "$(bash $SKILL/auth.sh)"

# Step 2: Create a cart
export CART_ID=$(bash $SKILL/create_cart.sh)

# Step 3: Order items and run E2E
bash $SKILL/order_item.sh 691bf10018f1d3c34db1db00 2          # Order Ulli Vada x2
bash $SKILL/flow_dine_in_pay.sh                              # Complete: place → accept → pay
```

**Full E2E in one command:**
```bash
bash $SKILL/flow_dine_in_pay.sh [itemId] [qty]
```

---

## Core Rules (MUST Follow)

### Rule 1: Script-First Methodology

**Every operation has a pre-built script. Use it. Never write curl manually.**

For all standard operations:
```bash
eval "$(bash $SKILL/auth.sh)"           # All users + tokens
export CART_ID=$(bash $SKILL/create_cart.sh)
bash $SKILL/order_item.sh <itemId> [qty]
bash $SKILL/order_combo.sh [comboId] [qty]
bash $SKILL/flow_dine_in_pay.sh         # Full E2E (place → approve → pay)
bash $SKILL/branch_pos_config.sh [setup|get|disable]
bash $SKILL/fetch_menu.sh [command]
bash $SKILL/agent_test.sh "<message>"
bash $SKILL/reset_tables.sh
```

**Why:**
- Correct token extraction and variable handling
- Consistent request formatting across all flows
- Proper error handling and retries
- Testability and debuggability

### Rule 2: Non-Standard Operations → Context-Mode Sandbox

If no script exists for your operation, **do NOT write curl manually**. Use context-mode:

```bash
mcp_context_mode_ctx_execute(
  language: "shell",
  code: """
    SKILL=/path/to/grubgenie-api-test/scripts
    eval "$(bash $SKILL/auth.sh 2>/dev/null)"
    curl -s -X PATCH "$BASE/v1/partner/order-history/respond/ORDER_ID" \\
      -H "Authorization: Bearer $PARTNER_TOKEN" \\
      -H 'Content-Type: application/json' \\
      -d '{"action":"accept","modifications":[{"itemId":"<id>","quantity":2}]}'
  """
)
```

**Benefits:**
- HTTP calls don't flood context (output captured in sandbox)
- Proper token handling via auth.sh
- Response data searchable via context-mode search

### Rule 3: Token Expiry → Re-auth

If you get 401, tokens expired. Re-run:
```bash
eval "$(bash $SKILL/auth.sh)"
```

### Rule 4: Error Handling

When a script fails:
1. Re-run auth: `eval "$(bash $SKILL/auth.sh)"`
2. Check server logs
3. Refer to "Key API Facts" section (below) and "Debugging Tips" in references

---

## Helper Scripts Reference

### Script Inventory

**Bash (macOS / Linux / Git Bash on Windows):**

| Script | Purpose | Usage |
|--------|---------|-------|
| `env.sh` | Select target environment | `eval "$(bash $SKILL/env.sh [local\|dev\|prod])"` |
| `auth.sh` | Partner + diner auth, first table | `eval "$(bash $SKILL/auth.sh)"` |
| `create_cart.sh` | Create cart for session | `export CART_ID=$(bash $SKILL/create_cart.sh)` |
| `order_item.sh` | Order menu item | `bash $SKILL/order_item.sh <itemId> [qty]` |
| `order_combo.sh` | Order combo | `bash $SKILL/order_combo.sh [comboId] [qty]` |
| `flow_dine_in_pay.sh` | Full E2E dine-in + pay | `bash $SKILL/flow_dine_in_pay.sh [itemId] [qty]` |
| `get_pos_menu.sh` | Fetch POS menu with real IDs | `bash $SKILL/get_pos_menu.sh` |
| `sync_pos_menu.sh` | Trigger POS menu sync queue job | `bash $SKILL/sync_pos_menu.sh [petpooja]` |
| `test_pos_validation.sh` | Test POS ID validation | `bash $SKILL/test_pos_validation.sh` |
| `branch_pos_config.sh` | Petpooja POS config | `bash $SKILL/branch_pos_config.sh [setup\|get\|disable]` |
| `fetch_menu.sh` | Browse menu | `bash $SKILL/fetch_menu.sh [items\|categories\|restaurant-info]` |
| `agent_test.sh` | Agent chat | `bash $SKILL/agent_test.sh "<message>" [dinerId]` |
| `reset_tables.sh` | Reset all tables | `bash $SKILL/reset_tables.sh` |

**PowerShell (Windows — dot-source with `. script.ps1`):**

| Script | Purpose | Usage |
|--------|---------|-------|
| `powershell\env.ps1` | Select target environment | `. $SKILL\env.ps1 [local\|dev\|prod]` |
| `powershell\auth.ps1` | Partner + diner auth, first table | `. $SKILL\auth.ps1` |
| `powershell\create_cart.ps1` | Create cart for session | `. $SKILL\create_cart.ps1` |
| `powershell\order_item.ps1` | Order menu item | `. $SKILL\order_item.ps1 -ItemId <id> [-Qty 2]` |
| `powershell\flow_dine_in_pay.ps1` | Full E2E dine-in + pay | `. $SKILL\flow_dine_in_pay.ps1 [-ItemId <id>] [-Qty 2]` |

### Script Dependencies

Scripts assume these environment variables (set by `auth.sh`):
- `PARTNER_TOKEN` — partner bearer token
- `DINER_TOKEN` — diner bearer token
- `DINER_ID` — diner ObjectId
- `TABLE_ID` — table id
- `BASE` — `http://localhost:3000`

For ordering scripts (`order_item.sh`, `order_combo.sh`), also set:
```bash
export CART_ID=<from create_cart.sh>
```

---

## Common Workflows

### Workflow 1: Basic Order (Dine-In, Pay-In-Person)

```bash
SKILL=/path/to/grubgenie-api-test/scripts

# 1. Auth
eval "$(bash $SKILL/auth.sh)"

# 2. Create cart
export CART_ID=$(bash $SKILL/create_cart.sh)

# 3. Add items
bash $SKILL/order_item.sh 691bf10018f1d3c34db1db00 2

# 4. Place order
bash $SKILL/flow_dine_in_pay.sh
```

### Workflow 2: Menu Exploration

```bash
bash $SKILL/fetch_menu.sh items              # List all items
bash $SKILL/fetch_menu.sh categories         # List categories
bash $SKILL/fetch_menu.sh restaurant-info    # Get restaurant details
bash $SKILL/fetch_menu.sh search pizza       # Search
```

### Workflow 3: POS Integration Testing (Petpooja)

#### IMPORTANT: Always Use Real POS Menu IDs

Never use dummy or hardcoded item IDs when testing POS integration. Always fetch the POS menu first to get real item IDs from Petpooja.

#### Step 1: Fetch POS Menu Structure

```bash
bash $SKILL/get_pos_menu.sh
```

**What it returns:**
- 33 categories from Petpooja
- Item list for each category (currently empty - 0 items)
- Variation IDs for each item (when available)

#### Step 2: Extract Real Item ID

Once Petpooja restaurant has items in the menu:

```bash
ITEM_ID=$(bash $SKILL/get_pos_menu.sh | jq '.categories[0].items[0].itemid' -r)
echo "Using POS item: $ITEM_ID"
```

#### Step 3: Create Menu Item with POS Link

```bash
curl -s -X POST "$BASE/v1/partner/menu" \
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
```

#### Step 4: Verify POS Validation

Test that invalid IDs are properly rejected:

```bash
bash $SKILL/test_pos_validation.sh
```

**Expected output:**
```json
{
  "status": 400,
  "message": "POS item not found"
}
```

This proves validation is working correctly!

#### Step 5: Sync POS Menu into GrubGenie

Trigger a background job that imports the Petpooja menu into GrubGenie:

```bash
bash $SKILL/sync_pos_menu.sh
```

Or manually via curl:

```bash
curl -s -X POST "$BASE/v1/partner/pos/sync-menu" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"provider":"petpooja"}'
```

**Response (202 Accepted):**
```json
{ "message": "Menu sync started", "result": { "jobId": "..." } }
```

**Conflict (409):** If sync already running:
```json
{ "message": "Menu sync already in progress" }
```

#### Step 6: Monitor Sync Progress via Socket

The sync job emits progress over the `posMenuImport` socket channel. To check status without a live socket, poll the status endpoint:

```bash
# Via socket event (emit → receive on same channel)
# Event name:  posMenuImport
# Payload to emit:  { customDomain: "munch2", branchId: "3XSJT" }
# Response shape:
# { syncing: true,  message: "[pos] Fetching categories..." }
# { syncing: false, message: "[pos] Menu sync complete", refreshMenuData: true }
# { syncing: false, message: "[pos] Menu sync failed: ...", refreshMenuData: false }
```

**Socket channel map (all separate):**

| Channel key | Event name | Purpose |
|-------------|------------|---------|
| `menuOcr` | `menuOcr` | OCR upload status |
| `posMenuImport` | `posMenuImport` | POS sync job progress |
| `imageGen` | `imageGen` | AI image generation status |

#### Current Limitations

- **Menu may be empty**: Petpooja restaurant (i4fwyk7e) has 0 items initially — use sync-menu to import
- **Structure works**: 33 categories are mapped from Petpooja correctly
- **Validation enforced**: System rejects invalid POS IDs (correct behavior!)

#### API Endpoints for POS Testing

| Endpoint | Purpose |
|----------|---------|
| `GET /v1/partner/pos/menu?provider=petpooja` | Fetch raw POS menu with real item IDs |
| `POST /v1/partner/pos/sync-menu` | Trigger async menu import (body: `{"provider":"petpooja"}`) |
| `POST /v1/partner/menu` | Create menu item linked to POS |
| `POST /v1/partner/menu/add-variant/:itemId` | Create variant linked to POS |

#### POS Configuration (Separate from Testing)

```bash
bash $SKILL/branch_pos_config.sh setup       # Enable POS (uses test credentials)
bash $SKILL/branch_pos_config.sh get         # View current config
bash $SKILL/branch_pos_config.sh disable     # Remove config
```

### Workflow 4: Order Approval/Rejection (Manual Acceptance)

Enable manual approval on branch:
```bash
curl -X PUT $BASE/v1/partner/branch/update-branch/3XSJT \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"orderAcceptanceMode":"manual"}'
```

Then place order (response: "Order submitted for approval"). Accept/reject:
```bash
# Accept with modifications
curl -X PATCH $BASE/v1/partner/order-history/respond/$ORDER_ID \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"action":"accept","modifications":[{"itemId":"<id>","quantity":2}]}'

# Reject
curl -X PATCH $BASE/v1/partner/order-history/respond/$ORDER_ID \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"action":"reject","rejectionReason":"Item out of stock"}'
```

**Rules:**
- `action` required: `"accept"` or `"reject"`
- `rejectionReason` required on reject; forbidden on accept
- `modifications` allowed only on accept (not reject)
- Each modification: XOR `itemId`/`comboId` + `quantity` ≥ 1

---

## Key API Facts (Common Mistakes)

| Mistake | Fix |
|---------|-----|
| Partner token at `result.tokens.access.token` | ✅ Use `result.accessToken` |
| Diner ID at `result.diner._id` | ✅ Use `result._id` |
| Cart ID at `result._id` | ✅ Use `result.cartId` |
| Order ID: use order `_id` | ✅ Use `result.currentActiveOrder` |
| Order route: `POST /v1/genie/order` with body params | ✅ Use query params: `?cartId=:cartId&dinerId=:dinerId` |
| Combo order: use `itemId` key | ✅ Use `comboId` key |
| Place order route: `PUT /v1/genie/order/:orderId` | ✅ Add query param: `?cartId=:cartId` |
| branchId from token | ✅ Decode JWT: `echo "$PARTNER_TOKEN" \| cut -d'.' -f2 \| tr '_-' '/+' \| base64 -d 2>/dev/null \| jq .` |
| munch2 branchId | `3XSJT` |
| Payment blocked | ✅ Partner must accept/reject all pending orders first |
| Modifications on reject | ✅ Forbidden — use `rejectionReason` instead |
| POS config in branch create/update | ✅ Use dedicated `/v1/partner/branch/pos-config` endpoints |
| POS creds visible to diners | ✅ Hidden from diner APIs, only partner APIs |
| Sync-menu returns 404/500 | ✅ POS config not set — run `branch_pos_config.sh setup` first |
| Sync-menu returns 409 | ✅ Job already running — wait for it to complete or socket to emit `syncing: false` |
| Socket: listen on combined ocr/pos channel | ✅ Channels are separate: `menuOcr`, `posMenuImport`, `imageGen` |
| Agent menu route: `/v1/agents/*` | ✅ Use `/v1/agents/menu/*` |
| Order items field: `items` | ✅ Use `orderDetails` array |

---

## Quick Reference Cheat Sheet

### Test Credentials

```
Partner: munch@yopmail.com / Test@123 (branchId: 3XSJT)
Diner:   fingerprint: grubgenie-stripe-test-002
Admin:   hello@grubgenie.ai / $$grubgod123
```

### Known Test Data (munch2)

```
Snack Combo:  69f8757fd475a8cf66ed94f2 (24 AED)
Ulli Vada:    691bf10018f1d3c34db1db00 (12 AED)
Test Diner:   69f89034e0a784fea33a0d12
```

### Petpooja Credentials (Test)

```
appKey:    xz8swugh0vp9oymdab2tkne1qr5c3i67
restId:    i4fwyk7e
```

### Token Extraction

```bash
# Set endpoint (defaults to localhost:3000)
export BASE=http://localhost:3000

# Partner token
PARTNER_TOKEN=$(curl -s -X POST $BASE/v1/partner/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"munch@yopmail.com","password":"Test@123"}' | jq -r '.result.accessToken')

# Diner auth
DINER_RESPONSE=$(curl -s "$BASE/v1/genie/diner?customDomain=munch2&branchId=3XSJT&fingerprint=grubgenie-stripe-test-002")
DINER_TOKEN=$(echo $DINER_RESPONSE | jq -r '.result.accessToken')
DINER_ID=$(echo $DINER_RESPONSE | jq -r '.result._id')
```

---

## References

### Navigation

- **Full API routes + schemas**: `references/api_reference.md`
- **Auth, permissions, security bugs**: `references/auth_security.md`
- **Order approval flows, variant selection, success pages**: `references/advanced_flows.md`
- **Petpooja integration, credentials, setup**: `references/petpooja_setup.md`
- **Debugging errors and edge cases**: `references/debugging_guide.md`

### What Lives Where

- **SKILL.md** (this file): Overview, quick start, script inventory, core rules, cheat sheet
- **api_reference.md**: Full route map, test credentials, complete curl examples
- **auth_security.md**: Permission system, auth middleware details, known bugs
- **advanced_flows.md**: Order approval/rejection, variant selection, success pages, POS config edge cases
- **petpooja_setup.md**: Petpooja credentials, integration, setup guide
- **debugging_guide.md**: Common errors, troubleshooting, context-mode patterns

---

## Status

✅ **All 9 helper scripts validated and working**
✅ **Order approval/rejection flow** (manual & auto)
✅ **Variant selection** (pricing override, validation)
✅ **Petpooja POS** (multi-provider ready, credentials hidden)
✅ **POS menu sync** (`POST /v1/partner/pos/sync-menu` → BullMQ job → socket progress)
✅ **Separate socket channels** (`menuOcr`, `posMenuImport`, `imageGen`)
✅ **Context-mode integration** (batch execute, search, sandbox)
