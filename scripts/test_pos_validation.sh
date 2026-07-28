#!/usr/bin/env bash
# Back-compat shim — see pos.sh. Usage: bash test_pos_validation.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pos.sh" validate "$@"
