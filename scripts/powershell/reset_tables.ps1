# Reset all tables to "available", force-clearing any active carts.
# Usage: pwsh ./reset_tables.ps1
# Auths itself (see auth.ps1) if no session exists yet or the existing one has expired.
. "$PSScriptRoot/lib/Bootstrap.ps1"

$resp = Get-GgTables | ConvertFrom-Json
foreach ($t in $resp.result) {
    $msg = Set-GgTableStatus -TableId $t._id -Status 'available'
    Write-GgKv -Key $t._id -Value $msg
}
Write-GgInfo "All tables reset to available"
