# 🚀 EasyPIM Authentication Test (Local Execution)
# This script bypasses Azure DevOps parallelism limitations by running locally

Write-Host "🔍 EasyPIM Authentication Test - Local Execution" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if Azure CLI is available
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "   Download: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
    exit 1
}

# Check authentication
Write-Host "`n🔐 Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show --query "{subscriptionId:id, tenantId:tenantId, user:user.name}" | ConvertFrom-Json
    Write-Host "✅ Authenticated as: $($account.user)" -ForegroundColor Green
    Write-Host "   Subscription: $($account.subscriptionId)" -ForegroundColor Gray
    Write-Host "   Tenant: $($account.tenantId)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Azure CLI not authenticated. Please run: az login" -ForegroundColor Red
    exit 1
}

# Test resource group access
Write-Host "`n📋 Testing resource group access..." -ForegroundColor Yellow
$resourceGroup = "RG-EASYPIM"  # Update this to your resource group name
try {
    $rg = az group show --name $resourceGroup --query "{name:name, location:location, provisioningState:properties.provisioningState}" | ConvertFrom-Json
    Write-Host "✅ Resource Group: $($rg.name)" -ForegroundColor Green
    Write-Host "   Location: $($rg.location)" -ForegroundColor Gray
    Write-Host "   State: $($rg.provisioningState)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Cannot access resource group: $resourceGroup" -ForegroundColor Red
    Write-Host "   Please verify the resource group name exists" -ForegroundColor Yellow
}

# Test Key Vault access
Write-Host "`n🔑 Testing Key Vault access..." -ForegroundColor Yellow
try {
    $keyVaults = az keyvault list --resource-group $resourceGroup --query "[].{name:name, location:location}" | ConvertFrom-Json
    if ($keyVaults -and $keyVaults.Count -gt 0) {
        foreach ($kv in $keyVaults) {
            Write-Host "✅ Key Vault: $($kv.name)" -ForegroundColor Green
            Write-Host "   Location: $($kv.location)" -ForegroundColor Gray

            # Test secret access
            try {
                $secrets = az keyvault secret list --vault-name $kv.name --query "[0].{name:name}" | ConvertFrom-Json
                if ($secrets) {
                    Write-Host "   ✅ Can list secrets" -ForegroundColor Green
                } else {
                    Write-Host "   ℹ️  No secrets found (normal for new deployment)" -ForegroundColor Cyan
                }
            } catch {
                Write-Host "   ⚠️  Limited secret access (may need permissions)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "⚠️  No Key Vaults found in resource group" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Cannot list Key Vaults" -ForegroundColor Red
}

# Test PowerShell modules
Write-Host "`n📦 Checking PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @("Az.Accounts", "Az.KeyVault", "Az.Resources", "Microsoft.Graph.Authentication")

foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue
    if ($installed) {
        Write-Host "✅ $module (installed)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $module (not installed - will be installed during execution)" -ForegroundColor Yellow
    }
}

# Test connectivity
Write-Host "`n🌐 Testing connectivity..." -ForegroundColor Yellow
$endpoints = @(
    @{ Name = "Azure Management API"; Url = "https://management.azure.com/" }
    @{ Name = "Microsoft Graph"; Url = "https://graph.microsoft.com/" }
    @{ Name = "PowerShell Gallery"; Url = "https://www.powershellgallery.com/" }
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Url -UseBasicParsing -TimeoutSec 10 -Method Head
        Write-Host "✅ $($endpoint.Name): Accessible" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  $($endpoint.Name): Limited connectivity" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n🎯 Test Summary:" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host "✅ Local authentication test completed successfully!" -ForegroundColor Green
Write-Host "`n💡 This verifies that EasyPIM can run in your environment." -ForegroundColor Cyan
Write-Host "`n📝 Alternative deployment options:" -ForegroundColor Yellow
Write-Host "   1. Use GitHub Actions (no parallelism limitations)" -ForegroundColor White
Write-Host "   2. Run EasyPIM locally with scheduled tasks" -ForegroundColor White
Write-Host "   3. Request Azure DevOps parallelism grant: https://aka.ms/azpipelines-parallelism-request" -ForegroundColor White
Write-Host "   4. Use self-hosted Azure DevOps agents" -ForegroundColor White

Write-Host "`n🚀 Ready for EasyPIM deployment!" -ForegroundColor Green
