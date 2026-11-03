#!/usr/bin/env bash
# Admin-bearer long-tail ops/diagnostic groups: config, cuisine, diner, genie-core sessions,
# kb-topic-catalog, migration, ml, openviking, order, plan, qrcode (extra), waba resolve,
# whatsapp-template. Auths itself (see auth.sh) if no session exists yet or the existing one has
# expired; most subcommands here additionally lazy-mint a cached admin bearer token
# (gg_admin_token).
#
# Usage: bash admin_misc.sh <resource> <action> [args...]
#
# Commands:
#   config get <name>
#   config update <name> <value>      value is sent as a plain string field: {value: "<value>"}
#   config delete <name>
#   cuisine list
#   cuisine get <cuisineId>
#   diner list [page] [limit]
#   diner get <dinerId>
#   genie-core-sessions
#   kb-topic-catalog list
#   kb-topic-catalog create <key> <label> <store> [description]   store: documents|menu|none
#   kb-topic-catalog update <catalogId> [label] [description] [store]   pass "" to skip a field
#   kb-topic-catalog delete <catalogId>
#   migration run-all [--override]
#   ml retrain <accountId>
#   openviking inject-branch-context <accountId> <branchId> <content>
#   openviking upload-skill <accountId> <branchId> <content>
#   order list [page] [limit]
#   order get <orderId>
#   plan slug <slug>
#   qrcode available-partners
#   qrcode available-tables <branchId> <accountId>
#   qrcode details <code>
#   waba resolve-account <wabaId> <callerKeyId>             requires GG_WABA_MIDDLEWARE_API_KEY
#   waba resolve-platform-inbound <phoneNumberId> [waId]    requires GG_WABA_MIDDLEWARE_API_KEY
#   whatsapp-template re-provision <partnerId>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: admin_misc.sh config get|update|delete <name> | cuisine list|get <id> | diner list|get <id> | genie-core-sessions | kb-topic-catalog list|create|update <id>|delete <id> | migration run-all [--override] | ml retrain <accountId> | openviking inject-branch-context|upload-skill | order list|get <id> | plan slug <slug> | qrcode available-partners|available-tables|details <code> | waba resolve-account|resolve-platform-inbound | whatsapp-template re-provision <partnerId>"

RESOURCE="${1:-}"
gg_require "$RESOURCE" "$USAGE"

case "$RESOURCE" in
  config)
    ACTION="${2:-}"
    case "$ACTION" in
      get)    gg_config_get "${3:-}" ;;
      update) gg_config_update "${3:-}" "${4:-}" ;;
      delete) gg_config_delete "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh config get|update|delete <name> [value]" ;;
    esac
    ;;

  cuisine)
    ACTION="${2:-list}"
    case "$ACTION" in
      list) gg_cuisine_list ;;
      get)  gg_cuisine_get "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh cuisine list|get <cuisineId>" ;;
    esac
    ;;

  diner)
    ACTION="${2:-list}"
    case "$ACTION" in
      list) gg_diner_list "${3:-}" "${4:-}" ;;
      get)  gg_diner_get "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh diner list [page] [limit] | get <dinerId>" ;;
    esac
    ;;

  genie-core-sessions)
    gg_genie_core_sessions
    ;;

  kb-topic-catalog)
    ACTION="${2:-list}"
    case "$ACTION" in
      list)   gg_kb_topic_catalog_list ;;
      create) gg_kb_topic_catalog_create "${3:-}" "${4:-}" "${5:-}" "${6:-}" ;;
      update) gg_kb_topic_catalog_update "${3:-}" "${4:-}" "${5:-}" "${6:-}" ;;
      delete) gg_kb_topic_catalog_delete "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh kb-topic-catalog list|create <key> <label> <store> [description]|update <id> [label] [description] [store]|delete <id>" ;;
    esac
    ;;

  migration)
    ACTION="${2:-run-all}"
    case "$ACTION" in
      run-all)
        OVERRIDE=""
        for arg in "${@:3}"; do
          [ "$arg" = "--override" ] && OVERRIDE="true"
        done
        gg_migration_run_all "$OVERRIDE"
        ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh migration run-all [--override]" ;;
    esac
    ;;

  ml)
    ACTION="${2:-retrain}"
    case "$ACTION" in
      retrain) gg_ml_retrain "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh ml retrain <accountId>" ;;
    esac
    ;;

  openviking)
    ACTION="${2:-}"
    case "$ACTION" in
      inject-branch-context) gg_openviking_inject_branch_context "${3:-}" "${4:-}" "${5:-}" ;;
      upload-skill)          gg_openviking_upload_skill "${3:-}" "${4:-}" "${5:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh openviking inject-branch-context|upload-skill <accountId> <branchId> <content>" ;;
    esac
    ;;

  order)
    ACTION="${2:-list}"
    case "$ACTION" in
      list) gg_order_admin_list "${3:-}" "${4:-}" ;;
      get)  gg_order_admin_get "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh order list [page] [limit] | get <orderId>" ;;
    esac
    ;;

  plan)
    ACTION="${2:-}"
    case "$ACTION" in
      slug) gg_plan_get_by_slug "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh plan slug <slug>" ;;
    esac
    ;;

  qrcode)
    ACTION="${2:-}"
    case "$ACTION" in
      available-partners) gg_qrcode_available_partners ;;
      available-tables)   gg_qrcode_available_tables "${3:-}" "${4:-}" ;;
      details)            gg_qrcode_details "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh qrcode available-partners|available-tables <branchId> <accountId>|details <code>" ;;
    esac
    ;;

  waba)
    ACTION="${2:-}"
    case "$ACTION" in
      resolve-account)           gg_waba_resolve_account "${3:-}" "${4:-}" ;;
      resolve-platform-inbound)  gg_waba_resolve_platform_inbound "${3:-}" "${4:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh waba resolve-account <wabaId> <callerKeyId> | resolve-platform-inbound <phoneNumberId> [waId]" ;;
    esac
    ;;

  whatsapp-template)
    ACTION="${2:-re-provision}"
    case "$ACTION" in
      re-provision) gg_whatsapp_template_reprovision "${3:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: admin_misc.sh whatsapp-template re-provision <partnerId>" ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "$USAGE"
    ;;
esac
