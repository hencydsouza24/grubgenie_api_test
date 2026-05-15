#!/bin/bash

# Test branch POS configuration (Petpooja integration)
# Uses dedicated POS config endpoints:
#   GET    /v1/partner/branch/pos-config           - List POS configs
#   PUT    /v1/partner/branch/pos-config           - Upsert POS config
#   DELETE /v1/partner/branch/pos-config/:provider  - Remove POS config
#
# Usage:
#   bash branch_pos_config.sh setup                    # Enable POS on branch
#   bash branch_pos_config.sh get                      # Get POS config
#   bash branch_pos_config.sh disable                  # Disable (delete) POS config

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE=${BASE:-"http://localhost:3000"}

# Ensure auth is set
if [ -z "$PARTNER_TOKEN" ]; then
  eval "$(bash $SKILL_DIR/auth.sh 2>/dev/null)"
fi

ACTION="${1:-get}"

case $ACTION in
  setup|enable)
    echo "Setting up Petpooja POS config via PUT /v1/partner/branch/pos-config"
    curl -s -X PUT "$BASE/v1/partner/branch/pos-config" \
      -H "Authorization: Bearer $PARTNER_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{
        "provider": "petpooja",
        "isEnabled": true,
        "credentials": {
          "appKey": "xz8swugh0vp9oymdab2tkne1qr5c3i67",
          "appSecret": "1c54ca0d1f1f84bc9bfec49b9a2efd7852bdef59",
          "accessToken": "c6038984b2ce7e1797f7ddc5b73641e1add36bf4",
          "restId": "i4fwyk7e"
        }
      }' | jq '.'
    ;;
  disable|delete)
    echo "Deleting Petpooja POS config via DELETE /v1/partner/branch/pos-config/petpooja"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/v1/partner/branch/pos-config/petpooja" \
      -H "Authorization: Bearer $PARTNER_TOKEN")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    echo "HTTP $HTTP_CODE"
    [ -n "$BODY" ] && echo "$BODY" | jq '.' 2>/dev/null || echo "(empty body)"
    ;;
  get)
    echo "Getting POS config via GET /v1/partner/branch/pos-config"
    curl -s "$BASE/v1/partner/branch/pos-config" \
      -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.'
    ;;
  *)
    echo "Usage: branch_pos_config.sh [setup|disable|get]"
    echo "  setup    - Enable Petpooja POS on branch (PUT /pos-config)"
    echo "  disable  - Delete Petpooja POS config (DELETE /pos-config/petpooja)"
    echo "  get      - Show POS config (GET /pos-config)"
    exit 1
    ;;
esac
