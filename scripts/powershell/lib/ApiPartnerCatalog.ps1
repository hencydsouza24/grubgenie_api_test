# Partner catalog management domain verbs — Combo CRUD, Menu bulk edit/delete/duplicate, partner
# Settlement reads. Mirrors scripts/lib/api_partner_catalog.sh function-for-function. Intended to
# be dot-sourced by Bootstrap.ps1 once wired in centrally; until then, menu_manage.ps1 /
# partner_settlement.ps1 dot-source it directly, right after lib/Bootstrap.ps1.
#
#   gg_combo_create       -> New-GgCombo
#   gg_combo_get          -> Get-GgCombo
#   gg_combo_update       -> Update-GgCombo
#   gg_combo_delete       -> Remove-GgCombo
#   gg_menu_bulk_edit     -> Update-GgMenuItemsBulk
#   gg_menu_bulk_delete   -> Remove-GgMenuItemsBulk
#   gg_menu_duplicate     -> Copy-GgMenuItem
#   gg_settlement_list    -> Get-GgSettlements
#   gg_settlement_summary -> Get-GgPartnerSettlementSummary

if (Get-Variable -Name _GgApiPartnerCatalogLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiPartnerCatalogLoaded = $true

# --- Combo CRUD (/v1/partner/combo) ---
#
# createCombo's body REQUIRES foodCategoryId and foodTypeId (comboValidation.createCombo) —
# api_reference.md's older "Combo Fetching" doc example omits both, which would 400 live against
# the current validation. New-GgCombo below matches the real schema.

# New-GgCombo <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [-DPrice] —
# single-item combo (the common smoke-test shape). For a multi-item combo, build the body
# yourself per the raw curl example in api_reference.md.
function New-GgCombo {
    param(
        [Parameter(Mandatory)][string]$ComboName,
        [Parameter(Mandatory)][string]$FoodCategoryId,
        [Parameter(Mandatory)][string]$FoodTypeId,
        [Parameter(Mandatory)][string]$MenuItemId,
        [Parameter(Mandatory)][int]$Quantity,
        [double]$DPrice
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $fields = @{
        comboName      = $ComboName
        foodCategoryId = $FoodCategoryId
        foodTypeId     = $FoodTypeId
        items          = @(@{ menuItemId = $MenuItemId; quantity = $Quantity })
    }
    if ($PSBoundParameters.ContainsKey('DPrice')) { $fields['dPrice'] = $DPrice }
    $body = $fields | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'combo create' -Method POST -Path "$base/v1/partner/combo" -Token $partnerToken -JsonBody $body
}

function Get-GgCombo {
    param([Parameter(Mandatory)][string]$ComboId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'combo get' -Method GET -Path "$base/v1/partner/combo/$ComboId" -Token $partnerToken
}

# Update-GgCombo <comboId> [-ComboName] [-IsActive] — IsActive is the literal string "true" or
# "false". Matches api_reference.md's documented `{"isActive":false}` update example, plus
# ComboName for renaming.
function Update-GgCombo {
    param(
        [Parameter(Mandatory)][string]$ComboId,
        [string]$ComboName,
        [string]$IsActive
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $fields = @{}
    if ($ComboName) { $fields['comboName'] = $ComboName }
    if ($IsActive) { $fields['isActive'] = ($IsActive -eq 'true') }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'combo update' -Method PATCH -Path "$base/v1/partner/combo/$ComboId" -Token $partnerToken -JsonBody $body
}

function Remove-GgCombo {
    param([Parameter(Mandatory)][string]$ComboId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'combo delete' -Method DELETE -Path "$base/v1/partner/combo/$ComboId" -Token $partnerToken
}

# --- Menu bulk/duplicate (/v1/partner/menu) ---

# Update-GgMenuItemsBulk <idsCsv> <changesJson> [-CustomizationMode] — idsCsv is comma-separated
# menuItemIds (e.g. "id1,id2"). changesJson is a raw JSON object matching
# menuItemValidation.bulkEditMenuItems' `changes` shape (e.g. '{"chefsChoice":true}') — its
# fields are too numerous/nested to flatten into parameters, so it is passed through as-is.
function Update-GgMenuItemsBulk {
    param(
        [Parameter(Mandatory)][string]$IdsCsv,
        [Parameter(Mandatory)][string]$ChangesJson,
        [string]$CustomizationMode
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $ids = $IdsCsv -split ','
    $changes = $ChangesJson | ConvertFrom-Json
    $fields = @{ ids = $ids; changes = $changes }
    if ($CustomizationMode) { $fields['customizationMode'] = $CustomizationMode }
    $body = $fields | ConvertTo-Json -Compress -Depth 10
    return Invoke-GgHttpOrDie -Label 'menu bulk edit' -Method PUT -Path "$base/v1/partner/menu/bulk" -Token $partnerToken -JsonBody $body
}

# Remove-GgMenuItemsBulk <idsCsv> — idsCsv is comma-separated menuItemIds.
function Remove-GgMenuItemsBulk {
    param([Parameter(Mandatory)][string]$IdsCsv)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $ids = $IdsCsv -split ','
    $body = @{ ids = $ids } | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'menu bulk delete' -Method DELETE -Path "$base/v1/partner/menu/bulk" -Token $partnerToken -JsonBody $body
}

function Copy-GgMenuItem {
    param(
        [Parameter(Mandatory)][string]$MenuItemId,
        [Parameter(Mandatory)][string]$FoodCategoryId
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $body = @{ foodCategoryId = $FoodCategoryId } | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'menu duplicate' -Method POST -Path "$base/v1/partner/menu/$MenuItemId/duplicate" -Token $partnerToken -JsonBody $body
}

# --- Partner Settlement (/v1/partner/settlement, read-only) ---

# Get-GgSettlements [-Filters @{branchId='...'; status='pending'}] — any listPartnerSettlements
# query filters, passed through verbatim. branchId is auto-scoped server-side for non-admin
# partner users, so it's rarely needed here.
function Get-GgSettlements {
    param([hashtable]$Filters = @{})
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'settlement list' -Method GET -Path "$base/v1/partner/settlement" -Token $partnerToken -Query $Filters
}

function Get-GgPartnerSettlementSummary {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'settlement summary' -Method GET -Path "$base/v1/partner/settlement/summary" -Token $partnerToken
}
