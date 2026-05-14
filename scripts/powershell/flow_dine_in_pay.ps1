param(
    [string]$ItemId = "691bf10018f1d3c34db1db00",
    [int]$Qty = 2
)
# Full E2E dine-in + pay-in-person flow.
# Usage: . $SKILL\flow_dine_in_pay.ps1 [-ItemId <id>] [-Qty 2]

$base = if ($env:BASE) { $env:BASE } else { "http://localhost:3000" }

Write-Host "=== Step 1: Partner auth ===" -ForegroundColor Yellow
$r = Invoke-RestMethod -Uri "$base/v1/partner/auth/signin" -Method POST `
    -ContentType "application/json" -Body '{"email":"munch@yopmail.com","password":"Test@123"}'
$partnerToken = $r.result.accessToken
Write-Host "Partner: $($partnerToken.Substring(0,20))..."

Write-Host "`n=== Step 2: Get table ===" -ForegroundColor Yellow
$t = Invoke-RestMethod -Uri "$base/v1/partner/table" -Headers @{ Authorization = "Bearer $partnerToken" }
$tableId = $t.result[0]._id
Write-Host "Table: $tableId"

Write-Host "`n=== Step 3: Diner auth ===" -ForegroundColor Yellow
$d = Invoke-RestMethod -Uri "$base/v1/genie/diner?customDomain=munch2&branchId=3XSJT&fingerprint=grubgenie-stripe-test-002"
$dinerToken = $d.result.accessToken
$dinerId    = $d.result._id
Write-Host "Diner: $dinerId"

Write-Host "`n=== Step 4: Create cart ===" -ForegroundColor Yellow
$c = Invoke-RestMethod -Uri "$base/v1/genie/cart" -Method POST `
    -ContentType "application/json" -Headers @{ Authorization = "Bearer $dinerToken" } `
    -Body "{`"tableId`":`"$tableId`"}"
$cartId = $c.result.cartId
Write-Host "Cart: $cartId"

Write-Host "`n=== Step 5: Create order (itemId=$ItemId qty=$Qty) ===" -ForegroundColor Yellow
$o = Invoke-RestMethod -Uri "$base/v1/genie/order?cartId=$cartId&dinerId=$dinerId" -Method POST `
    -ContentType "application/json" -Headers @{ Authorization = "Bearer $dinerToken" } `
    -Body "{`"items`":[{`"itemId`":`"$ItemId`",`"quantity`":$Qty}]}"
$orderId = $o.result.currentActiveOrder
Write-Host "Order: $orderId"

Write-Host "`n=== Step 6: Place order ===" -ForegroundColor Yellow
$p = Invoke-RestMethod -Uri "$base/v1/genie/order/place-order/$orderId`?cartId=$cartId" `
    -Method PUT -Headers @{ Authorization = "Bearer $dinerToken" }
Write-Host $p.message

Write-Host "`n=== Step 6b: Accept if pending approval ===" -ForegroundColor Yellow
if ($p.message -match "approval") {
    $a = Invoke-RestMethod -Uri "$base/v1/partner/order-history/respond/$orderId" -Method PATCH `
        -ContentType "application/json" -Headers @{ Authorization = "Bearer $partnerToken" } `
        -Body '{"action":"accept"}'
    Write-Host $a.message
} else {
    Write-Host "No approval needed."
}

Write-Host "`n=== Step 7: Pay in person ===" -ForegroundColor Yellow
$pay = Invoke-RestMethod -Uri "$base/v1/genie/cart/$cartId/payment/pay-in-person" -Method POST `
    -ContentType "application/json" -Headers @{ Authorization = "Bearer $dinerToken" } `
    -Body "{`"dinerId`":`"$dinerId`"}"
Write-Host $pay.message

Write-Host "`n=== Step 8: Partner confirms payment ===" -ForegroundColor Yellow
$confirm = Invoke-RestMethod -Uri "$base/v1/partner/order-history/update-payment-status/$cartId" -Method PUT `
    -ContentType "application/json" -Headers @{ Authorization = "Bearer $partnerToken" } `
    -Body '{"paymentStatus":"done","paymentMode":"cash","confirmed":true}'
Write-Host $confirm.message

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Cart: $cartId | Order: $orderId | Diner: $dinerId"
