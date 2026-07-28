# JSON field extraction with validation, and simple body construction. Dot-sourced by
# Bootstrap.ps1. Mirrors scripts/lib/json.sh — always via ConvertFrom-Json explicitly, never by
# letting Invoke-WebRequest auto-deserialize (that's Http.ps1's job to avoid entirely).

if (Get-Variable -Name _GgJsonLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgJsonLoaded = $true

# Resolve-GgJsonPath <obj> <path> — path like ".result.cartId" or ".result[0]._id"; "." alone
# returns the object itself. Mirrors jq's dotted-path addressing for the small subset this skill
# needs (nested objects + array index), returns $null on any missing segment.
function Resolve-GgJsonPath {
    param($Obj, [string]$Path)

    if ($Path -eq '.') { return $Obj }
    $segments = $Path.TrimStart('.') -split '\.'
    $current = $Obj

    foreach ($seg in $segments) {
        if ($null -eq $current) { return $null }
        if ($seg -match '^([A-Za-z0-9_]+)\[(\d+)\]$') {
            $prop = $Matches[1]; $idx = [int]$Matches[2]
            $current = $current.$prop
            if ($null -eq $current -or $idx -ge @($current).Count) { return $null }
            $current = @($current)[$idx]
        }
        else {
            $current = $current.$seg
        }
    }
    return $current
}

# Get-GgJsonField <json> <path> <label> → prints the field; dies with GgExitContract if the
# field is null, missing, or empty.
function Get-GgJsonField {
    param([Parameter(Mandatory)][string]$Json, [Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)

    $obj = $Json | ConvertFrom-Json -ErrorAction SilentlyContinue
    $value = if ($obj) { Resolve-GgJsonPath -Obj $obj -Path $Path } else { $null }

    if ($null -eq $value -or "$value" -eq '') {
        Write-GgError "expected field missing: $Label ($Path)"
        $excerpt = if ($Json.Length -gt 400) { $Json.Substring(0, 400) } else { $Json }
        Write-GgError "response was: $excerpt"
        exit $Script:GgExitContract
    }
    return "$value"
}

# Get-GgJsonOpt <json> <path> [default] → the field, or default (or empty) if absent/null.
function Get-GgJsonOpt {
    param([Parameter(Mandatory)][string]$Json, [Parameter(Mandatory)][string]$Path, [string]$Default = '')

    $obj = $Json | ConvertFrom-Json -ErrorAction SilentlyContinue
    $value = if ($obj) { Resolve-GgJsonPath -Obj $obj -Path $Path } else { $null }
    if ($null -eq $value -or "$value" -eq '') { return $Default }
    return "$value"
}

# Get-GgJsonMessage <json> → .message, falling back to the whole doc as compact JSON.
function Get-GgJsonMessage {
    param([Parameter(Mandatory)][string]$Json)

    $obj = $Json | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($obj -and $obj.PSObject.Properties.Name -contains 'message' -and $obj.message) {
        return "$($obj.message)"
    }
    return $Json
}

# New-GgJsonObj @{k=v; ...} → a JSON object of string fields, via ConvertTo-Json (safe against
# quotes/backslashes/unicode). For bodies needing numbers/booleans, build a hashtable with real
# typed values and pass it here — ConvertTo-Json preserves the type, unlike a string-only helper.
function New-GgJsonObj {
    param([Parameter(Mandatory)][hashtable]$Fields)
    return ($Fields | ConvertTo-Json -Compress)
}
