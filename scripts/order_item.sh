#!/usr/bin/env bash
# Back-compat shim — see order.sh. Usage: bash order_item.sh <itemId> [quantity]
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/order.sh" item "$@"
