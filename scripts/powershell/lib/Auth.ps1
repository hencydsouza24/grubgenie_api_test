# Idempotent session acquisition + session-file persistence. Dot-sourced by Bootstrap.ps1.
# Mirrors scripts/lib/auth.sh, and writes/reads the SAME session file path convention (see
# Get-GgTempDir in Env.ps1) — this is what lets a bash auth.sh run and a PowerShell order.ps1 run
# share one session on the same machine.

if (Get-Variable -Name _GgAuthLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgAuthLoaded = $true

# Get-GgSessionFilePath [-Name env_name] → path to the session file for that environment.
function Get-GgSessionFilePath {
    param([string]$Name)
    if (-not $Name) { $Name = Get-GgEnvName }
    if ($env:GG_SESSION_FILE) { return $env:GG_SESSION_FILE }
    return (Join-Path (Get-GgTempDir) "grubgenie-session-$Name.json")
}

# Import-GgCredentials → dot-sources scripts/config/credentials.env (a simple KEY=VALUE file, one
# per line, shared with the bash side) into $env: vars, if present. Silent no-op if absent.
function Import-GgCredentials {
    $credFile = Join-Path $Script:GgSkillDir 'config/credentials.env'
    if (-not (Test-Path $credFile)) { return }
    Get-Content $credFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $parts = $line -split '=', 2
        if ($parts.Count -eq 2) {
            [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim())
        }
    }
}

function Test-GgSessionFresh {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $age = (Get-Date) - (Get-Item $Path).LastWriteTime
    return $age.TotalSeconds -lt $Script:GgSessionTtl
}

function Get-GgPartnerToken {
    param([Parameter(Mandatory)][string]$Base)
    $body = New-GgJsonObj @{ email = $Script:GgPartnerEmail; password = $Script:GgPartnerPassword }
    $resp = Invoke-GgHttpOrDie -Label 'partner signin' -Method POST -Path "$Base/v1/partner/auth/signin" -JsonBody $body
    return Get-GgJsonField -Json $resp -Path '.result.accessToken' -Label 'partner accessToken'
}

# Get-GgAdminToken — requires $env:GG_ADMIN_EMAIL / $env:GG_ADMIN_PASSWORD from credentials.env.
function Get-GgAdminToken {
    param([Parameter(Mandatory)][string]$Base)
    Import-GgCredentials
    if (-not $env:GG_ADMIN_EMAIL -or -not $env:GG_ADMIN_PASSWORD) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_ADMIN_EMAIL/GG_ADMIN_PASSWORD not set — see scripts/config/credentials.example.env'
    }
    $body = New-GgJsonObj @{ email = $env:GG_ADMIN_EMAIL; password = $env:GG_ADMIN_PASSWORD }
    $resp = Invoke-GgHttpOrDie -Label 'admin signin' -Method POST -Path "$Base/v1/admin/auth/signin" -JsonBody $body
    return Get-GgJsonField -Json $resp -Path '.result.accessToken' -Label 'admin accessToken'
}

# Get-GgJwtField <token> <claim> → decode a JWT's payload (base64url, unverified — same trust
# level as everywhere else in this skill, which already holds the bearer token in plaintext) and
# return one claim.
function Get-GgJwtField {
    param([Parameter(Mandatory)][string]$Token, [Parameter(Mandatory)][string]$Claim)

    $payload = $Token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $payload += ('=' * ((4 - $payload.Length % 4) % 4))
    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
    $obj = $json | ConvertFrom-Json
    return "$($obj.$Claim)"
}

# Get-GgDinerAuth <base> <partnerToken> → returns @{ BranchId; TableId; DinerToken; DinerId }
#
# branchId is decoded from the PARTNER TOKEN's own claim, not a hardcoded constant. A partner
# account can have multiple branches (confirmed live: this test account has 9), and the JWT's
# branchId reflects whichever one is CURRENTLY SELECTED via /v1/partner/branch/switch-branch —
# the account's active branch can change over time. A fixed literal here goes stale the moment
# someone switches branches: /v1/partner/table (called with this same token) returns tables
# scoped to the active branch, so if the diner authenticates against a DIFFERENT branchId than
# the partner's active one, cart creation 404s ("Table not found") even though both branchIds are
# individually valid.
function Get-GgDinerAuth {
    param([Parameter(Mandatory)][string]$Base, [Parameter(Mandatory)][string]$PartnerToken)

    $branchId = Get-GgJwtField -Token $PartnerToken -Claim 'branchId'
    if (-not $branchId) {
        Exit-GgDie -ExitCode $Script:GgExitContract -Message 'could not decode branchId from partner token'
    }

    $resp = Invoke-GgHttpOrDie -Label 'table fetch' -Method GET -Path "$Base/v1/partner/table" -Token $PartnerToken
    $tableId = Get-GgJsonField -Json $resp -Path '.result[0]._id' -Label 'table id'

    $dinerResp = Invoke-GgHttpOrDie -Label 'diner auth' -Method GET -Path "$Base/v1/genie/diner" -Query @{
        customDomain = $Script:GgCustomDomain
        branchId     = $branchId
        fingerprint  = $Script:GgFingerprint
    }

    $dinerToken = Get-GgJsonField -Json $dinerResp -Path '.result.accessToken' -Label 'diner accessToken'
    $dinerId = Get-GgJsonField -Json $dinerResp -Path '.result._id' -Label 'diner id'

    return @{ BranchId = $branchId; TableId = $tableId; DinerToken = $dinerToken; DinerId = $dinerId }
}

# Confirm-GgSession [-Force] → writes/refreshes the session file for the current environment and
# returns its path. Idempotent: reuses a fresh (< GgSessionTtl seconds old) session unless
# -Force or the file is stale/missing.
function Confirm-GgSession {
    param([switch]$Force)

    $envName = Get-GgEnvName
    $base = Resolve-GgBase
    $path = Get-GgSessionFilePath -Name $envName

    if (-not $Force -and (Test-GgSessionFresh -Path $path)) {
        return $path
    }

    Write-GgStep -Number '1' -Title "Authenticating ($envName)"

    $partnerToken = Get-GgPartnerToken -Base $base
    $diner = Get-GgDinerAuth -Base $base -PartnerToken $partnerToken

    $session = @{
        base         = $base
        env          = $envName
        branchId     = $diner.BranchId
        partnerToken = $partnerToken
        tableId      = $diner.TableId
        dinerToken   = $diner.DinerToken
        dinerId      = $diner.DinerId
    }

    ($session | ConvertTo-Json -Compress) | Set-Content -Path $path -NoNewline

    Write-GgKv -Key 'Partner token' -Value ($partnerToken.Substring(0, [Math]::Min(20, $partnerToken.Length)) + '...')
    Write-GgKv -Key 'Table' -Value $diner.TableId
    Write-GgKv -Key 'Diner' -Value $diner.DinerId

    return $path
}

# Get-GgSessionValue <key> → reads one field from the current session, auth'ing first if needed.
function Get-GgSessionValue {
    param([Parameter(Mandatory)][string]$Key)
    $path = Confirm-GgSession
    $session = Get-Content $path -Raw | ConvertFrom-Json
    return "$($session.$Key)"
}
