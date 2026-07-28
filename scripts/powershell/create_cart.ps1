# Usage: $cartId = & "$SKILL/create_cart.ps1"
# Creates a cart against the active session's table. Auths itself (see auth.ps1) if no session
# exists yet or the existing one has expired.
. "$PSScriptRoot/lib/Bootstrap.ps1"

New-GgCart
