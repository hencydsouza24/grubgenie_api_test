#!/bin/bash
# Fetch POS menu structure with actual item IDs

SKILL=$(dirname "$0")
eval "$(bash $SKILL/auth.sh 2>/dev/null)"

curl -s -X GET "$BASE/v1/partner/pos/menu?provider=petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
