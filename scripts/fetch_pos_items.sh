#!/bin/bash
# Fetch POS items with GrubGenie link status
# Returns raw Petpooja items + which ones are already linked to GrubGenie menu items/variants

SKILL=$(dirname "$0")
eval "$(bash $SKILL/auth.sh 2>/dev/null)"

PROVIDER=${1:-petpooja}

curl -s -X GET "$BASE/v1/partner/pos/$PROVIDER/items" \
  -H "Authorization: Bearer $PARTNER_TOKEN"
