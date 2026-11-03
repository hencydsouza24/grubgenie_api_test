# Admin dashboard — summary tiles, timeseries charts, top-N leaderboards.
# Usage: pwsh ./dashboard.ps1 summary
#        pwsh ./dashboard.ps1 timeseries <metric> <interval> [from] [to]
#        pwsh ./dashboard.ps1 top <metric> [limit]
# timeseries metric: orders|signups|partners|revenue   interval: day|week
# top metric: partners-by-orders|diners-by-orders|dishes|cuisines|partners-by-revenue
# from/to are ISO dates. Requires admin credentials (see scripts/config/credentials.example.env)
# — Get-GgCachedAdminToken lazily logs in and caches it.
param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(Position = 3)][string]$Arg3,
    [Parameter(Position = 4)][string]$Arg4
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = 'Usage: dashboard.ps1 summary|timeseries|top [args]'

if (-not $Command) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Command) {
    'summary' {
        $resp = Get-GgDashboardSummary
    }
    'timeseries' {
        $metric = $Arg1; $interval = $Arg2; $from = $Arg3; $to = $Arg4
        if (-not $metric -or -not $interval) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: dashboard.ps1 timeseries <metric> <interval> [from] [to]' }
        $resp = Get-GgDashboardTimeseries -Metric $metric -Interval $interval -From $from -To $to
    }
    'top' {
        $metric = $Arg1; $limit = $Arg2
        if (-not $metric) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: dashboard.ps1 top <metric> [limit]' }
        $resp = Get-GgDashboardTop -Metric $metric -Limit $limit
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown command: $Command. $Usage"
    }
}

$resp | ConvertFrom-Json | ConvertTo-Json -Depth 10
