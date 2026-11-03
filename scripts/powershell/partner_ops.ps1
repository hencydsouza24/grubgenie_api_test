# Partner Ops — bundles three domains: AllOutlets (cross-branch rollup reads), Queue (walk-in
# queue CRUD + transitions), Role (custom partner roles, mounted at /v1/partner/roles — plural).
# Usage:
#   AllOutlets:
#     pwsh ./partner_ops.ps1 outlets
#     pwsh ./partner_ops.ps1 inquiries [key=value ...]
#     pwsh ./partner_ops.ps1 reservations [key=value ...]     # must include after=... before=...
#     pwsh ./partner_ops.ps1 queue-list [key=value ...]
#     pwsh ./partner_ops.ps1 notifications
#     pwsh ./partner_ops.ps1 notifications-read <branchId> <notificationId> [notificationId...]
#   Queue:
#     pwsh ./partner_ops.ps1 queue create <guestName> <guestPhone> <partySize> [quotedWaitMin] [preferenceNote]
#     pwsh ./partner_ops.ps1 queue list [key=value ...]
#     pwsh ./partner_ops.ps1 queue get <queueId>
#     pwsh ./partner_ops.ps1 queue update <queueId> [guestName] [guestPhone] [partySize] [quotedWaitMin] [preferenceNote]
#     pwsh ./partner_ops.ps1 queue delete <queueId>
#     pwsh ./partner_ops.ps1 queue notify <queueId>
#     pwsh ./partner_ops.ps1 queue table-ready <queueId> [tableId]
#     pwsh ./partner_ops.ps1 queue seat <queueId> [tableId]
#     pwsh ./partner_ops.ps1 queue abandon <queueId> [staff|converted]
#     pwsh ./partner_ops.ps1 queue reopen <queueId>
#   Role:
#     pwsh ./partner_ops.ps1 role permission-catalog [roleKey]
#     pwsh ./partner_ops.ps1 role list
#     pwsh ./partner_ops.ps1 role create <name> <permission> [permission...]
#     pwsh ./partner_ops.ps1 role update <roleId> <name-or-dash> [permission...]
#     pwsh ./partner_ops.ps1 role delete <roleId>
#
# `queue update`/`role update` use "-" as a skip sentinel for an omitted positional field — pass
# "-" to leave that field unchanged.
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('outlets', 'inquiries', 'reservations', 'queue-list', 'notifications', 'notifications-read', 'queue', 'role')]
    [string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

if (-not $Rest) { $Rest = @() }

function ConvertTo-GgQueryHashtable {
    param([string[]]$Pairs)
    $q = @{}
    foreach ($kv in $Pairs) {
        $parts = $kv -split '=', 2
        if ($parts.Count -eq 2) { $q[$parts[0]] = $parts[1] }
    }
    return $q
}

function Format-GgJson { param($Raw) $Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10 }

switch ($Command) {
    'outlets' { Format-GgJson (Get-GgAllOutlets) }
    'inquiries' { Format-GgJson (Get-GgAllOutletsInquiries -Query (ConvertTo-GgQueryHashtable -Pairs $Rest)) }
    'reservations' { Format-GgJson (Get-GgAllOutletsReservations -Query (ConvertTo-GgQueryHashtable -Pairs $Rest)) }
    'queue-list' { Format-GgJson (Get-GgAllOutletsQueue -Query (ConvertTo-GgQueryHashtable -Pairs $Rest)) }
    'notifications' { Format-GgJson (Get-GgAllOutletsNotifications) }
    'notifications-read' {
        if ($Rest.Count -lt 2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 notifications-read <branchId> <notificationId> [notificationId...]' }
        Set-GgAllOutletsNotificationsRead -BranchId $Rest[0] -NotificationIds $Rest[1..($Rest.Count - 1)]
    }

    'queue' {
        $sub = $Rest[0]
        $subArgs = if ($Rest.Count -gt 1) { $Rest[1..($Rest.Count - 1)] } else { @() }
        switch ($sub) {
            'create' {
                if ($subArgs.Count -lt 3) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue create <guestName> <guestPhone> <partySize> [quotedWaitMin] [preferenceNote]' }
                $params = @{ GuestName = $subArgs[0]; GuestPhone = $subArgs[1]; PartySize = [int]$subArgs[2] }
                if ($subArgs.Count -ge 4 -and $subArgs[3]) { $params['QuotedWaitMin'] = [int]$subArgs[3] }
                if ($subArgs.Count -ge 5 -and $subArgs[4]) { $params['PreferenceNote'] = $subArgs[4] }
                New-GgQueueEntry @params
            }
            'list' { Format-GgJson (Get-GgQueueEntries -Query (ConvertTo-GgQueryHashtable -Pairs $subArgs)) }
            'get' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue get <queueId>' }
                Format-GgJson (Get-GgQueueEntry -QueueId $subArgs[0])
            }
            'update' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue update <queueId> [guestName] [guestPhone] [partySize] [quotedWaitMin] [preferenceNote]' }
                $params = @{ QueueId = $subArgs[0] }
                if ($subArgs.Count -ge 2 -and $subArgs[1] -and $subArgs[1] -ne '-') { $params['GuestName'] = $subArgs[1] }
                if ($subArgs.Count -ge 3 -and $subArgs[2] -and $subArgs[2] -ne '-') { $params['GuestPhone'] = $subArgs[2] }
                if ($subArgs.Count -ge 4 -and $subArgs[3] -and $subArgs[3] -ne '-') { $params['PartySize'] = [int]$subArgs[3] }
                if ($subArgs.Count -ge 5 -and $subArgs[4] -and $subArgs[4] -ne '-') { $params['QuotedWaitMin'] = [int]$subArgs[4] }
                if ($subArgs.Count -ge 6 -and $subArgs[5] -and $subArgs[5] -ne '-') { $params['PreferenceNote'] = $subArgs[5] }
                Format-GgJson (Set-GgQueueEntry @params)
            }
            'delete' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue delete <queueId>' }
                Remove-GgQueueEntry -QueueId $subArgs[0]
            }
            'notify' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue notify <queueId>' }
                Invoke-GgQueueNotify -QueueId $subArgs[0]
            }
            'table-ready' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue table-ready <queueId> [tableId]' }
                $params = @{ QueueId = $subArgs[0] }
                if ($subArgs.Count -ge 2 -and $subArgs[1]) { $params['TableId'] = $subArgs[1] }
                Format-GgJson (Invoke-GgQueueTableReady @params)
            }
            'seat' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue seat <queueId> [tableId]' }
                $params = @{ QueueId = $subArgs[0] }
                if ($subArgs.Count -ge 2 -and $subArgs[1]) { $params['TableId'] = $subArgs[1] }
                Format-GgJson (Invoke-GgQueueSeat @params)
            }
            'abandon' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue abandon <queueId> [staff|converted]' }
                $params = @{ QueueId = $subArgs[0] }
                if ($subArgs.Count -ge 2 -and $subArgs[1]) { $params['Reason'] = $subArgs[1] }
                Format-GgJson (Invoke-GgQueueAbandon @params)
            }
            'reopen' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 queue reopen <queueId>' }
                Invoke-GgQueueReopen -QueueId $subArgs[0]
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown queue subcommand: $sub" }
        }
    }

    'role' {
        $sub = $Rest[0]
        $subArgs = if ($Rest.Count -gt 1) { $Rest[1..($Rest.Count - 1)] } else { @() }
        switch ($sub) {
            'permission-catalog' {
                $params = @{}
                if ($subArgs.Count -ge 1 -and $subArgs[0]) { $params['RoleKey'] = $subArgs[0] }
                Format-GgJson (Get-GgRolePermissionCatalog @params)
            }
            'list' { Format-GgJson (Get-GgRoles) }
            'create' {
                if ($subArgs.Count -lt 2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 role create <name> <permission> [permission...]' }
                Format-GgJson (New-GgRole -Name $subArgs[0] -Permissions $subArgs[1..($subArgs.Count - 1)])
            }
            'update' {
                if ($subArgs.Count -lt 2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 role update <roleId> <name-or-dash> [permission...]' }
                $params = @{ RoleId = $subArgs[0] }
                if ($subArgs[1] -ne '-') { $params['Name'] = $subArgs[1] }
                if ($subArgs.Count -gt 2) { $params['Permissions'] = $subArgs[2..($subArgs.Count - 1)] }
                Format-GgJson (Set-GgRole @params)
            }
            'delete' {
                if (-not $subArgs[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_ops.ps1 role delete <roleId>' }
                Remove-GgRole -RoleId $subArgs[0]
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown role subcommand: $sub" }
        }
    }
}
