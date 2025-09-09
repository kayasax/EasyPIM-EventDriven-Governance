# Quick Event Grid Validation Test
# Run this after the function deployment completes

Write-Host "🧪 Quick Event Grid Validation Test" -ForegroundColor Cyan

# Get function URL
$functionKey = az functionapp keys list --resource-group "rg-easypim-cicd-test" --name "easypimAKV2GH" --query "functionKeys.default" -o tsv
$functionUrl = "https://easypimakv2gh-fugzcdf2h3eef8gr.francecentral-01.azurewebsites.net/api/EasyPIM-secret-change-detected?code=$functionKey"

Write-Host "🔗 Function URL: $functionUrl" -ForegroundColor Blue

# Test validation event
$validationEvent = @{
    id = "test-validation"
    topic = "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a/resourceGroups/rg-easypim-cicd-test/providers/Microsoft.KeyVault/vaults/test"
    subject = ""
    eventType = "Microsoft.EventGrid.SubscriptionValidationEvent"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        validationCode = "QUICK-TEST-12345"
    }
    dataVersion = "2"
    metadataVersion = "1"
}

$headers = @{ "Content-Type" = "application/json" }
$body = $validationEvent | ConvertTo-Json -Depth 10

Write-Host "📤 Sending validation event..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $functionUrl -Method POST -Body $body -Headers $headers
    Write-Host "✅ SUCCESS! Response:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json) -ForegroundColor Green

    if ($response.validationResponse -eq "QUICK-TEST-12345") {
        Write-Host "🎉 VALIDATION RESPONSE CORRECT!" -ForegroundColor Green
        Write-Host "   You can now create the Event Grid subscription!" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "🔧 Next: Test Key Vault event with parameters..." -ForegroundColor Cyan

# Test Key Vault event with "test" in name (should trigger WhatIf mode)
$kvEvent = @{
    id = "test-kv"
    topic = "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a/resourceGroups/rg-easypim-cicd-test/providers/Microsoft.KeyVault/vaults/test-vault"
    subject = "secretnewversion"
    eventType = "Microsoft.KeyVault.SecretNewVersionCreated"
    eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    data = @{
        VaultName = "test-vault"
        ObjectName = "easypim-test-secret"  # Contains "test" - should enable WhatIf
        ObjectType = "Secret"
        Version = "abc123"
    }
    dataVersion = "1"
    metadataVersion = "1"
}

$kvBody = $kvEvent | ConvertTo-Json -Depth 10

Write-Host "📤 Sending Key Vault event..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $functionUrl -Method POST -Body $kvBody -Headers $headers
    Write-Host "✅ Key Vault event processed!" -ForegroundColor Green
    Write-Host "🔍 Check GitHub Actions for workflow with WhatIf=true" -ForegroundColor Yellow
    Write-Host "   URL: https://github.com/kayasax/EasyPIM-CICD-test/actions" -ForegroundColor Blue
} catch {
    Write-Host "❌ ERROR processing Key Vault event:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
