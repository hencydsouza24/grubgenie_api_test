#!/usr/bin/env bash
# Partner catalog management — Combo CRUD, Menu bulk edit/delete/duplicate. Partner bearer auth.
#
# Usage: bash menu_manage.sh combo create <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [dPrice]
#        bash menu_manage.sh combo get <comboId>
#        bash menu_manage.sh combo update <comboId> [comboName] [isActive]
#        bash menu_manage.sh combo delete <comboId>
#        bash menu_manage.sh bulk-edit <idsCsv> <changesJson> [customizationMode]
#        bash menu_manage.sh bulk-delete <idsCsv>
#        bash menu_manage.sh duplicate <menuItemId> <foodCategoryId>
#
# idsCsv is a comma-separated list of menuItemIds, e.g. "id1,id2,id3". changesJson is a raw JSON
# object matching bulkEditChangesSchema, e.g. '{"chefsChoice":true}'. isActive is the literal
# string "true" or "false". Pass "" to skip an optional combo-update field while setting a later
# one, e.g. `combo update <id> "" true`.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

CMD="${1:-}"
gg_require "$CMD" "Usage: menu_manage.sh combo|bulk-edit|bulk-delete|duplicate [args]"

case "$CMD" in
  combo)
    SUB="${2:-}"
    case "$SUB" in
      create)
        COMBO_NAME="${3:-}"
        FOOD_CATEGORY_ID="${4:-}"
        FOOD_TYPE_ID="${5:-}"
        MENU_ITEM_ID="${6:-}"
        QUANTITY="${7:-}"
        gg_require "$COMBO_NAME" "Usage: menu_manage.sh combo create <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [dPrice]"
        gg_require "$QUANTITY" "Usage: menu_manage.sh combo create <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [dPrice]"
        RESP="$(gg_combo_create "$COMBO_NAME" "$FOOD_CATEGORY_ID" "$FOOD_TYPE_ID" "$MENU_ITEM_ID" "$QUANTITY" "${8:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      get)
        COMBO_ID="${3:-}"
        gg_require "$COMBO_ID" "Usage: menu_manage.sh combo get <comboId>"
        RESP="$(gg_combo_get "$COMBO_ID")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      update)
        COMBO_ID="${3:-}"
        gg_require "$COMBO_ID" "Usage: menu_manage.sh combo update <comboId> [comboName] [isActive]"
        RESP="$(gg_combo_update "$COMBO_ID" "${4:-}" "${5:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      delete)
        COMBO_ID="${3:-}"
        gg_require "$COMBO_ID" "Usage: menu_manage.sh combo delete <comboId>"
        gg_combo_delete "$COMBO_ID" >/dev/null || exit $?
        gg_info "Combo $COMBO_ID deleted"
        ;;
      *) gg_die "$GG_EXIT_USAGE" "Unknown combo subcommand: $SUB (expected create|get|update|delete)" ;;
    esac
    ;;

  bulk-edit)
    IDS_CSV="${2:-}"
    CHANGES_JSON="${3:-}"
    gg_require "$IDS_CSV" "Usage: menu_manage.sh bulk-edit <idsCsv> <changesJson> [customizationMode]"
    gg_require "$CHANGES_JSON" "Usage: menu_manage.sh bulk-edit <idsCsv> <changesJson> [customizationMode]"
    RESP="$(gg_menu_bulk_edit "$IDS_CSV" "$CHANGES_JSON" "${4:-}")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  bulk-delete)
    IDS_CSV="${2:-}"
    gg_require "$IDS_CSV" "Usage: menu_manage.sh bulk-delete <idsCsv>"
    RESP="$(gg_menu_bulk_delete "$IDS_CSV")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  duplicate)
    MENU_ITEM_ID="${2:-}"
    FOOD_CATEGORY_ID="${3:-}"
    gg_require "$MENU_ITEM_ID" "Usage: menu_manage.sh duplicate <menuItemId> <foodCategoryId>"
    gg_require "$FOOD_CATEGORY_ID" "Usage: menu_manage.sh duplicate <menuItemId> <foodCategoryId>"
    RESP="$(gg_menu_duplicate "$MENU_ITEM_ID" "$FOOD_CATEGORY_ID")" || exit $?
    echo "$RESP" | jq '.result'
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD (expected combo|bulk-edit|bulk-delete|duplicate)"
    ;;
esac
