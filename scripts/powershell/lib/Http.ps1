# HTTP transport. Owns status handling. Knows nothing about domain semantics — see Api.ps1.
# Dot-sourced by Bootstrap.ps1. Mirrors scripts/lib/http.sh's contract, adapted to how PowerShell
# actually propagates state: a PS function runs IN-PROCESS (unlike `body=$(gg_http ...)` in bash,
# which forks a subshell), so $Script:GgHttpStatus set here is directly visible to the caller —
# no file-backed workaround needed. $Script:GgHttpExitCode is the PS analog of bash's $? — read
# it immediately after every Invoke-GgHttp call.

if (Get-Variable -Name _GgHttpLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgHttpLoaded = $true

$Script:GgHttpStatus = $null
$Script:GgHttpExitCode = $null

# spec: "2xx"-style class match | "any" | comma list of exact codes, e.g. "400,409"
function Test-GgExpectMatch {
    param([Parameter(Mandatory)][int]$Status, [Parameter(Mandatory)][string]$Spec)

    if ($Spec -eq 'any') { return $true }
    foreach ($code in ($Spec -split ',')) {
        $code = $code.Trim()
        if ($code -match '^[0-9]xx$') {
            if ("$Status".Substring(0, 1) -eq $code.Substring(0, 1)) { return $true }
        }
        elseif ("$Status" -eq $code) {
            return $true
        }
    }
    return $false
}

# Invoke-GgHttp -Method <M> -Path <p> [-Token T] [-JsonBody B] [-Query @{k=v}] [-Expect SPEC]
# Returns: response body as a STRING — never a deserialized object (ConvertFrom-Json is Json.ps1's
# job, explicitly, so bash `jq -r` and PS both operate on the same raw text).
# Side effects: $Script:GgHttpStatus (numeric, or 0 if unreachable) and $Script:GgHttpExitCode
# (0/4/5/7 — numerically identical to the bash twin's return codes).
function Invoke-GgHttp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [string]$Token,
        [string]$JsonBody,
        [hashtable]$Query,
        [string]$Expect = '2xx'
    )

    $url = if ($Path -match '^https?://') { $Path } else { (Resolve-GgBase) + $Path }

    if ($Query -and $Query.Count -gt 0) {
        $pairs = foreach ($k in $Query.Keys) { "$k=$($Query[$k])" }
        $qs = [string]::Join('&', $pairs)
        $url += $(if ($url.Contains('?')) { '&' } else { '?' }) + $qs
    }

    $headers = @{}
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }

    $params = @{
        Uri        = $url
        Method     = $Method
        Headers    = $headers
        TimeoutSec = $Script:GgMaxTime
    }
    if ($JsonBody) {
        $params['Body'] = $JsonBody
        $params['ContentType'] = 'application/json'
    }

    $status = 0
    $body = ''

    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # -SkipHttpErrorCheck is what makes Invoke-WebRequest behave like `curl -s`: it
            # returns a response object on 4xx/5xx instead of throwing.
            $resp = Invoke-WebRequest @params -SkipHttpErrorCheck
            $status = [int]$resp.StatusCode
            $body = $resp.Content
        }
        else {
            # PS 5.1 has no -SkipHttpErrorCheck; Invoke-WebRequest throws on non-2xx and the
            # status/body must be recovered from the WebException.
            $resp = Invoke-WebRequest @params -UseBasicParsing
            $status = [int]$resp.StatusCode
            $body = $resp.Content
        }
    }
    catch [System.Net.WebException] {
        $webResp = $_.Exception.Response
        if ($null -eq $webResp) {
            $status = 0
        }
        else {
            $status = [int]$webResp.StatusCode
            $stream = $webResp.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
            $reader.Close()
        }
    }
    catch {
        # DNS failure, connection refused, timeout on some platforms — treat as unreachable.
        $status = 0
    }

    $Script:GgHttpStatus = $status
    $statusStr = if ($status -eq 0) { '000' } else { "$status" }
    Write-GgInfo "$Method $url -> $statusStr"

    if ($status -eq 0) {
        $Script:GgHttpExitCode = $Script:GgExitTransport
    }
    elseif (Test-GgExpectMatch -Status $status -Spec $Expect) {
        $Script:GgHttpExitCode = $Script:GgExitOk
    }
    elseif ($status -ge 400 -and $status -lt 500) {
        $Script:GgHttpExitCode = $Script:GgExitClient
    }
    else {
        $Script:GgHttpExitCode = $Script:GgExitServer
    }

    return $body
}

function Invoke-GgGet    { param([Parameter(Mandatory)][string]$Path, [string]$Token, [hashtable]$Query, [string]$Expect = '2xx') Invoke-GgHttp -Method GET -Path $Path -Token $Token -Query $Query -Expect $Expect }
function Invoke-GgPost   { param([Parameter(Mandatory)][string]$Path, [string]$Token, [string]$JsonBody, [hashtable]$Query, [string]$Expect = '2xx') Invoke-GgHttp -Method POST -Path $Path -Token $Token -JsonBody $JsonBody -Query $Query -Expect $Expect }
function Invoke-GgPut    { param([Parameter(Mandatory)][string]$Path, [string]$Token, [string]$JsonBody, [hashtable]$Query, [string]$Expect = '2xx') Invoke-GgHttp -Method PUT -Path $Path -Token $Token -JsonBody $JsonBody -Query $Query -Expect $Expect }
function Invoke-GgPatch  { param([Parameter(Mandatory)][string]$Path, [string]$Token, [string]$JsonBody, [hashtable]$Query, [string]$Expect = '2xx') Invoke-GgHttp -Method PATCH -Path $Path -Token $Token -JsonBody $JsonBody -Query $Query -Expect $Expect }
function Invoke-GgDelete { param([Parameter(Mandatory)][string]$Path, [string]$Token, [hashtable]$Query, [string]$Expect = '2xx') Invoke-GgHttp -Method DELETE -Path $Path -Token $Token -Query $Query -Expect $Expect }

# Invoke-GgHttpOrDie <label> <same params as Invoke-GgHttp> — same call, but on a non-success
# exit code it prints <label> + status + a body excerpt and terminates the process with that
# exit code. This is the "must succeed" call site every Auth.ps1/Api.ps1 function uses.
function Invoke-GgHttpOrDie {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [string]$Token,
        [string]$JsonBody,
        [hashtable]$Query,
        [string]$Expect = '2xx'
    )

    $body = Invoke-GgHttp -Method $Method -Path $Path -Token $Token -JsonBody $JsonBody -Query $Query -Expect $Expect

    if ($Script:GgHttpExitCode -ne 0) {
        Write-GgError "$Label failed (HTTP $Script:GgHttpStatus)"
        $excerpt = if ($body.Length -gt 300) { $body.Substring(0, 300) } else { $body }
        Write-GgError "response: $excerpt"
        exit $Script:GgHttpExitCode
    }
    return $body
}
