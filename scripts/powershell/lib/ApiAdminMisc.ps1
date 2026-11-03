# Admin-bearer domain verbs for the long tail of small admin/ops endpoints: config, cuisine,
# diner, genie-core sessions, kb-topic-catalog, migration, ml, openviking, order, plan,
# qrcode-extra, waba-resolve, whatsapp-template. Expressed over Http.ps1 + Json.ps1 +
# Auth.ps1's Get-GgCachedAdminToken, exactly like Api.ps1. Dot-sourced by Bootstrap.ps1.
# Mirrors scripts/lib/api_admin_misc.sh function-for-function; the name mapping (bash ->
# PowerShell) is kept here, exactly like Api.ps1's own header:
#
#   gg_config_get                          -> Get-GgConfig
#   gg_config_update                       -> Set-GgConfig
#   gg_config_delete                       -> Remove-GgConfig
#   gg_cuisine_list                        -> Get-GgCuisines
#   gg_cuisine_get                         -> Get-GgCuisine
#   gg_diner_list                          -> Get-GgAdminDiners
#   gg_diner_get                           -> Get-GgAdminDiner
#   gg_genie_core_sessions                 -> Get-GgGenieCoreSessions
#   gg_kb_topic_catalog_list               -> Get-GgKbTopicCatalog
#   gg_kb_topic_catalog_create             -> New-GgKbTopicCatalogEntry
#   gg_kb_topic_catalog_update             -> Set-GgKbTopicCatalogEntry
#   gg_kb_topic_catalog_delete             -> Remove-GgKbTopicCatalogEntry
#   gg_migration_run_all                   -> Start-GgMigrationRunAll
#   gg_ml_retrain                          -> Start-GgMlRetrain
#   gg_openviking_inject_branch_context    -> Invoke-GgOpenvikingInjectBranchContext
#   gg_openviking_upload_skill             -> Invoke-GgOpenvikingUploadSkill
#   gg_order_admin_list                    -> Get-GgAdminOrders
#   gg_order_admin_get                     -> Get-GgAdminOrder
#   gg_plan_get_by_slug                    -> Get-GgPlanBySlug
#   gg_qrcode_available_partners           -> Get-GgQrCodeAvailablePartners
#   gg_qrcode_available_tables             -> Get-GgQrCodeAvailableTables
#   gg_qrcode_details                      -> Get-GgQrCodeDetails
#   gg_waba_resolve_account                -> Resolve-GgWabaAccount
#   gg_waba_resolve_platform_inbound       -> Resolve-GgWabaPlatformInbound
#   gg_whatsapp_template_reprovision       -> Invoke-GgWhatsappTemplateReProvision

if (Get-Variable -Name _GgApiAdminMiscLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiAdminMiscLoaded = $true

# --- Config ---
# NOTE: GET /v1/admin/config/:name has NO auth middleware in the real route (only `validate()`)
# — confirmed against src/routes/v1/admin/config.route.ts. Called here with no token.

function Get-GgConfig {
    param([Parameter(Mandatory)][string]$Name)
    $base = Get-GgSessionValue -Key 'base'
    return Invoke-GgHttpOrDie -Label 'config get' -Method GET -Path "$base/v1/admin/config/$Name"
}

# Set-GgConfig <name> <value> — value is sent as a plain string field, i.e. body
# `{value: "<value>"}`. The real schema's `value` is `Joi.any()` (any JSON type), but this
# skill's convention is to build bodies via New-GgJsonObj/ConvertTo-Json, not shell-interpolated
# JSON, so a structured (object/array/number) value isn't supported from the CLI here.
function Set-GgConfig {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ value = $Value }
    return Invoke-GgHttpOrDie -Label 'config update' -Method PUT -Path "$base/v1/admin/config/$Name" -Token $token -JsonBody $body
}

function Remove-GgConfig {
    param([Parameter(Mandatory)][string]$Name)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'config delete' -Method DELETE -Path "$base/v1/admin/config/$Name" -Token $token
}

# --- Cuisine ---
# NOTE: both routes have NO auth middleware in the real route (public) — confirmed against
# src/routes/v1/admin/cuisine.route.ts. Called here with no token.

function Get-GgCuisines {
    $base = Get-GgSessionValue -Key 'base'
    return Invoke-GgHttpOrDie -Label 'cuisine list' -Method GET -Path "$base/v1/admin/cuisine"
}

function Get-GgCuisine {
    param([Parameter(Mandatory)][string]$CuisineId)
    $base = Get-GgSessionValue -Key 'base'
    return Invoke-GgHttpOrDie -Label 'cuisine get' -Method GET -Path "$base/v1/admin/cuisine/$CuisineId"
}

# --- Diner (admin) ---

function Get-GgAdminDiners {
    param([string]$Page, [string]$Limit)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $query = @{}
    if ($Page) { $query['page'] = $Page }
    if ($Limit) { $query['limit'] = $Limit }
    return Invoke-GgHttpOrDie -Label 'diner list' -Method GET -Path "$base/v1/admin/diner" -Token $token -Query $query
}

function Get-GgAdminDiner {
    param([Parameter(Mandatory)][string]$Id)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'diner get' -Method GET -Path "$base/v1/admin/diner/$Id" -Token $token
}

# --- GenieCore sessions ---

function Get-GgGenieCoreSessions {
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'genie-core sessions' -Method GET -Path "$base/v1/admin/genie-core/sessions" -Token $token
}

# --- KbTopicCatalog ---
# NOTE: mounted at /v1/admin/kb-topic-catalog (kebab-case) — confirmed against
# src/routes/v1/admin/index.ts, not /v1/admin/kbTopicCatalog.

function Get-GgKbTopicCatalog {
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'kb-topic-catalog list' -Method GET -Path "$base/v1/admin/kb-topic-catalog" -Token $token
}

# New-GgKbTopicCatalogEntry <key> <label> <store> [description] — store must be one of
# documents|menu|none (KB_TOPIC_STORES).
function New-GgKbTopicCatalogEntry {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][ValidateSet('documents', 'menu', 'none')][string]$Store,
        [string]$Description
    )
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $fields = @{ key = $Key; label = $Label; store = $Store }
    if ($Description) { $fields['description'] = $Description }
    $body = New-GgJsonObj $fields
    return Invoke-GgHttpOrDie -Label 'kb-topic-catalog create' -Method POST -Path "$base/v1/admin/kb-topic-catalog" -Token $token -JsonBody $body
}

# Set-GgKbTopicCatalogEntry <catalogId> [label] [description] [store] — any of label/description/
# store may be omitted to leave that field unchanged.
function Set-GgKbTopicCatalogEntry {
    param(
        [Parameter(Mandatory)][string]$CatalogId,
        [string]$Label,
        [string]$Description,
        [string]$Store
    )
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $fields = @{}
    if ($Label) { $fields['label'] = $Label }
    if ($Description) { $fields['description'] = $Description }
    if ($Store) { $fields['store'] = $Store }
    $body = New-GgJsonObj $fields
    return Invoke-GgHttpOrDie -Label 'kb-topic-catalog update' -Method PUT -Path "$base/v1/admin/kb-topic-catalog/$CatalogId" -Token $token -JsonBody $body
}

function Remove-GgKbTopicCatalogEntry {
    param([Parameter(Mandatory)][string]$CatalogId)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'kb-topic-catalog delete' -Method DELETE -Path "$base/v1/admin/kb-topic-catalog/$CatalogId" -Token $token
}

# --- Migration ---

# Start-GgMigrationRunAll [-Override "true"|"false"]
function Start-GgMigrationRunAll {
    param([string]$Override)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $query = @{}
    if ($Override) { $query['override'] = $Override }
    return Invoke-GgHttpOrDie -Label 'migration run-all-pending' -Method POST -Path "$base/v1/admin/migration/run-all-pending" -Token $token -Query $query
}

# --- ML ---

function Start-GgMlRetrain {
    param([Parameter(Mandatory)][string]$AccountId)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'ml retrain' -Method POST -Path "$base/v1/admin/ml/retrain/$AccountId" -Token $token
}

# --- OpenViking (admin) ---
# body shape confirmed against src/modules/openviking/openviking.validation.ts: both routes take
# {accountId, branchId, content} — plain strings, not ObjectIds.

function Invoke-GgOpenvikingInjectBranchContext {
    param(
        [Parameter(Mandatory)][string]$AccountId,
        [Parameter(Mandatory)][string]$BranchId,
        [Parameter(Mandatory)][string]$Content
    )
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ accountId = $AccountId; branchId = $BranchId; content = $Content }
    return Invoke-GgHttpOrDie -Label 'openviking inject-branch-context' -Method POST -Path "$base/v1/admin/openviking/inject-branch-context" -Token $token -JsonBody $body
}

function Invoke-GgOpenvikingUploadSkill {
    param(
        [Parameter(Mandatory)][string]$AccountId,
        [Parameter(Mandatory)][string]$BranchId,
        [Parameter(Mandatory)][string]$Content
    )
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ accountId = $AccountId; branchId = $BranchId; content = $Content }
    return Invoke-GgHttpOrDie -Label 'openviking upload-skill' -Method POST -Path "$base/v1/admin/openviking/upload-skill" -Token $token -JsonBody $body
}

# --- Order (admin) ---

function Get-GgAdminOrders {
    param([string]$Page, [string]$Limit)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $query = @{}
    if ($Page) { $query['page'] = $Page }
    if ($Limit) { $query['limit'] = $Limit }
    return Invoke-GgHttpOrDie -Label 'order list' -Method GET -Path "$base/v1/admin/order" -Token $token -Query $query
}

function Get-GgAdminOrder {
    param([Parameter(Mandatory)][string]$Id)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'order get' -Method GET -Path "$base/v1/admin/order/$Id" -Token $token
}

# --- Plan ---

function Get-GgPlanBySlug {
    param([Parameter(Mandatory)][string]$Slug)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'plan by slug' -Method GET -Path "$base/v1/admin/plan/slug/$Slug" -Token $token
}

# --- QrCode (admin, extra) ---
# Base is /v1/admin/qr-code (confirmed — mounted at '/qr-code' in admin/index.ts).

function Get-GgQrCodeAvailablePartners {
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'qrcode available-partners' -Method GET -Path "$base/v1/admin/qr-code/available-partners" -Token $token
}

function Get-GgQrCodeAvailableTables {
    param([Parameter(Mandatory)][string]$BranchId, [Parameter(Mandatory)][string]$AccountId)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'qrcode available-tables' -Method GET -Path "$base/v1/admin/qr-code/available-tables" -Token $token -Query @{ branchId = $BranchId; accountId = $AccountId }
}

function Get-GgQrCodeDetails {
    param([Parameter(Mandatory)][string]$Code)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'qrcode details' -Method GET -Path "$base/v1/admin/qr-code/details" -Token $token -Query @{ code = $Code }
}

# --- WABA resolve ---
# Auth is authJwtOrApiKey — a Bearer JWT OR an `X-Api-Key` header, NOT "no auth" (confirmed
# against src/modules/apiKey/apiKey.middleware.ts). Used here with the WABA middleware service
# API key over X-Api-Key, per the task spec's intent (a separate credential from the admin
# bearer token) — requires $env:GG_WABA_MIDDLEWARE_API_KEY from credentials.env.

function Resolve-GgWabaAccount {
    param([Parameter(Mandatory)][string]$WabaId, [Parameter(Mandatory)][string]$CallerKeyId)
    Import-GgCredentials
    if (-not $env:GG_WABA_MIDDLEWARE_API_KEY) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_WABA_MIDDLEWARE_API_KEY not set — see scripts/config/credentials.example.env'
    }
    $base = Get-GgSessionValue -Key 'base'
    $body = New-GgJsonObj @{ wabaId = $WabaId; callerKeyId = $CallerKeyId }
    return Invoke-GgHttpOrDie -Label 'waba resolve-account' -Method POST -Path "$base/v1/admin/waba/resolve-account" -JsonBody $body -Headers @{ 'X-Api-Key' = $env:GG_WABA_MIDDLEWARE_API_KEY }
}

# Resolve-GgWabaPlatformInbound <phoneNumberId> [-WaId waId]
function Resolve-GgWabaPlatformInbound {
    param([Parameter(Mandatory)][string]$PhoneNumberId, [string]$WaId)
    Import-GgCredentials
    if (-not $env:GG_WABA_MIDDLEWARE_API_KEY) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_WABA_MIDDLEWARE_API_KEY not set — see scripts/config/credentials.example.env'
    }
    $base = Get-GgSessionValue -Key 'base'
    $fields = @{ phoneNumberId = $PhoneNumberId }
    if ($WaId) { $fields['waId'] = $WaId }
    $body = New-GgJsonObj $fields
    return Invoke-GgHttpOrDie -Label 'waba resolve-platform-inbound' -Method POST -Path "$base/v1/admin/waba/resolve-platform-inbound" -JsonBody $body -Headers @{ 'X-Api-Key' = $env:GG_WABA_MIDDLEWARE_API_KEY }
}

# --- WhatsAppTemplate ---
# Base is /v1/admin/whatsapp/templates (confirmed — mounted at '/whatsapp/templates' in
# admin/index.ts), NOT /v1/admin/whatsapp-template.

function Invoke-GgWhatsappTemplateReProvision {
    param([Parameter(Mandatory)][string]$PartnerId)
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ partnerId = $PartnerId }
    return Invoke-GgHttpOrDie -Label 'whatsapp-template re-provision' -Method POST -Path "$base/v1/admin/whatsapp/templates/re-provision" -Token $token -JsonBody $body
}
