# Test Azure Function Parameter Handling
# This script tests the enhanced parameter functionality by simulating different event types

param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionUrl,

    [Parameter(Mandatory = $false)]
    [string]$TestType = "normal"
)

Write-Host "🧪 Testing Azure Function Parameter Handling..." -ForegroundColor Cyan

# Define test scenarios
$testScenarios = @{
    "normal" = @{
        secretName = "easypim-config"
        vaultName = "kv-easypim-prod"
        expectedWhatIf = $false
        expectedMode = "delta"
        description = "Normal secret change"
    }
    "test" = @{
        secretName = "easypim-test-config"
        vaultName = "kv-easypim-test"
        expectedWhatIf = $true
        expectedMode = "delta"
        description = "Test secret (should trigger WhatIf mode)"
    }
    "initial" = @{
        secretName = "easypim-initial-setup"
        vaultName = "kv-easypim-prod"
        expectedWhatIf = $false
        expectedMode = "initial"
        description = "Initial setup secret (should use initial mode)"
    }
    "debug" = @{
        secretName = "easypim-debug-config"
        vaultName = "kv-easypim-dev"
        expectedWhatIf = $true
        expectedMode = "delta"
        description = "Debug secret (should trigger WhatIf mode)"
    }
}

$scenario = $testScenarios[$TestType]
if (-not $scenario) {
    Write-Error "❌ Invalid test type. Valid options: $($testScenarios.Keys -join ', ')"
    exit 1
}

Write-Host "📋 Test Scenario: $($scenario.description)" -ForegroundColor Blue
Write-Host "   Secret: $($scenario.secretName)"
Write-Host "   Vault: $($scenario.vaultName)"
Write-Host "   Expected WhatIf: $($scenario.expectedWhatIf)"
Write-Host "   Expected Mode: $($scenario.expectedMode)"

# Create test Event Grid event
$testEvent = @{
    id = [System.Guid]::NewGuid().ToString()
    topic = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-easypim/providers/Microsoft.KeyVault/vaults/$($scenario.vaultName)"
    subject = "secretnewversion"
    eventType = "Microsoft.KeyVault.SecretNewVersionCreated"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        Id = "https://$($scenario.vaultName).vault.azure.net/secrets/$($scenario.secretName)/abcd1234efgh5678"
        VaultName = $scenario.vaultName
        ObjectType = "Secret"
        ObjectName = $scenario.secretName
        Version = "abcd1234efgh5678"
        NBF = 1631234567
        EXP = 1662770567
    }
    dataVersion = "1"
    metadataVersion = "1"
}

# Convert to JSON
$jsonBody = $testEvent | ConvertTo-Json -Depth 10

Write-Host "🚀 Sending test event to function..." -ForegroundColor Blue
Write-Host "Event JSON:" -ForegroundColor DarkGray
Write-Host $jsonBody -ForegroundColor DarkGray

try {
    # Send the test event
    $headers = @{
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod -Uri $FunctionUrl -Method POST -Body $jsonBody -Headers $headers

    Write-Host "✅ Function response received!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Green

} catch {
    Write-Error "❌ Failed to call function: $_"
    Write-Host "Response Details:" -ForegroundColor Red
    Write-Host $_.Exception.Response -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📊 Test Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Function executed successfully"
Write-Host "   ✅ Parameters should be adjusted based on secret name pattern"
Write-Host "   ✅ Check GitHub Actions for workflow run with correct parameters"
Write-Host ""
Write-Host "🔍 Verify in GitHub Actions:" -ForegroundColor Yellow
Write-Host "   1. Go to your repository → Actions tab"
Write-Host "   2. Look for the latest '02-orchestrator-test' workflow run"
Write-Host "   3. Check the run description for: '$($scenario.description)'"
Write-Host "   4. Verify WhatIf mode is: $($scenario.expectedWhatIf)"
Write-Host "   5. Verify Mode is: $($scenario.expectedMode)"
