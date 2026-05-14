param(
    [Parameter(Mandatory)][string]$ItemId,
    [int]$Qty = 1
)
# Dot-source to set $env:ORDER_ID:
# . $SKILL\order_item.ps1 -ItemId <id> [-Qty 2]

$r = Invoke-RestMethod -Uri "$env:BASE/v1/genie/order?cartId=$env:CART_ID&dinerId=$env:DINER_ID" `
    -Method POST -ContentType "application/json" `
    -Headers @{ Authorization = "Bearer $env:DINER_TOKEN" } `
    -Body "{`"items`":[{`"itemId`":`"$ItemId`",`"quantity`":$Qty}]}"

if (-not $r.result.currentActiveOrder) {
    Write-Error "Failed to create order: $($r | ConvertTo-Json)"
    exit 1
}

$env:ORDER_ID = $r.result.currentActiveOrder
Write-Host "Order: $env:ORDER_ID" -ForegroundColor Cyan

$p = Invoke-RestMethod -Uri "$env:BASE/v1/genie/order/place-order/$($env:ORDER_ID)?cartId=$env:CART_ID" `
    -Method PUT -Headers @{ Authorization = "Bearer $env:DINER_TOKEN" }
Write-Host "Place: $($p.message)" -ForegroundColor Cyan
