# Petpooja POS integration — menu sync, config, and validation testing.
# Usage: pwsh ./pos.ps1 menu [provider]
#        pwsh ./pos.ps1 items [provider]
#        pwsh ./pos.ps1 sync [provider]
#        pwsh ./pos.ps1 config get|setup|disable [provider]
#        pwsh ./pos.ps1 validate
# Default provider: petpooja. `config setup` requires scripts/config/credentials.env — see
# credentials.example.env.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('menu', 'items', 'sync', 'config', 'validate')][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

switch ($Command) {
    'menu' {
        $provider = if ($Arg1) { $Arg1 } else { $Script:GgPosProvider }
        Get-GgPosMenu -Provider $provider
    }
    'items' {
        $provider = if ($Arg1) { $Arg1 } else { $Script:GgPosProvider }
        Get-GgPosItems -Provider $provider
    }
    'sync' {
        $provider = if ($Arg1) { $Arg1 } else { $Script:GgPosProvider }
        $resp = Start-GgPosSync -Provider $provider
        $resp | ConvertFrom-Json | ConvertTo-Json -Depth 5
    }
    'config' {
        $sub = if ($Arg1) { $Arg1 } else { 'get' }
        switch ($sub) {
            'get' { Get-GgPosConfig }
            'setup' { Set-GgPosConfig }
            'disable' {
                $provider = if ($Arg2) { $Arg2 } else { $Script:GgPosProvider }
                Remove-GgPosConfig -Provider $provider
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: pos.ps1 config get|setup|disable [provider]' }
        }
    }
    'validate' {
        # ONE request per case, not two — the original test_pos_validation.ps1-equivalent logic
        # would have fired each POST twice. -Expect 400 turns "was this rejected?" into a single
        # request's exit code.
        $partnerToken = Get-GgSessionValue -Key 'partnerToken'

        Write-GgInfo 'Fetching foodCategoryId and foodTypeId...'
        # These two endpoints return a bare JSON array (not the usual {result:[...]} wrapper),
        # so the [0].id access is done directly rather than through Get-GgJsonField's simple
        # dotted-path resolver, which doesn't handle a leading array index.
        $catResp = Invoke-GgHttpOrDie -Label 'food category' -Method GET -Path '/v1/partner/food-category' -Token $partnerToken
        $catArr = $catResp | ConvertFrom-Json
        if (-not $catArr -or $catArr.Count -eq 0 -or -not $catArr[0].id) {
            Exit-GgDie -ExitCode $Script:GgExitContract -Message 'expected field missing: foodCategoryId ([0].id)'
        }
        $catId = $catArr[0].id

        $ftResp = Invoke-GgHttpOrDie -Label 'food type' -Method GET -Path '/v1/partner/food-type' -Token $partnerToken
        $ftArr = $ftResp | ConvertFrom-Json
        if (-not $ftArr -or $ftArr.Count -eq 0 -or -not $ftArr[0].id) {
            Exit-GgDie -ExitCode $Script:GgExitContract -Message 'expected field missing: foodTypeId ([0].id)'
        }
        $ftId = $ftArr[0].id

        $baseBody = @{
            item_name          = 'Test Item'
            foodCategoryId     = $catId
            foodTypeId         = $ftId
            description        = 'Test description'
            oPrice             = 100
            portion            = 'Full'
            spicinessLevel     = 1
            dietaryPreference  = 'vegetarian'
            image              = 'https://example.com/test.jpg'
        }

        $fail = $false

        Write-GgInfo 'Test 1: invalid Petpooja itemId'
        $itemBody = $baseBody.Clone()
        $itemBody['pos'] = @{ petpooja = @{ itemId = 'this_id_does_not_exist_in_pos' } }
        Invoke-GgHttp -Method POST -Path '/v1/partner/menu' -Token $partnerToken -JsonBody ($itemBody | ConvertTo-Json -Depth 5) -Expect '400' | Out-Null
        if ($Script:GgHttpExitCode -eq 0) {
            Write-GgInfo "PASS: invalid itemId correctly rejected (HTTP $Script:GgHttpStatus)"
        }
        else {
            Write-GgError "FAIL: invalid itemId was NOT rejected (HTTP $Script:GgHttpStatus)"
            $fail = $true
        }

        Write-GgInfo 'Test 2: invalid Petpooja variationId'
        $varBody = $baseBody.Clone()
        $varBody['variants'] = @(@{ pos = @{ petpooja = @{ variationId = 'invalid_variation_id' } } })
        Invoke-GgHttp -Method POST -Path '/v1/partner/menu' -Token $partnerToken -JsonBody ($varBody | ConvertTo-Json -Depth 5) -Expect '400' | Out-Null
        if ($Script:GgHttpExitCode -eq 0) {
            Write-GgInfo "PASS: invalid variationId correctly rejected (HTTP $Script:GgHttpStatus)"
        }
        else {
            Write-GgError "FAIL: invalid variationId was NOT rejected (HTTP $Script:GgHttpStatus)"
            $fail = $true
        }

        if ($fail) {
            Exit-GgDie -ExitCode $Script:GgExitClient -Message '=== POS Validation Tests: FAILED ==='
        }
        Write-GgInfo '=== POS Validation Tests: all passed ==='
    }
}
