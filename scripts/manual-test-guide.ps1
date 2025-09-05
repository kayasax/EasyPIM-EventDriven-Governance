# Manual Test for Event Grid Validation
# This script manually tests the validation response using curl-like approach

Write-Host "🧪 Manual Event Grid Validation Test" -ForegroundColor Cyan

# You'll need to get the function URL from Azure Portal
$functionUrl = "https://easypimakv2gh-fugzcdf2h3eef8gr.francecentral-01.azurewebsites.net/api/EasyPIM-secret-change-detected?code=YOUR_FUNCTION_KEY"

Write-Host "⚠️  Please update the function URL above with your actual function key from Azure Portal" -ForegroundColor Yellow
Write-Host "   Azure Portal → Function App → Functions → EasyPIM-secret-change-detected → Get Function URL" -ForegroundColor Yellow

# Event Grid validation event
$validationEvent = @{
    id = "test-validation-event"
    topic = "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a/resourceGroups/rg-easypim-cicd-test/providers/Microsoft.KeyVault/vaults/test"
    subject = ""
    eventType = "Microsoft.EventGrid.SubscriptionValidationEvent"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        validationCode = "TEST-12345"
    }
    dataVersion = "2"
    metadataVersion = "1"
}

$jsonBody = $validationEvent | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "📋 Test Event JSON:" -ForegroundColor Blue
Write-Host $jsonBody -ForegroundColor DarkGray

Write-Host ""
Write-Host "🔧 PowerShell Test Command:" -ForegroundColor Green
Write-Host @"
`$headers = @{ "Content-Type" = "application/json" }
`$response = Invoke-RestMethod -Uri "$functionUrl" -Method POST -Body '$($jsonBody -replace "'", "''")' -Headers `$headers
`$response | ConvertTo-Json
"@ -ForegroundColor DarkGray

Write-Host ""
Write-Host "✅ Expected Response:" -ForegroundColor Green
Write-Host '{"validationResponse": "TEST-12345"}' -ForegroundColor DarkGray

Write-Host ""
Write-Host "📝 Current Issues Fixed:" -ForegroundColor Cyan
Write-Host "   ✅ Response format: Now uses Push-OutputBinding with HttpResponseContext" -ForegroundColor Green
Write-Host "   ✅ Validation response: Returns validationResponse in JSON format" -ForegroundColor Green
Write-Host "   ✅ Profile.ps1 errors: Azure module calls commented out" -ForegroundColor Green
Write-Host "   ✅ Parameters: Now includes workflow inputs in GitHub API call" -ForegroundColor Green

Write-Host ""
Write-Host "🚀 After successful validation, test with Key Vault event:" -ForegroundColor Cyan
$kvEvent = @{
    id = "test-kv-event"
    topic = "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a/resourceGroups/rg-easypim-cicd-test/providers/Microsoft.KeyVault/vaults/test"
    subject = "secretnewversion"
    eventType = "Microsoft.KeyVault.SecretNewVersionCreated"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        VaultName = "test-vault"
        ObjectName = "easypim-test-config"  # Contains "test" - should enable WhatIf
        ObjectType = "Secret"
        Version = "abc123"
    }
    dataVersion = "1"
    metadataVersion = "1"
}

$kvJsonBody = $kvEvent | ConvertTo-Json -Depth 10
Write-Host "Key Vault test event (should trigger WhatIf mode):" -ForegroundColor DarkGray
Write-Host $kvJsonBody -ForegroundColor DarkGray
