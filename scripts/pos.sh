#!/usr/bin/env bash
# Petpooja POS integration — menu sync, config, and validation testing.
# Usage: bash pos.sh menu [provider]
#        bash pos.sh items [provider]
#        bash pos.sh sync [provider]
#        bash pos.sh config get|setup|disable [provider]
#        bash pos.sh validate
# Default provider: petpooja. `config setup` requires scripts/config/credentials.env — see
# credentials.example.env.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

CMD="${1:-}"
gg_require "$CMD" "Usage: pos.sh menu|items|sync|config|validate [args]"

case "$CMD" in
  menu)
    PROVIDER="${2:-$GG_POS_PROVIDER}"
    gg_pos_menu "$PROVIDER"
    ;;

  items)
    PROVIDER="${2:-$GG_POS_PROVIDER}"
    gg_pos_items "$PROVIDER"
    ;;

  sync)
    PROVIDER="${2:-$GG_POS_PROVIDER}"
    # 202 = job enqueued, 409 = sync already running — gg_pos_sync treats both as success.
    RESP="$(gg_pos_sync "$PROVIDER")" || exit $?
    echo "$RESP" | jq .
    ;;

  config)
    SUB="${2:-get}"
    case "$SUB" in
      get)     gg_pos_config_get ;;
      setup)   gg_pos_config_setup ;;
      disable) gg_pos_config_disable "${3:-$GG_POS_PROVIDER}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: pos.sh config get|setup|disable [provider]" ;;
    esac
    ;;

  validate)
    # Test that the API correctly rejects invalid Petpooja itemId/variationId values.
    # ONE request per case, not two — the original test_pos_validation.sh fired each POST twice
    # (once to capture the body, once via -w to capture the status), creating duplicate records.
    # --expect 400 turns "was this rejected?" into a single request's exit code.
    PARTNER_TOKEN="$(gg_session_get partnerToken)" || exit $?

    gg_info "Fetching foodCategoryId and foodTypeId..."
    CAT_RESP="$(gg_http_or_die "food category" GET "/v1/partner/food-category" --token "$PARTNER_TOKEN")" || exit $?
    CAT_ID="$(gg_json_field "$CAT_RESP" '.[0].id' "foodCategoryId")" || exit $?

    FT_RESP="$(gg_http_or_die "food type" GET "/v1/partner/food-type" --token "$PARTNER_TOKEN")" || exit $?
    FT_ID="$(gg_json_field "$FT_RESP" '.[0].id' "foodTypeId")" || exit $?

    BASE_BODY="$(jq -n --arg catId "$CAT_ID" --arg ftId "$FT_ID" '{
      item_name: "Test Item", foodCategoryId: $catId, foodTypeId: $ftId,
      description: "Test description", oPrice: 100, portion: "Full",
      spicinessLevel: 1, dietaryPreference: "vegetarian", image: "https://example.com/test.jpg"
    }')" || exit $?

    FAIL=0

    gg_info "Test 1: invalid Petpooja itemId"
    ITEM_BODY="$(echo "$BASE_BODY" | jq '. + {pos: {petpooja: {itemId: "this_id_does_not_exist_in_pos"}}}')" || exit $?
    if gg_http POST "/v1/partner/menu" --token "$PARTNER_TOKEN" --json "$ITEM_BODY" --expect 400 >/dev/null; then
      gg_info "PASS: invalid itemId correctly rejected (HTTP $(gg_http_status))"
    else
      gg_error "FAIL: invalid itemId was NOT rejected (HTTP $(gg_http_status))"
      FAIL=1
    fi

    gg_info "Test 2: invalid Petpooja variationId"
    VAR_BODY="$(echo "$BASE_BODY" | jq '. + {variants: [{pos: {petpooja: {variationId: "invalid_variation_id"}}}]}')" || exit $?
    if gg_http POST "/v1/partner/menu" --token "$PARTNER_TOKEN" --json "$VAR_BODY" --expect 400 >/dev/null; then
      gg_info "PASS: invalid variationId correctly rejected (HTTP $(gg_http_status))"
    else
      gg_error "FAIL: invalid variationId was NOT rejected (HTTP $(gg_http_status))"
      FAIL=1
    fi

    [ "$FAIL" -eq 0 ] && gg_info "=== POS Validation Tests: all passed ===" || gg_die "$GG_EXIT_CLIENT" "=== POS Validation Tests: FAILED ==="
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD (expected menu|items|sync|config|validate)"
    ;;
esac
