# Dot-source this to export tokens to current session:
# . $SKILL\auth.ps1

$base = if ($env:BASE) { $env:BASE } else { "http://localhost:3000" }
$env:BASE = $base

$r = Invoke-RestMethod -Uri "$base/v1/partner/auth/signin" -Method POST `
    -ContentType "application/json" `
    -Body '{"email":"munchuser@yopmail.com","password":"Test@123"}'
$env:PARTNER_TOKEN = $r.result.accessToken

$t = Invoke-RestMethod -Uri "$base/v1/partner/table" `
    -Headers @{ Authorization = "Bearer $env:PARTNER_TOKEN" }
$env:TABLE_ID = $t.result[0]._id

$d = Invoke-RestMethod -Uri "$base/v1/genie/diner?customDomain=munch2&branchId=3XSJT&fingerprint=grubgenie-stripe-test-002"
$env:DINER_TOKEN = $d.result.accessToken
$env:DINER_ID    = $d.result._id

Write-Host "Partner: $($env:PARTNER_TOKEN.Substring(0,20))..." -ForegroundColor Cyan
Write-Host "Table:   $env:TABLE_ID" -ForegroundColor Cyan
Write-Host "Diner:   $env:DINER_ID" -ForegroundColor Cyan
