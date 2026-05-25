#!/usr/bin/env bash
# Usage: eval "$(bash auth.sh)"
# Exports PARTNER_TOKEN, DINER_TOKEN, DINER_ID, TABLE_ID into the current shell.

set -euo pipefail
BASE=${BASE:-http://localhost:3000}

PARTNER_TOKEN=$(curl -s -X POST "$BASE/v1/partner/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"munchuser@yopmail.com","password":"Test@123"}' | jq -r '.result.accessToken')

TABLE_ID=$(curl -s "$BASE/v1/partner/table" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq -r '.result[0]._id')

DINER_RESPONSE=$(curl -s "$BASE/v1/genie/diner?customDomain=munch2&branchId=D13GZ&fingerprint=grubgenie-stripe-test-002")
DINER_TOKEN=$(echo "$DINER_RESPONSE" | jq -r '.result.accessToken')
DINER_ID=$(echo "$DINER_RESPONSE" | jq -r '.result._id')

echo "export BASE=$BASE"
echo "export PARTNER_TOKEN=$PARTNER_TOKEN"
echo "export TABLE_ID=$TABLE_ID"
echo "export DINER_TOKEN=$DINER_TOKEN"
echo "export DINER_ID=$DINER_ID"

echo "# Partner token: ${PARTNER_TOKEN:0:20}..." >&2
echo "# Table:         $TABLE_ID" >&2
echo "# Diner:         $DINER_ID" >&2
