#!/usr/bin/env bash
# Reset all tables to "available", force-clearing any active carts.
# Usage: bash reset_tables.sh
# Auths itself (see auth.sh) if no session exists yet or the existing one has expired.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

RESP="$(gg_tables_list)" || exit $?

for TID in $(echo "$RESP" | jq -r '.result[]._id'); do
  MSG="$(gg_table_set_status "$TID" available)" || exit $?
  gg_kv "$TID" "$MSG"
done

gg_info "All tables reset to available"
