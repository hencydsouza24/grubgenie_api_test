#!/usr/bin/env bash
# Back-compat shim — see order.sh. Usage: bash order_combo.sh [comboId] [quantity]
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/order.sh" combo "$@"
