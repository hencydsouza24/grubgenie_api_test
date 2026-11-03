# Diner-facing genie API extensions: combo fetching, order detail, profile identity linking.
# Usage: pwsh ./diner_ext.ps1 combo list
#        pwsh ./diner_ext.ps1 combo get <comboId>
#        pwsh ./diner_ext.ps1 order-detail <orderId>
#        pwsh ./diner_ext.ps1 link-identity <field> <value> <code>
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('combo', 'order-detail', 'link-identity')][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(Position = 3)][string]$Arg3
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

switch ($Command) {
    'combo' {
        if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: diner_ext.ps1 combo list|get <id>' }
        switch ($Arg1) {
            'list' { Get-GgComboList }
            'get' {
                if (-not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: diner_ext.ps1 combo get <comboId>' }
                Get-GgDinerCombo -ComboId $Arg2
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: diner_ext.ps1 combo list|get <id>' }
        }
    }
    'order-detail' {
        if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: diner_ext.ps1 order-detail <orderId>' }
        Get-GgDinerOrderDetail -OrderId $Arg1
    }
    'link-identity' {
        if (-not $Arg1 -or -not $Arg2 -or -not $Arg3) {
            Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: diner_ext.ps1 link-identity <field> <value> <code>'
        }
        Confirm-GgLinkIdentity -Field $Arg1 -Value $Arg2 -Code $Arg3
    }
}
