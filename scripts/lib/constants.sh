#!/usr/bin/env bash
# Pure fixture data — no I/O, no network, no side effects. Sourced by bootstrap.sh.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/constants.sh is a library — source it, don't execute it." >&2; exit 1; }

# Environments
readonly GG_ENV_LOCAL="http://localhost:3000"
readonly GG_ENV_DEV="https://dev-backend.grubgenie.ai"
readonly GG_ENV_PROD="https://backend.grubgenie.ai"

# Test tenant (munch2).
readonly GG_CUSTOM_DOMAIN="munch2"
readonly GG_FINGERPRINT="grubgenie-stripe-test-002"

# GG_BRANCH_ID is NOT used for diner auth — lib/auth.sh decodes the real branchId from the
# partner token's own JWT claim instead. A partner account can have multiple branches (confirmed
# live: the test account has 9: 3XSJT, D13GZ, and 7 others) and its "currently selected" branch
# changes via /v1/partner/branch/switch-branch — a hardcoded literal here would go stale the
# moment someone switches, exactly as happened between this skill's original D13GZ/3XSJT
# inconsistency and the account's current active branch (neither). Kept only as an example value
# for docs/reference — do not wire it back into an auth call.
readonly GG_BRANCH_ID="3XSJT"

# Partner test credentials — a throwaway mailbox against a shared test tenant. Safe to keep
# tracked; this is what makes the zero-config happy path possible.
readonly GG_PARTNER_EMAIL="munchuser@yopmail.com"
readonly GG_PARTNER_PASSWORD="Test@123"

# Petpooja public identifiers — not secret. The secret pair (appSecret/accessToken) lives in
# scripts/config/credentials.env (gitignored); see credentials.example.env.
readonly GG_POS_PROVIDER="petpooja"
readonly GG_POS_APP_KEY="xz8swugh0vp9oymdab2tkne1qr5c3i67"
readonly GG_POS_REST_ID="i4fwyk7e"

# Known-good sample IDs (munch2 test data)
readonly GG_ITEM_ULLI_VADA="691bf10018f1d3c34db1db00" # Ulli Vada, 12 AED
readonly GG_COMBO_SNACK="69f8757fd475a8cf66ed94f2"     # Snack Combo, 24 AED
readonly GG_DINER_TEST="69f89034e0a784fea33a0d12"

# Exit codes — numerically identical to the PowerShell twins in powershell/lib/Constants.ps1.
readonly GG_EXIT_OK=0
readonly GG_EXIT_USAGE=2
readonly GG_EXIT_CLIENT=4
readonly GG_EXIT_SERVER=5
readonly GG_EXIT_CONTRACT=6
readonly GG_EXIT_TRANSPORT=7

# Tunables — override via env var before sourcing.
readonly GG_CONNECT_TIMEOUT="${GG_CONNECT_TIMEOUT:-5}"
readonly GG_MAX_TIME="${GG_MAX_TIME:-30}"
readonly GG_SESSION_TTL="${GG_SESSION_TTL:-900}"
