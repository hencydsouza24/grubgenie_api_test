#!/bin/bash
# Fetch POS menu structure with actual item IDs

SKILL=$(dirname "$0")
eval "$(bash $SKILL/auth.sh 2>/dev/null)"

curl -s -X GET "http://localhost:3000/v1/partner/pos/menu?provider=petpooja" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
