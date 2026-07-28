#!/usr/bin/env bash
# Back-compat shim — see pos.sh. Usage: bash get_pos_menu.sh [provider]
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pos.sh" menu "$@"
