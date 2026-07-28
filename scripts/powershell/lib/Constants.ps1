# Pure fixture data — no I/O, no network, no side effects. Dot-sourced by Bootstrap.ps1.
# Mirrors scripts/lib/constants.sh field-for-field; keep the two in sync.

if (Get-Variable -Name _GgConstantsLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgConstantsLoaded = $true

# Environments
$Script:GgEnvLocal = 'http://localhost:3000'
$Script:GgEnvDev   = 'https://dev-backend.grubgenie.ai'
$Script:GgEnvProd  = 'https://backend.grubgenie.ai'

# Test tenant (munch2).
$Script:GgCustomDomain = 'munch2'
$Script:GgFingerprint  = 'grubgenie-stripe-test-002'

# GgBranchId is NOT used for diner auth — Auth.ps1 decodes the real branchId from the partner
# token's own JWT claim instead. A partner account can have multiple branches (confirmed live:
# the test account has 9: 3XSJT, D13GZ, and 7 others) and its "currently selected" branch changes
# via /v1/partner/branch/switch-branch — a hardcoded literal here would go stale the moment
# someone switches. Kept only as an example value for docs/reference.
$Script:GgBranchId     = '3XSJT'

# Partner test credentials — a throwaway mailbox against a shared test tenant. Safe to keep
# tracked; this is what makes the zero-config happy path possible.
$Script:GgPartnerEmail    = 'munchuser@yopmail.com'
$Script:GgPartnerPassword = 'Test@123'

# Petpooja public identifiers — not secret. The secret pair (appSecret/accessToken) lives in
# scripts/config/credentials.env (gitignored); see credentials.example.env.
$Script:GgPosProvider = 'petpooja'
$Script:GgPosAppKey   = 'xz8swugh0vp9oymdab2tkne1qr5c3i67'
$Script:GgPosRestId   = 'i4fwyk7e'

# Known-good sample IDs (munch2 test data)
$Script:GgItemUlliVada = '691bf10018f1d3c34db1db00' # Ulli Vada, 12 AED
$Script:GgComboSnack   = '69f8757fd475a8cf66ed94f2' # Snack Combo, 24 AED
$Script:GgDinerTest    = '69f89034e0a784fea33a0d12'

# Exit codes — numerically identical to the bash twins in ../../lib/constants.sh.
$Script:GgExitOk        = 0
$Script:GgExitUsage     = 2
$Script:GgExitClient    = 4
$Script:GgExitServer    = 5
$Script:GgExitContract  = 6
$Script:GgExitTransport = 7

# Tunables — override via env var before dot-sourcing.
$Script:GgConnectTimeout = if ($env:GG_CONNECT_TIMEOUT) { [int]$env:GG_CONNECT_TIMEOUT } else { 5 }
$Script:GgMaxTime        = if ($env:GG_MAX_TIME)        { [int]$env:GG_MAX_TIME }        else { 30 }
$Script:GgSessionTtl     = if ($env:GG_SESSION_TTL)      { [int]$env:GG_SESSION_TTL }     else { 900 }
