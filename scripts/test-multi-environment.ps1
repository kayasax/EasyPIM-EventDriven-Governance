# Test Multi-Environment Configuration Detection
# This script tests the new dynamic configuration path capability

param(
    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName = "easypimakv2gh-fugzcdf2h3eef8gr",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd-test",

    [Parameter(Mandatory = $false)]
    [string]$VaultName = "kv-easypim-cicd-fugzcdf",

    [Parameter(Mandatory = $false)]
    [switch]$TestDriftDetection = $false
)

Write-Host "🧪 Testing Multi-Environment Configuration Detection..." -ForegroundColor Cyan

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
} catch {
    Write-Error "❌ Failed to get function URL: $_"
    exit 1
}

# Test cases for different environment configurations
$testCases = @(
    @{
        Name = "Test Environment"
        SecretName = "pim-config-test"
        ExpectedWhatIf = $true
        ExpectedMode = "delta"
        Description = "Should trigger WhatIf mode for test environments"
    },
    @{
        Name = "Production Environment" 
        SecretName = "pim-config-prod"
        ExpectedWhatIf = $false
        ExpectedMode = "delta"
        Description = "Should trigger full execution for production"
    },
    @{
        Name = "Development Environment"
        SecretName = "pim-config-dev"
        ExpectedWhatIf = $true
        ExpectedMode = "delta"
        Description = "Should trigger WhatIf mode for development (contains pattern)"
    },
    @{
        Name = "Initial Setup"
        SecretName = "pim-initial-setup"
        ExpectedWhatIf = $false
        ExpectedMode = "initial"
        Description = "Should trigger initial mode for setup scenarios"
    },
    @{
        Name = "Custom Configuration"
        SecretName = "custom-pim-environment"
        ExpectedWhatIf = $false
        ExpectedMode = "delta"
        Description = "Should handle custom naming without special logic"
    }
)

Write-Host "🎯 Testing configuration detection for different secret names..." -ForegroundColor Yellow

foreach ($testCase in $testCases) {
    Write-Host "`n📋 Testing: $($testCase.Name)" -ForegroundColor Magenta
    Write-Host "   Secret: $($testCase.SecretName)" -ForegroundColor White
    Write-Host "   Expected: WhatIf=$($testCase.ExpectedWhatIf), Mode=$($testCase.ExpectedMode)" -ForegroundColor White
    Write-Host "   $($testCase.Description)" -ForegroundColor DarkGray

    # Create Event Grid secret change event
    $eventData = @{
        topic = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/$VaultName"
        subject = "KeyVault/$VaultName/secrets/$($testCase.SecretName)/a1b2c3d4e5f6"
        eventType = "Microsoft.KeyVault.SecretNewVersionCreated"
        eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        id = [System.Guid]::NewGuid().ToString()
        data = @{
            Id = "https://$VaultName.vault.azure.net/secrets/$($testCase.SecretName)/a1b2c3d4e5f6"
            VaultName = $VaultName
            ObjectType = "Secret"
            ObjectName = $testCase.SecretName
            Version = "a1b2c3d4e5f6"
            NBF = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            EXP = [DateTimeOffset]::UtcNow.AddYears(1).ToUnixTimeSeconds()
        }
        dataVersion = "1"
        metadataVersion = "1"
    }

    $requestBody = @($eventData) | ConvertTo-Json -Depth 5

    try {
        Write-Host "   🚀 Sending test event..." -ForegroundColor Blue
        
        $response = Invoke-RestMethod -Uri $functionUrl -Method POST -Body $requestBody -ContentType "application/json" -Verbose:$false
        
        Write-Host "   ✅ Response received: $response" -ForegroundColor Green
        Write-Host "   💡 Check GitHub Actions to verify parameters were set correctly" -ForegroundColor Cyan
        
    } catch {
        Write-Warning "   ⚠️ Request failed: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            Write-Host "   Status Code: $statusCode" -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds 2
}

Write-Host "`n🎉 Multi-environment testing complete!" -ForegroundColor Green

if ($TestDriftDetection) {
    Write-Host "`n🔍 Testing Drift Detection with different configurations..." -ForegroundColor Cyan
    
    foreach ($testCase in $testCases) {
        Write-Host "`n📊 Testing Drift Detection: $($testCase.Name)" -ForegroundColor Magenta
        Write-Host "   Using ConfigSecretName: $($testCase.SecretName)" -ForegroundColor White
        
        try {
            Write-Host "   🚀 Triggering drift detection workflow..." -ForegroundColor Blue
            & "$PSScriptRoot\Invoke-DriftDetection.ps1" -ConfigSecretName $testCase.SecretName -Verbose $true -Repository "kayasax/EasyPIM-CICD-test"
            Write-Host "   ✅ Drift detection triggered successfully" -ForegroundColor Green
        } catch {
            Write-Warning "   ⚠️ Drift detection trigger failed: $($_.Exception.Message)"
        }
        
        Start-Sleep -Seconds 5
    }
}

Write-Host "`n💡 Key improvements in v1.1:" -ForegroundColor Cyan
Write-Host "   • Dynamic configuration paths based on secret names" -ForegroundColor White
Write-Host "   • Automatic environment detection (test/dev vs prod)" -ForegroundColor White
Write-Host "   • Intelligent parameter setting based on naming patterns" -ForegroundColor White
Write-Host "   • Full backward compatibility with manual triggers" -ForegroundColor White
Write-Host "   • Multi-environment support for both orchestrator and drift detection workflows" -ForegroundColor White

Write-Host "`n📊 Check your GitHub Actions runs to see the new configSecretName parameter in action!" -ForegroundColor Yellow
Write-Host "💡 Use -TestDriftDetection switch to also test drift detection workflow triggers" -ForegroundColor Cyan
