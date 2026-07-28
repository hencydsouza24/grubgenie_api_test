#!/usr/bin/env bash
# Fetch menu data — browse items, categories, food types, restaurant info.
# Usage: bash fetch_menu.sh [command] [arg]
# Auths itself (see auth.sh) if no session exists yet or the existing one has expired.
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
#
# RESP is always captured into a variable before piping to jq — NOT `gg_http_or_die ... | jq`.
# Under `set -o pipefail`, a pipeline's reported status is the RIGHTMOST non-zero exit, so a
# failed gg_http_or_die piped straight into jq risks jq's own exit code (parsing empty/partial
# input) masking the real failure. Capture-then-jq sidesteps it entirely.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

CMD="${1:-items}"

case "$CMD" in
  items)
    CATEGORY="${2:-}"
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    if [ -n "$CATEGORY" ]; then
      RESP="$(gg_http_or_die "menu items" GET "/v1/genie/menu" --token "$DINER_TOKEN" --query "foodCategoryId=${CATEGORY}")" || exit $?
    else
      RESP="$(gg_http_or_die "menu items" GET "/v1/genie/menu" --token "$DINER_TOKEN")" || exit $?
    fi
    echo "$RESP" | jq '{total: .totalResults, pages: .totalPages, items: [.result[] | {_id, name: .item_name, price: .oPrice, dPrice, category: .foodCategoryId, isActive}]}'
    ;;

  items-search)
    Q="${2:-}"
    gg_require "$Q" "Usage: fetch_menu.sh items-search <query>"
    PARTNER_TOKEN="$(gg_session_get partnerToken)" || exit $?
    RESP="$(gg_http_or_die "item search" GET "/v1/partner/menu/item/search" --token "$PARTNER_TOKEN" --query "q=${Q}")" || exit $?
    echo "$RESP" | jq '.result[] | {_id, name: .itemName, price}'
    ;;

  categories)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "categories" GET "/v1/genie/menu/food-category" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result[] | {_id, name: .food_category, sequence}'
    ;;

  food-types)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "food types" GET "/v1/genie/menu/food-type" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result[] | {_id, name}'
    ;;

  restaurant-info)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "restaurant info" GET "/v1/genie/menu/restaurant-info" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result | {name: .restaurantName, logo: .logoURL, address: .address}'
    ;;

  branches)
    DOMAIN="${2:-$GG_CUSTOM_DOMAIN}"
    RESP="$(gg_http_or_die "branches" GET "/v1/genie/menu/restaurant-branches/${DOMAIN}")" || exit $?
    echo "$RESP" | jq '.result | {name: .restaurantName, branches: [.branches[]? | {_id, name: .branchName}]}'
    ;;

  item)
    ITEM_ID="${2:-}"
    gg_require "$ITEM_ID" "Usage: fetch_menu.sh item <menuItemId>"
    PARTNER_TOKEN="$(gg_session_get partnerToken)" || exit $?
    RESP="$(gg_http_or_die "item" GET "/v1/partner/menu/item/${ITEM_ID}" --token "$PARTNER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result | {_id, name: .itemName, price, category: .foodCategory, isActive}'
    ;;

  partner-items)
    PARTNER_TOKEN="$(gg_session_get partnerToken)" || exit $?
    RESP="$(gg_http_or_die "partner items" GET "/v1/partner/menu/item" --token "$PARTNER_TOKEN")" || exit $?
    echo "$RESP" | jq '{total: .totalResults, items: [.result[] | {_id, name: .item_name, price: .oPrice, isActive}]}'
    ;;

  dietary)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "dietary preferences" GET "/v1/genie/menu/dietary-preference" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  allergens)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "allergens" GET "/v1/genie/menu/allergens" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  offers)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "offers" GET "/v1/genie/menu/offers" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  combos)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "combos" GET "/v1/genie/combo" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result[] | {_id, name: .comboName, price: .dPrice, isActive}'
    ;;

  combo)
    COMBO_ID="${2:-}"
    gg_require "$COMBO_ID" "Usage: fetch_menu.sh combo <comboId>"
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "combo" GET "/v1/genie/combo/${COMBO_ID}" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result | {_id, name: .comboName, price: .dPrice, isActive, items: [.items[]? | {itemId: .menuItemId, qty: .quantity}]}'
    ;;

  partner-combos)
    PARTNER_TOKEN="$(gg_session_get partnerToken)" || exit $?
    RESP="$(gg_http_or_die "partner combos" GET "/v1/partner/combo" --token "$PARTNER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result[] | {_id, name: .comboName, price: .dPrice, isActive}'
    ;;

  partner-combo)
    COMBO_ID="${2:-}"
    gg_require "$COMBO_ID" "Usage: fetch_menu.sh partner-combo <comboId>"
    PARTNER_TOKEN="$(gg_session_get partnerToken)" || exit $?
    RESP="$(gg_http_or_die "partner combo" GET "/v1/partner/combo/${COMBO_ID}" --token "$PARTNER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result | {_id, name: .comboName, price: .dPrice, isActive, items: [.items[]? | {itemId: .menuItemId, qty: .quantity}]}'
    ;;

  reels)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "reels" GET "/v1/genie/menu/reels" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  stories)
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "stories" GET "/v1/genie/menu/stories" --token "$DINER_TOKEN")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  item-by-media)
    MEDIA_ID="${2:-}"
    gg_require "$MEDIA_ID" "Usage: fetch_menu.sh item-by-media <mediaId>"
    DINER_TOKEN="$(gg_session_get dinerToken)" || exit $?
    RESP="$(gg_http_or_die "item by media" GET "/v1/genie/menu/item-by-media-id" --token "$DINER_TOKEN" --query "mediaId=${MEDIA_ID}")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD. Commands: items [categoryId] | items-search <q> | categories | food-types | restaurant-info | branches [domain] | item <id> | partner-items | dietary | allergens | offers | combos | combo <id> | partner-combos | partner-combo <id> | reels | stories | item-by-media <mediaId>"
    ;;
esac
