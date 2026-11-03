# Partner catalog management — Combo CRUD, Menu bulk edit/delete/duplicate. Partner bearer auth.
#
# Usage: pwsh ./menu_manage.ps1 combo create <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [dPrice]
#        pwsh ./menu_manage.ps1 combo get <comboId>
#        pwsh ./menu_manage.ps1 combo update <comboId> [comboName] [isActive]
#        pwsh ./menu_manage.ps1 combo delete <comboId>
#        pwsh ./menu_manage.ps1 bulk-edit <idsCsv> <changesJson> [customizationMode]
#        pwsh ./menu_manage.ps1 bulk-delete <idsCsv>
#        pwsh ./menu_manage.ps1 duplicate <menuItemId> <foodCategoryId>
#
# idsCsv is a comma-separated list of menuItemIds, e.g. "id1,id2,id3". changesJson is a raw JSON
# object matching bulkEditChangesSchema, e.g. '{"chefsChoice":true}'. isActive is the literal
# string "true" or "false".
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('combo', 'bulk-edit', 'bulk-delete', 'duplicate')][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(Position = 3)][string]$Arg3,
    [Parameter(Position = 4)][string]$Arg4,
    [Parameter(Position = 5)][string]$Arg5,
    [Parameter(Position = 6)][string]$Arg6,
    [Parameter(Position = 7)][string]$Arg7
)
. "$PSScriptRoot/lib/Bootstrap.ps1"
# ApiPartnerCatalog.ps1 isn't wired into Bootstrap.ps1 yet — dot-sourced directly here until it is.

switch ($Command) {
    'combo' {
        $sub = $Arg1
        switch ($sub) {
            'create' {
                if (-not $Arg2 -or -not $Arg3 -or -not $Arg4 -or -not $Arg5 -or -not $Arg6) {
                    Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 combo create <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [dPrice]'
                }
                $dPriceParams = @{}
                if ($Arg7) { $dPriceParams['DPrice'] = [double]$Arg7 }
                $resp = New-GgCombo -ComboName $Arg2 -FoodCategoryId $Arg3 -FoodTypeId $Arg4 -MenuItemId $Arg5 -Quantity ([int]$Arg6) @dPriceParams
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'get' {
                if (-not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 combo get <comboId>' }
                $resp = Get-GgCombo -ComboId $Arg2
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'update' {
                if (-not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 combo update <comboId> [comboName] [isActive]' }
                $resp = Update-GgCombo -ComboId $Arg2 -ComboName $Arg3 -IsActive $Arg4
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'delete' {
                if (-not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 combo delete <comboId>' }
                Remove-GgCombo -ComboId $Arg2 | Out-Null
                Write-GgInfo "Combo $Arg2 deleted"
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown combo subcommand: $sub (expected create|get|update|delete)" }
        }
    }
    'bulk-edit' {
        if (-not $Arg1 -or -not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 bulk-edit <idsCsv> <changesJson> [customizationMode]' }
        $resp = Update-GgMenuItemsBulk -IdsCsv $Arg1 -ChangesJson $Arg2 -CustomizationMode $Arg3
        ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
    }
    'bulk-delete' {
        if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 bulk-delete <idsCsv>' }
        $resp = Remove-GgMenuItemsBulk -IdsCsv $Arg1
        ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
    }
    'duplicate' {
        if (-not $Arg1 -or -not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: menu_manage.ps1 duplicate <menuItemId> <foodCategoryId>' }
        $resp = Copy-GgMenuItem -MenuItemId $Arg1 -FoodCategoryId $Arg2
        ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
    }
}
