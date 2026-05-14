#!/usr/bin/env bash
# Fetch menu data — browse items, categories, food types, restaurant info.
# Usage: bash fetch_menu.sh [command] [arg]
# Requires: DINER_TOKEN (from auth.sh). PARTNER_TOKEN needed for partner commands.
#
# Commands:
#   items              List all menu items (default)
#   items <categoryId> Items filtered by category ID
#   items-search <q>   Search items by name (partner token)
#   categories         List food categories
#   food-types         List food types
#   restaurant-info    Restaurant info (name, logo, address)
#   branches           Restaurant branches (no auth needed)
#   item <id>          Single item by ID (partner token)
#   partner-items      List all items via partner route
#   dietary            Available dietary preferences
#   allergens          Available allergens
#   offers             Active offers
#   combos             List all combos (diner token)
#   combo <id>         Single combo by ID (diner token)
#   partner-combos     List combos via partner route (partner token)
#   partner-combo <id> Single combo via partner route (partner token)
#   reels              Menu item reels (diner token)
#   stories            Menu item stories (diner token)
#   item-by-media <id> Item by media ID (diner token)

set -euo pipefail
BASE=${BASE:-http://localhost:3000}
CMD=${1:-items}

case "$CMD" in
  items)
    CATEGORY=${2:-}
    URL="$BASE/v1/genie/menu"
    [ -n "$CATEGORY" ] && URL="$URL?foodCategoryId=$CATEGORY"
    curl -s "$URL" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '{total: .totalResults, pages: .totalPages, items: [.result[] | {_id, name: .item_name, price: .oPrice, dPrice, category: .foodCategoryId, isActive}]}'
    ;;

  items-search)
    Q=${2:?"Usage: fetch_menu.sh items-search <query>"}
    curl -sG "$BASE/v1/partner/menu/item/search" \
      --data-urlencode "q=$Q" \
      -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | {_id, name: .itemName, price}'
    ;;

  categories)
    curl -s "$BASE/v1/genie/menu/food-category" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .food_category, sequence}'
    ;;

  food-types)
    curl -s "$BASE/v1/genie/menu/food-type" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name}'
    ;;

  restaurant-info)
    curl -s "$BASE/v1/genie/menu/restaurant-info" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result | {name: .restaurantName, logo: .logoURL, address: .address}'
    ;;

  branches)
    DOMAIN=${2:-munch2}
    curl -s "$BASE/v1/genie/menu/restaurant-branches/$DOMAIN" | jq '.result | {name: .restaurantName, branches: [.branches[]? | {_id, name: .branchName}]}'
    ;;

  item)
    ITEM_ID=${2:?"Usage: fetch_menu.sh item <menuItemId>"}
    curl -s "$BASE/v1/partner/menu/item/$ITEM_ID" \
      -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result | {_id, name: .itemName, price, category: .foodCategory, isActive}'
    ;;

  partner-items)
    curl -s "$BASE/v1/partner/menu/item" \
      -H "Authorization: Bearer $PARTNER_TOKEN" | jq '{total: .totalResults, items: [.result[] | {_id, name: .item_name, price: .oPrice, isActive}]}'
    ;;

  dietary)
    curl -s "$BASE/v1/genie/menu/dietary-preference" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result'
    ;;

  allergens)
    curl -s "$BASE/v1/genie/menu/allergens" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result'
    ;;

  offers)
    curl -s "$BASE/v1/genie/menu/offers" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result'
    ;;

  combos)
    curl -s "$BASE/v1/genie/combo" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result[] | {_id, name: .comboName, price: .dPrice, isActive}'
    ;;

  combo)
    COMBO_ID=${2:?"Usage: fetch_menu.sh combo <comboId>"}
    curl -s "$BASE/v1/genie/combo/$COMBO_ID" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result | {_id, name: .comboName, price: .dPrice, isActive, items: [.items[]? | {itemId: .menuItemId, qty: .quantity}]}'
    ;;

  partner-combos)
    curl -s "$BASE/v1/partner/combo" \
      -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result[] | {_id, name: .comboName, price: .dPrice, isActive}'
    ;;

  partner-combo)
    COMBO_ID=${2:?"Usage: fetch_menu.sh partner-combo <comboId>"}
    curl -s "$BASE/v1/partner/combo/$COMBO_ID" \
      -H "Authorization: Bearer $PARTNER_TOKEN" | jq '.result | {_id, name: .comboName, price: .dPrice, isActive, items: [.items[]? | {itemId: .menuItemId, qty: .quantity}]}'
    ;;

  reels)
    curl -s "$BASE/v1/genie/menu/reels" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result'
    ;;

  stories)
    curl -s "$BASE/v1/genie/menu/stories" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result'
    ;;

  item-by-media)
    MEDIA_ID=${2:?"Usage: fetch_menu.sh item-by-media <mediaId>"}
    curl -s "$BASE/v1/genie/menu/item-by-media-id?mediaId=$MEDIA_ID" \
      -H "Authorization: Bearer $DINER_TOKEN" | jq '.result'
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    echo "Commands: items [categoryId] | items-search <q> | categories | food-types | restaurant-info | branches [domain] | item <id> | partner-items | dietary | allergens | offers | combos | combo <id> | partner-combos | partner-combo <id> | reels | stories | item-by-media <mediaId>" >&2
    exit 1
    ;;
esac
