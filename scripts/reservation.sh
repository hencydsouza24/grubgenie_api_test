#!/usr/bin/env bash
# Reservation widget embed config (partner-side, X-Api-Key auth) + public (unauthenticated)
# reservation self-service, keyed by a signed `ref` token (NOT a plain Mongo id).
# Usage: bash reservation.sh embed
#        bash reservation.sh public review <ref>
#        bash reservation.sh public get <ref>
#        bash reservation.sh public availability <ref> <date> <partySize>
#        bash reservation.sh public modify <ref> [startAt] [partySize]
#        bash reservation.sh public cancel <ref> [reason]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"
source "$GG_LIB_DIR/api_partner_misc.sh"

CMD="${1:-}"
gg_require "$CMD" "Usage: reservation.sh embed|public <subcommand> [args]"

case "$CMD" in
  embed)
    gg_reservation_widget_embed
    ;;

  public)
    SUB="${2:-}"
    REF="${3:-}"
    gg_require "$SUB" "Usage: reservation.sh public review|get|availability|modify|cancel <ref> [args]"
    gg_require "$REF" "Usage: reservation.sh public $SUB <ref> [args]"
    case "$SUB" in
      review)       gg_reservation_public_review "$REF" ;;
      get)          gg_reservation_public_get "$REF" ;;
      availability) gg_reservation_public_availability "$REF" "${4:-}" "${5:-}" ;;
      modify)       gg_reservation_public_modify "$REF" "${4:-}" "${5:-}" ;;
      cancel)       gg_reservation_public_cancel "$REF" "${4:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Unknown public subcommand: $SUB (expected review|get|availability|modify|cancel)" ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD (expected embed|public)"
    ;;
esac
