#!/usr/bin/env bash
# Back-compat shim — see pos.sh. Usage: bash branch_pos_config.sh setup|disable|get
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pos.sh" config "$@"
