#!/usr/bin/env bash
# GrubGenie API test skill — shared library bootstrap.
# Every script sources ONLY this file:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"
# It sets strict mode once and pulls in the rest of lib/ in dependency order.

if [ "${_GG_LOADED:-}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi
_GG_LOADED=1

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "lib/bootstrap.sh is a library — source it, don't execute it." >&2
  exit 1
fi

set -euo pipefail

GG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GG_SKILL_DIR="$(cd "$GG_LIB_DIR/.." && pwd)"

# shellcheck source=scripts/lib/constants.sh
source "$GG_LIB_DIR/constants.sh"
# shellcheck source=scripts/lib/log.sh
source "$GG_LIB_DIR/log.sh"
# shellcheck source=scripts/lib/env.sh
source "$GG_LIB_DIR/env.sh"
# shellcheck source=scripts/lib/json.sh
source "$GG_LIB_DIR/json.sh"
# shellcheck source=scripts/lib/http.sh
source "$GG_LIB_DIR/http.sh"
# shellcheck source=scripts/lib/auth.sh
source "$GG_LIB_DIR/auth.sh"
# shellcheck source=scripts/lib/api.sh
source "$GG_LIB_DIR/api.sh"
# shellcheck source=scripts/lib/api_admin.sh
source "$GG_LIB_DIR/api_admin.sh"
# shellcheck source=scripts/lib/api_admin_misc.sh
source "$GG_LIB_DIR/api_admin_misc.sh"
# shellcheck source=scripts/lib/api_misc.sh
source "$GG_LIB_DIR/api_misc.sh"
# shellcheck source=scripts/lib/api_partner_voice.sh
source "$GG_LIB_DIR/api_partner_voice.sh"
# shellcheck source=scripts/lib/api_partner_ops.sh
source "$GG_LIB_DIR/api_partner_ops.sh"
# shellcheck source=scripts/lib/api_partner_crm.sh
source "$GG_LIB_DIR/api_partner_crm.sh"
# shellcheck source=scripts/lib/api_partner_catalog.sh
source "$GG_LIB_DIR/api_partner_catalog.sh"
# shellcheck source=scripts/lib/api_partner_misc.sh
source "$GG_LIB_DIR/api_partner_misc.sh"
