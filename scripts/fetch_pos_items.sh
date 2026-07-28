#!/usr/bin/env bash
# Back-compat shim — see pos.sh. Usage: bash fetch_pos_items.sh [provider]
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pos.sh" items "$@"
