# Admin WABA Flows — flow definitions and their deployments to connected WABAs.
# Usage: pwsh ./waba_flows.ps1 definitions list [key=value ...]
#        pwsh ./waba_flows.ps1 definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]
#        pwsh ./waba_flows.ps1 definitions get <definitionId>
#        pwsh ./waba_flows.ps1 definitions update <definitionId> [name] [categories-csv] [flowJson] [autoProvision]
#        pwsh ./waba_flows.ps1 definitions release <definitionId>
#        pwsh ./waba_flows.ps1 deployments list [key=value ...]
#        pwsh ./waba_flows.ps1 deployments retry <deploymentId>
#        pwsh ./waba_flows.ps1 deployments deprecate <deploymentId>
# categories-csv is comma-separated, e.g. "SIGN_UP,CONTACT_US". Pass "" for an update field you
# don't want to change. Requires admin credentials (see scripts/config/credentials.example.env)
# — Get-GgCachedAdminToken lazily logs in and caches it; manageFlows is super-admin-only, so this
# always uses the admin bearer token, never an X-Api-Key.
#
# Arity varies across subcommands, so every argument is read positionally out of one captured
# array instead of pos.ps1-style named Arg1/Arg2 params — $ArgList[0] is the bash twin's $1.
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$ArgList = @()
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = 'Usage: waba_flows.ps1 definitions list|create|get|update|release [args] | deployments list|retry|deprecate [args]'

function Get-GgTail {
    param([string[]]$All, [int]$Start)
    if ($All.Count -le $Start) { return @() }
    return $All[$Start..($All.Count - 1)]
}

function ConvertTo-GgQueryHashtable {
    param([string[]]$Pairs)
    $q = @{}
    foreach ($p in $Pairs) {
        if ($p -match '^([^=]+)=(.*)$') { $q[$Matches[1]] = $Matches[2] }
    }
    return $q
}

$Group = $ArgList[0]
if (-not $Group) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

$Sub = $ArgList[1]
if (-not $Sub) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Group) {
    'definitions' {
        switch ($Sub) {
            'list' {
                $resp = Get-GgWabaFlowDefinitions -Query (ConvertTo-GgQueryHashtable -Pairs (Get-GgTail -All $ArgList -Start 2))
            }
            'create' {
                $key = $ArgList[2]; $name = $ArgList[3]; $categoriesCsv = $ArgList[4]; $flowJson = $ArgList[5]; $autoProvision = $ArgList[6]
                $usage = 'Usage: waba_flows.ps1 definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]'
                if (-not $key -or -not $name -or -not $categoriesCsv -or -not $flowJson) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
                $resp = New-GgWabaFlowDefinition -Key $key -Name $name -CategoriesCsv $categoriesCsv -FlowJson $flowJson -AutoProvision $autoProvision
            }
            'get' {
                $definitionId = $ArgList[2]
                if (-not $definitionId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: waba_flows.ps1 definitions get <definitionId>' }
                $resp = Get-GgWabaFlowDefinition -DefinitionId $definitionId
            }
            'update' {
                $definitionId = $ArgList[2]; $name = $ArgList[3]; $categoriesCsv = $ArgList[4]; $flowJson = $ArgList[5]; $autoProvision = $ArgList[6]
                if (-not $definitionId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: waba_flows.ps1 definitions update <definitionId> [name] [categories-csv] [flowJson] [autoProvision]' }
                $resp = Update-GgWabaFlowDefinition -DefinitionId $definitionId -Name $name -CategoriesCsv $categoriesCsv -FlowJson $flowJson -AutoProvision $autoProvision
            }
            'release' {
                $definitionId = $ArgList[2]
                if (-not $definitionId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: waba_flows.ps1 definitions release <definitionId>' }
                $resp = Invoke-GgWabaFlowDefinitionRelease -DefinitionId $definitionId
            }
            default {
                Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown subcommand: $Sub. Usage: waba_flows.ps1 definitions list|create|get|update|release [args]"
            }
        }
    }
    'deployments' {
        switch ($Sub) {
            'list' {
                $resp = Get-GgWabaFlowDeployments -Query (ConvertTo-GgQueryHashtable -Pairs (Get-GgTail -All $ArgList -Start 2))
            }
            'retry' {
                $deploymentId = $ArgList[2]
                if (-not $deploymentId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: waba_flows.ps1 deployments retry <deploymentId>' }
                $resp = Invoke-GgWabaFlowDeploymentRetry -DeploymentId $deploymentId
            }
            'deprecate' {
                $deploymentId = $ArgList[2]
                if (-not $deploymentId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: waba_flows.ps1 deployments deprecate <deploymentId>' }
                $resp = Invoke-GgWabaFlowDeploymentDeprecate -DeploymentId $deploymentId
            }
            default {
                Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown subcommand: $Sub. Usage: waba_flows.ps1 deployments list|retry|deprecate [args]"
            }
        }
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown command group: $Group. $Usage"
    }
}

$resp | ConvertFrom-Json | ConvertTo-Json -Depth 10
