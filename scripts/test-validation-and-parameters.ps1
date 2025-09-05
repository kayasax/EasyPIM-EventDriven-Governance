# Test Event Grid Validation Response
# This script tests the validation response format for Event Grid webhook validation

param(
    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName = "easypimakv2gh-fugzcdf2h3eef8gr",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd-test"
)

Write-Host "🧪 Testing Event Grid Validation Response..." -ForegroundColor Cyan

# Get the function URL
Write-Host "🔗 Getting function URL..." -ForegroundColor Blue
try {
    $functionKey = az functionapp keys list --resource-group $ResourceGroupName --name $FunctionAppName --query "functionKeys.default" -o tsv
    if (-not $functionKey) {
        Write-Error "❌ Could not retrieve function key"
        exit 1
    }

    $functionUrl = "https://$FunctionAppName.azurewebsites.net/api/EasyPIM-secret-change-detected?code=$functionKey"
    Write-Host "✅ Function URL obtained" -ForegroundColor Green
    Write-Host "   URL: $functionUrl" -ForegroundColor DarkGray
} catch {
    Write-Error "❌ Failed to get function URL: $_"
    exit 1
}

# Create Event Grid validation event
$validationEvent = @{
    id = [System.Guid]::NewGuid().ToString()
    topic = "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a/resourceGroups/rg-easypim-cicd-test/providers/Microsoft.KeyVault/vaults/kv-easypim-test"
    subject = ""
    eventType = "Microsoft.EventGrid.SubscriptionValidationEvent"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        validationCode = "TEST-VALIDATION-CODE-12345"
    }
    dataVersion = "2"
    metadataVersion = "1"
}

$jsonBody = $validationEvent | ConvertTo-Json -Depth 10

Write-Host "📋 Sending validation event..." -ForegroundColor Blue
Write-Host "Expected response: { `"validationResponse`": `"TEST-VALIDATION-CODE-12345`" }" -ForegroundColor Yellow

try {
    $headers = @{
        "Content-Type" = "application/json"
        "aeg-event-type" = "SubscriptionValidation"
    }

    $response = Invoke-RestMethod -Uri $functionUrl -Method POST -Body $jsonBody -Headers $headers

    Write-Host "✅ Response received!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Green

    # Check if response contains the validation code
    if ($response.validationResponse -eq "TEST-VALIDATION-CODE-12345") {
        Write-Host "🎉 SUCCESS! Event Grid validation response is correct!" -ForegroundColor Green
        Write-Host "   You can now create the Event Grid subscription!" -ForegroundColor Green
    } else {
        Write-Warning "⚠️  Response format may be incorrect. Expected validationResponse field."
    }

} catch {
    Write-Error "❌ Failed to call function: $_"
    Write-Host "Response Details:" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        Write-Host "Body: $responseBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "🔧 Now test with a Key Vault event to verify parameters:" -ForegroundColor Cyan

# Create a Key Vault secret change event to test parameters
$secretEvent = @{
    id = [System.Guid]::NewGuid().ToString()
    topic = "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a/resourceGroups/rg-easypim-cicd-test/providers/Microsoft.KeyVault/vaults/kv-easypim-test"
    subject = "secretnewversion"
    eventType = "Microsoft.KeyVault.SecretNewVersionCreated"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        Id = "https://kv-easypim-test.vault.azure.net/secrets/easypim-test-config/abcd1234efgh5678"
        VaultName = "kv-easypim-test"
        ObjectType = "Secret"
        ObjectName = "easypim-test-config"  # Contains "test" - should trigger WhatIf mode
        Version = "abcd1234efgh5678"
        NBF = 1631234567
        EXP = 1662770567
    }
    dataVersion = "1"
    metadataVersion = "1"
}

$secretJsonBody = $secretEvent | ConvertTo-Json -Depth 10

Write-Host "📋 Sending Key Vault secret change event (with 'test' in name)..." -ForegroundColor Blue
Write-Host "Expected: Should trigger GitHub workflow with WhatIf=true" -ForegroundColor Yellow

try {
    $headers = @{
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod -Uri $functionUrl -Method POST -Body $secretJsonBody -Headers $headers

    Write-Host "✅ Key Vault event processed!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Green

    Write-Host ""
    Write-Host "🔍 Check GitHub Actions now:" -ForegroundColor Cyan
    Write-Host "   1. Go to: https://github.com/kayasax/EasyPIM-CICD-test/actions" -ForegroundColor Yellow
    Write-Host "   2. Look for latest '02-orchestrator-test' workflow run" -ForegroundColor Yellow
    Write-Host "   3. Verify run description mentions 'easypim-test-config'" -ForegroundColor Yellow
    Write-Host "   4. Verify WhatIf mode is enabled (Preview mode)" -ForegroundColor Yellow

} catch {
    Write-Error "❌ Failed to send Key Vault event: $_"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        Write-Host "Body: $responseBody" -ForegroundColor Red
    }
}
