#!/usr/bin/env bash
# Environment name -> BASE URL resolution. Sourced by bootstrap.sh.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/env.sh is a library — source it, don't execute it." >&2; exit 1; }

# gg_env_name → the environment name in effect ($GG_ENV, default "local").
gg_env_name() {
  echo "${GG_ENV:-local}"
}

# gg_resolve_base [env_name] → BASE url.
# Precedence: explicit $BASE env var (when no explicit env_name arg given) > mapped default.
gg_resolve_base() {
  local name="${1:-}"

  if [ -z "$name" ]; then
    if [ -n "${BASE:-}" ]; then
      echo "$BASE"
      return 0
    fi
    name="$(gg_env_name)"
  fi

  case "$name" in
    local) echo "$GG_ENV_LOCAL" ;;
    dev)   echo "$GG_ENV_DEV" ;;
    prod)  echo "$GG_ENV_PROD" ;;
    *)
      gg_die "$GG_EXIT_USAGE" "Unknown environment: $name (expected local|dev|prod)"
      ;;
  esac
}
