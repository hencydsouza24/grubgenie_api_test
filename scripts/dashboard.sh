#!/usr/bin/env bash
# Admin dashboard — summary tiles, timeseries charts, top-N leaderboards.
# Usage: bash dashboard.sh summary
#        bash dashboard.sh timeseries <metric> <interval> [from] [to]
#        bash dashboard.sh top <metric> [limit]
# timeseries metric: orders|signups|partners|revenue   interval: day|week
# top metric: partners-by-orders|diners-by-orders|dishes|cuisines|partners-by-revenue
# from/to are ISO dates. Requires admin credentials (see scripts/config/credentials.example.env)
# — gg_admin_token lazily logs in and caches the token.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: dashboard.sh summary|timeseries|top [args]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

case "$CMD" in
  summary)
    RESP="$(gg_dashboard_summary)" || exit $?
    ;;

  timeseries)
    METRIC="${2:-}" INTERVAL="${3:-}" FROM="${4:-}" TO="${5:-}"
    gg_require "$METRIC" "Usage: dashboard.sh timeseries <metric> <interval> [from] [to]"
    gg_require "$INTERVAL" "Usage: dashboard.sh timeseries <metric> <interval> [from] [to]"
    RESP="$(gg_dashboard_timeseries "$METRIC" "$INTERVAL" "$FROM" "$TO")" || exit $?
    ;;

  top)
    METRIC="${2:-}" LIMIT="${3:-}"
    gg_require "$METRIC" "Usage: dashboard.sh top <metric> [limit]"
    RESP="$(gg_dashboard_top "$METRIC" "$LIMIT")" || exit $?
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD. $USAGE"
    ;;
esac

echo "$RESP" | jq .
