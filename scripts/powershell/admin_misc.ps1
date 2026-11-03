# Admin-bearer long-tail ops/diagnostic groups: config, cuisine, diner, genie-core sessions,
# kb-topic-catalog, migration, ml, openviking, order, plan, qrcode (extra), waba resolve,
# whatsapp-template. Auths itself (see Auth.ps1) if no session exists yet or the existing one
# has expired; most subcommands here additionally lazy-mint a cached admin bearer token
# (Get-GgCachedAdminToken).
#
# Usage: pwsh ./admin_misc.ps1 <resource> <action> [args...]
#
# Commands: mirrors admin_misc.sh — see that file's header for the full list.
param(
    [Parameter(Position = 0)][string]$Resource,
    [Parameter(Position = 1)][string]$Action,
    [Parameter(Position = 2)][string]$Arg1,
    [Parameter(Position = 3)][string]$Arg2,
    [Parameter(Position = 4)][string]$Arg3,
    [Parameter(Position = 5)][string]$Arg4,
    [switch]$Override
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = "Usage: admin_misc.ps1 config get|update|delete <name> | cuisine list|get <id> | diner list|get <id> | genie-core-sessions | kb-topic-catalog list|create|update <id>|delete <id> | migration run-all [-Override] | ml retrain <accountId> | openviking inject-branch-context|upload-skill | order list|get <id> | plan slug <slug> | qrcode available-partners|available-tables|details <code> | waba resolve-account|resolve-platform-inbound | whatsapp-template re-provision <partnerId>"

if (-not $Resource) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Resource) {
    'config' {
        switch ($Action) {
            'get'    { Get-GgConfig -Name $Arg1 }
            'update' { Set-GgConfig -Name $Arg1 -Value $Arg2 }
            'delete' { Remove-GgConfig -Name $Arg1 }
            default  { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 config get|update|delete <name> [value]' }
        }
    }
    'cuisine' {
        switch ($Action) {
            'list'  { Get-GgCuisines }
            'get'   { Get-GgCuisine -CuisineId $Arg1 }
            ''      { Get-GgCuisines }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 cuisine list|get <cuisineId>' }
        }
    }
    'diner' {
        switch ($Action) {
            'list'  { Get-GgAdminDiners -Page $Arg1 -Limit $Arg2 }
            'get'   { Get-GgAdminDiner -Id $Arg1 }
            ''      { Get-GgAdminDiners }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 diner list [page] [limit] | get <dinerId>' }
        }
    }
    'genie-core-sessions' {
        Get-GgGenieCoreSessions
    }
    'kb-topic-catalog' {
        switch ($Action) {
            'list'   { Get-GgKbTopicCatalog }
            'create' { New-GgKbTopicCatalogEntry -Key $Arg1 -Label $Arg2 -Store $Arg3 -Description $Arg4 }
            'update' { Set-GgKbTopicCatalogEntry -CatalogId $Arg1 -Label $Arg2 -Description $Arg3 -Store $Arg4 }
            'delete' { Remove-GgKbTopicCatalogEntry -CatalogId $Arg1 }
            ''       { Get-GgKbTopicCatalog }
            default  { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 kb-topic-catalog list|create <key> <label> <store> [description]|update <id> [label] [description] [store]|delete <id>' }
        }
    }
    'migration' {
        # No ternary operator here — PS 5.1 (no `?:`) is a supported target, same as Http.ps1's
        # PSVersionTable branch for Invoke-WebRequest.
        $overrideValue = $null
        if ($Override.IsPresent) { $overrideValue = 'true' }
        switch ($Action) {
            'run-all' { Start-GgMigrationRunAll -Override $overrideValue }
            ''        { Start-GgMigrationRunAll -Override $overrideValue }
            default   { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 migration run-all [-Override]' }
        }
    }
    'ml' {
        switch ($Action) {
            'retrain' { Start-GgMlRetrain -AccountId $Arg1 }
            default   { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 ml retrain <accountId>' }
        }
    }
    'openviking' {
        switch ($Action) {
            'inject-branch-context' { Invoke-GgOpenvikingInjectBranchContext -AccountId $Arg1 -BranchId $Arg2 -Content $Arg3 }
            'upload-skill'          { Invoke-GgOpenvikingUploadSkill -AccountId $Arg1 -BranchId $Arg2 -Content $Arg3 }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 openviking inject-branch-context|upload-skill <accountId> <branchId> <content>' }
        }
    }
    'order' {
        switch ($Action) {
            'list'  { Get-GgAdminOrders -Page $Arg1 -Limit $Arg2 }
            'get'   { Get-GgAdminOrder -Id $Arg1 }
            ''      { Get-GgAdminOrders }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 order list [page] [limit] | get <orderId>' }
        }
    }
    'plan' {
        switch ($Action) {
            'slug'  { Get-GgPlanBySlug -Slug $Arg1 }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 plan slug <slug>' }
        }
    }
    'qrcode' {
        switch ($Action) {
            'available-partners' { Get-GgQrCodeAvailablePartners }
            'available-tables'   { Get-GgQrCodeAvailableTables -BranchId $Arg1 -AccountId $Arg2 }
            'details'            { Get-GgQrCodeDetails -Code $Arg1 }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 qrcode available-partners|available-tables <branchId> <accountId>|details <code>' }
        }
    }
    'waba' {
        switch ($Action) {
            'resolve-account'          { Resolve-GgWabaAccount -WabaId $Arg1 -CallerKeyId $Arg2 }
            'resolve-platform-inbound' { Resolve-GgWabaPlatformInbound -PhoneNumberId $Arg1 -WaId $Arg2 }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 waba resolve-account <wabaId> <callerKeyId> | resolve-platform-inbound <phoneNumberId> [waId]' }
        }
    }
    'whatsapp-template' {
        switch ($Action) {
            're-provision' { Invoke-GgWhatsappTemplateReProvision -PartnerId $Arg1 }
            ''             { Invoke-GgWhatsappTemplateReProvision -PartnerId $Arg1 }
            default        { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_misc.ps1 whatsapp-template re-provision <partnerId>' }
        }
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage
    }
}
