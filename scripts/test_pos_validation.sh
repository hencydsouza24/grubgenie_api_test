#!/bin/bash

# Test POS validation (Petpooja)
# Validates that API correctly rejects invalid Petpooja itemId and variationId values

set -e

BASE_URL="${BASE_URL:-http://localhost:3000/api}"
TOKEN="${TOKEN:-your_bearer_token_here}"

echo "=== Testing POS Validation (Petpooja) ==="

# Fetch real foodCategoryId
echo "Fetching foodCategoryId..."
CAT_RESPONSE=$(curl -s -X GET "$BASE_URL/v1/partner/food-category" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

CAT_ID=$(echo "$CAT_RESPONSE" | jq -r '.[0].id')
echo "Using foodCategoryId: $CAT_ID"

# Fetch real foodTypeId
echo "Fetching foodTypeId..."
FT_RESPONSE=$(curl -s -X GET "$BASE_URL/v1/partner/food-type" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

FT_ID=$(echo "$FT_RESPONSE" | jq -r '.[0].id')
echo "Using foodTypeId: $FT_ID"

# Define base menu item structure
BASE_BODY=$(cat <<BODY
{
  "item_name": "Test Item",
  "foodCategoryId": "$CAT_ID",
  "foodTypeId": "$FT_ID",
  "description": "Test description",
  "oPrice": 100,
  "portion": "Full",
  "spicinessLevel": 1,
  "dietaryPreference": "vegetarian",
  "image": "https://example.com/test.jpg"
}
BODY
)

# Test 1: Invalid itemId
echo ""
echo "Test 1: Testing invalid Petpooja itemId..."
INVALID_ITEM_BODY=$(echo "$BASE_BODY" | jq --arg id "this_id_does_not_exist_in_pos" '. + {pos: {petpooja: {itemId: $id}}}')

RESPONSE=$(curl -s -X POST "$BASE_URL/v1/partner/menu" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$INVALID_ITEM_BODY")

echo "Response: $RESPONSE"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/v1/partner/menu" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$INVALID_ITEM_BODY")

if [ "$HTTP_CODE" -ge 400 ]; then
  echo "✓ Invalid itemId correctly rejected (HTTP $HTTP_CODE)"
else
  echo "✗ Invalid itemId was NOT rejected (HTTP $HTTP_CODE)"
fi

# Test 2: Invalid variationId
echo ""
echo "Test 2: Testing invalid Petpooja variationId..."
INVALID_VAR_BODY=$(echo "$BASE_BODY" | jq '. + {variants: [{pos: {petpooja: {variationId: "invalid_variation_id"}}}]}')

RESPONSE=$(curl -s -X POST "$BASE_URL/v1/partner/menu" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$INVALID_VAR_BODY")

echo "Response: $RESPONSE"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/v1/partner/menu" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$INVALID_VAR_BODY")

if [ "$HTTP_CODE" -ge 400 ]; then
  echo "✓ Invalid variationId correctly rejected (HTTP $HTTP_CODE)"
else
  echo "✗ Invalid variationId was NOT rejected (HTTP $HTTP_CODE)"
fi

echo ""
echo "=== POS Validation Tests Complete ==="
