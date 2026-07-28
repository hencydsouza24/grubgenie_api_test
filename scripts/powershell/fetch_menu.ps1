# Fetch menu data — browse items, categories, food types, restaurant info.
# Usage: pwsh ./fetch_menu.ps1 [command] [arg]
# Auths itself (see auth.ps1) if no session exists yet or the existing one has expired.
#
# Commands: items [categoryId] | items-search <q> | categories | food-types | restaurant-info |
#           branches [domain] | item <id> | partner-items | dietary | allergens | offers |
#           combos | combo <id> | partner-combos | partner-combo <id> | reels | stories |
#           item-by-media <mediaId>
param(
    [Parameter(Position = 0)][string]$Command = 'items',
    [Parameter(Position = 1)][string]$Arg
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

switch ($Command) {
    'items' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        $query = if ($Arg) { @{ foodCategoryId = $Arg } } else { $null }
        $resp = Invoke-GgHttpOrDie -Label 'menu items' -Method GET -Path '/v1/genie/menu' -Token $dinerToken -Query $query
        $r = $resp | ConvertFrom-Json
        [PSCustomObject]@{
            total = $r.totalResults
            pages = $r.totalPages
            items = @($r.result | ForEach-Object { [PSCustomObject]@{ _id = $_._id; name = $_.item_name; price = $_.oPrice; dPrice = $_.dPrice; category = $_.foodCategoryId; isActive = $_.isActive } })
        } | ConvertTo-Json -Depth 5
    }
    'items-search' {
        if (-not $Arg) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: fetch_menu.ps1 items-search <query>' }
        $partnerToken = Get-GgSessionValue -Key 'partnerToken'
        $resp = Invoke-GgHttpOrDie -Label 'item search' -Method GET -Path '/v1/partner/menu/item/search' -Token $partnerToken -Query @{ q = $Arg }
        @(($resp | ConvertFrom-Json).result | Select-Object _id, @{n = 'name'; e = { $_.itemName } }, price) | ConvertTo-Json -Depth 5
    }
    'categories' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        $resp = Invoke-GgHttpOrDie -Label 'categories' -Method GET -Path '/v1/genie/menu/food-category' -Token $dinerToken
        @(($resp | ConvertFrom-Json).result | Select-Object _id, @{n = 'name'; e = { $_.food_category } }, sequence) | ConvertTo-Json -Depth 5
    }
    'food-types' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        $resp = Invoke-GgHttpOrDie -Label 'food types' -Method GET -Path '/v1/genie/menu/food-type' -Token $dinerToken
        @(($resp | ConvertFrom-Json).result | Select-Object _id, name) | ConvertTo-Json -Depth 5
    }
    'restaurant-info' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        $resp = Invoke-GgHttpOrDie -Label 'restaurant info' -Method GET -Path '/v1/genie/menu/restaurant-info' -Token $dinerToken
        $r = ($resp | ConvertFrom-Json).result
        [PSCustomObject]@{ name = $r.restaurantName; logo = $r.logoURL; address = $r.address } | ConvertTo-Json -Depth 5
    }
    'branches' {
        $domain = if ($Arg) { $Arg } else { $Script:GgCustomDomain }
        $resp = Invoke-GgHttpOrDie -Label 'branches' -Method GET -Path "/v1/genie/menu/restaurant-branches/$domain"
        $r = ($resp | ConvertFrom-Json).result
        [PSCustomObject]@{
            name     = $r.restaurantName
            branches = @($r.branches | ForEach-Object { [PSCustomObject]@{ _id = $_._id; name = $_.branchName } })
        } | ConvertTo-Json -Depth 5
    }
    'item' {
        if (-not $Arg) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: fetch_menu.ps1 item <menuItemId>' }
        $partnerToken = Get-GgSessionValue -Key 'partnerToken'
        $resp = Invoke-GgHttpOrDie -Label 'item' -Method GET -Path "/v1/partner/menu/item/$Arg" -Token $partnerToken
        $r = ($resp | ConvertFrom-Json).result
        [PSCustomObject]@{ _id = $r._id; name = $r.itemName; price = $r.price; category = $r.foodCategory; isActive = $r.isActive } | ConvertTo-Json -Depth 5
    }
    'partner-items' {
        $partnerToken = Get-GgSessionValue -Key 'partnerToken'
        $resp = Invoke-GgHttpOrDie -Label 'partner items' -Method GET -Path '/v1/partner/menu/item' -Token $partnerToken
        $r = $resp | ConvertFrom-Json
        [PSCustomObject]@{
            total = $r.totalResults
            items = @($r.result | ForEach-Object { [PSCustomObject]@{ _id = $_._id; name = $_.item_name; price = $_.oPrice; isActive = $_.isActive } })
        } | ConvertTo-Json -Depth 5
    }
    'dietary' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        (Invoke-GgHttpOrDie -Label 'dietary preferences' -Method GET -Path '/v1/genie/menu/dietary-preference' -Token $dinerToken | ConvertFrom-Json).result | ConvertTo-Json -Depth 5
    }
    'allergens' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        (Invoke-GgHttpOrDie -Label 'allergens' -Method GET -Path '/v1/genie/menu/allergens' -Token $dinerToken | ConvertFrom-Json).result | ConvertTo-Json -Depth 5
    }
    'offers' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        (Invoke-GgHttpOrDie -Label 'offers' -Method GET -Path '/v1/genie/menu/offers' -Token $dinerToken | ConvertFrom-Json).result | ConvertTo-Json -Depth 5
    }
    'combos' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        $resp = Invoke-GgHttpOrDie -Label 'combos' -Method GET -Path '/v1/genie/combo' -Token $dinerToken
        @(($resp | ConvertFrom-Json).result | Select-Object _id, @{n = 'name'; e = { $_.comboName } }, @{n = 'price'; e = { $_.dPrice } }, isActive) | ConvertTo-Json -Depth 5
    }
    'combo' {
        if (-not $Arg) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: fetch_menu.ps1 combo <comboId>' }
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        $resp = Invoke-GgHttpOrDie -Label 'combo' -Method GET -Path "/v1/genie/combo/$Arg" -Token $dinerToken
        $r = ($resp | ConvertFrom-Json).result
        [PSCustomObject]@{
            _id      = $r._id; name = $r.comboName; price = $r.dPrice; isActive = $r.isActive
            items    = @($r.items | ForEach-Object { [PSCustomObject]@{ itemId = $_.menuItemId; qty = $_.quantity } })
        } | ConvertTo-Json -Depth 5
    }
    'partner-combos' {
        $partnerToken = Get-GgSessionValue -Key 'partnerToken'
        $resp = Invoke-GgHttpOrDie -Label 'partner combos' -Method GET -Path '/v1/partner/combo' -Token $partnerToken
        @(($resp | ConvertFrom-Json).result | Select-Object _id, @{n = 'name'; e = { $_.comboName } }, @{n = 'price'; e = { $_.dPrice } }, isActive) | ConvertTo-Json -Depth 5
    }
    'partner-combo' {
        if (-not $Arg) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: fetch_menu.ps1 partner-combo <comboId>' }
        $partnerToken = Get-GgSessionValue -Key 'partnerToken'
        $resp = Invoke-GgHttpOrDie -Label 'partner combo' -Method GET -Path "/v1/partner/combo/$Arg" -Token $partnerToken
        $r = ($resp | ConvertFrom-Json).result
        [PSCustomObject]@{
            _id   = $r._id; name = $r.comboName; price = $r.dPrice; isActive = $r.isActive
            items = @($r.items | ForEach-Object { [PSCustomObject]@{ itemId = $_.menuItemId; qty = $_.quantity } })
        } | ConvertTo-Json -Depth 5
    }
    'reels' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        (Invoke-GgHttpOrDie -Label 'reels' -Method GET -Path '/v1/genie/menu/reels' -Token $dinerToken | ConvertFrom-Json).result | ConvertTo-Json -Depth 5
    }
    'stories' {
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        (Invoke-GgHttpOrDie -Label 'stories' -Method GET -Path '/v1/genie/menu/stories' -Token $dinerToken | ConvertFrom-Json).result | ConvertTo-Json -Depth 5
    }
    'item-by-media' {
        if (-not $Arg) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: fetch_menu.ps1 item-by-media <mediaId>' }
        $dinerToken = Get-GgSessionValue -Key 'dinerToken'
        (Invoke-GgHttpOrDie -Label 'item by media' -Method GET -Path '/v1/genie/menu/item-by-media-id' -Token $dinerToken -Query @{ mediaId = $Arg } | ConvertFrom-Json).result | ConvertTo-Json -Depth 5
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown command: $Command"
    }
}
