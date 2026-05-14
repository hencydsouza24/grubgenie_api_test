# Dot-source to set $env:CART_ID:
# . $SKILL\create_cart.ps1

$r = Invoke-RestMethod -Uri "$env:BASE/v1/genie/cart" -Method POST `
    -ContentType "application/json" `
    -Headers @{ Authorization = "Bearer $env:DINER_TOKEN" } `
    -Body "{`"tableId`":`"$env:TABLE_ID`"}"

if (-not $r.result.cartId) {
    Write-Error "Failed to create cart: $($r | ConvertTo-Json)"
    exit 1
}

$env:CART_ID = $r.result.cartId
Write-Host "Cart: $env:CART_ID" -ForegroundColor Cyan
