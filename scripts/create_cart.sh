#!/usr/bin/env bash
# Usage: CART_ID=$(bash create_cart.sh)
# Creates a cart against the active session's table. Auths itself (see auth.sh) if no session
# exists yet or the existing one has expired.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

gg_cart_create
