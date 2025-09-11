# Test Updated Pipeline Execution Locally
# This script tests the exact same steps the updated pipeline performs

param(
    [string]$KeyVaultName = "easypim-kv-mc-dev-02",
    [string]$SecretName = "EasyPIMConfig",
    [bool]$WhatIf = $true,
    [string]$Mode = "delta"
)

Write-Host "🧪 Testing UPDATED Pipeline Steps Locally..." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "⏰ Test started at: $(Get-Date)" -ForegroundColor Gray
Write-Host "📋 Using KeyVault: $KeyVaultName" -ForegroundColor Cyan
Write-Host "📋 Using Secret: $SecretName" -ForegroundColor Cyan
Write-Host "📋 WhatIf Mode: $WhatIf" -ForegroundColor Cyan
Write-Host "📋 Execution Mode: $Mode" -ForegroundColor Cyan

# Step 1: Check if we're authenticated to Azure
Write-Host "`n🔐 Step 1: Checking Azure authentication..." -ForegroundColor Cyan
try {
    $context = Get-AzContext
    if ($context) {
        Write-Host "✅ Azure PowerShell authenticated as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "     Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
        Write-Host "     Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
    } else {
        Write-Host "❌ No Azure PowerShell context found" -ForegroundColor Red
        Write-Host "💡 Please run: Connect-AzAccount" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Azure authentication check failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Install/Check EasyPIM modules
Write-Host "`n📦 Step 2: Checking EasyPIM modules..." -ForegroundColor Cyan

$easyPIM = Get-Module -ListAvailable -Name EasyPIM.Orchestrator
$graphAuth = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication

if (-not $easyPIM) {
    Write-Host "⬇️ Installing EasyPIM.Orchestrator..." -ForegroundColor Yellow
    Install-Module -Name EasyPIM.Orchestrator -Force -Scope CurrentUser -AllowClobber
    $easyPIM = Get-Module -ListAvailable -Name EasyPIM.Orchestrator
}

if (-not $graphAuth) {
    Write-Host "⬇️ Installing Microsoft.Graph.Authentication..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.Graph.Authentication -Force -Scope CurrentUser -AllowClobber
    $graphAuth = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication
}

if ($easyPIM) {
    Write-Host "✅ EasyPIM.Orchestrator found: v$($easyPIM.Version)" -ForegroundColor Green
} else {
    Write-Host "❌ EasyPIM.Orchestrator not found" -ForegroundColor Red
    exit 1
}

if ($graphAuth) {
    Write-Host "✅ Microsoft.Graph.Authentication found: v$($graphAuth.Version)" -ForegroundColor Green
} else {
    Write-Host "❌ Microsoft.Graph.Authentication not found" -ForegroundColor Red
    exit 1
}

# Step 3: Import modules
Write-Host "`n📦 Step 3: Importing modules..." -ForegroundColor Cyan
try {
    Write-Host "   🔄 Importing EasyPIM.Orchestrator..." -ForegroundColor Gray
    Import-Module EasyPIM.Orchestrator -Force
    Write-Host "   ✅ EasyPIM.Orchestrator imported" -ForegroundColor Green
    
    Write-Host "   🔄 Importing Microsoft.Graph.Authentication..." -ForegroundColor Gray
    Import-Module Microsoft.Graph.Authentication -Force
    Write-Host "   ✅ Microsoft.Graph.Authentication imported" -ForegroundColor Green
} catch {
    Write-Host "❌ Module import failed: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Verify commands
Write-Host "`n🔍 Step 4: Verifying EasyPIM commands..." -ForegroundColor Cyan
$easyPIMCommand = Get-Command -Name "Invoke-EasyPIMOrchestrator" -ErrorAction SilentlyContinue
if ($easyPIMCommand) {
    Write-Host "✅ Invoke-EasyPIMOrchestrator command found" -ForegroundColor Green
    Write-Host "   Module: $($easyPIMCommand.ModuleName)" -ForegroundColor Gray
    Write-Host "   Version: $($easyPIMCommand.Version)" -ForegroundColor Gray
} else {
    Write-Host "❌ Invoke-EasyPIMOrchestrator command not found" -ForegroundColor Red
    Write-Host "🔍 Available EasyPIM commands:" -ForegroundColor Yellow
    Get-Command -Module EasyPIM.Orchestrator | ForEach-Object { Write-Host "   - $($_.Name)" -ForegroundColor Gray }
    exit 1
}

# Step 5: Test Key Vault access
Write-Host "`n🔑 Step 5: Testing Key Vault access..." -ForegroundColor Cyan
try {
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
    Write-Host "✅ Key Vault found: $($keyVault.VaultName)" -ForegroundColor Green
    
    $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText -ErrorAction Stop
    if ($secret) {
        Write-Host "✅ Configuration secret accessible (length: $($secret.Length) chars)" -ForegroundColor Green
    } else {
        throw "Secret is null or empty"
    }
} catch {
    Write-Host "❌ Key Vault access failed: $_" -ForegroundColor Red
    Write-Host "💡 Make sure your Azure account has Key Vault access" -ForegroundColor Yellow
    exit 1
}

# Step 6: Test Microsoft Graph authentication
Write-Host "`n🔐 Step 6: Testing Microsoft Graph authentication..." -ForegroundColor Cyan
try {
    # Try Azure CLI method first
    Write-Host "   🔄 Getting Graph token via Azure CLI..." -ForegroundColor Gray
    $graphToken = az account get-access-token --resource https://graph.microsoft.com --query "accessToken" -o tsv
    
    if ($graphToken) {
        Write-Host "   ✅ Microsoft Graph token acquired via Azure CLI" -ForegroundColor Green
        
        $secureToken = ConvertTo-SecureString $graphToken -AsPlainText -Force
        Connect-MgGraph -AccessToken $secureToken -NoWelcome
        
        $mgContext = Get-MgContext
        if ($mgContext) {
            Write-Host "   ✅ Microsoft Graph authenticated successfully" -ForegroundColor Green
            Write-Host "      Account: $($mgContext.Account)" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️ Microsoft Graph context is null" -ForegroundColor Yellow
        }
    } else {
        throw "Failed to get Graph access token"
    }
} catch {
    Write-Host "   ⚠️ Microsoft Graph authentication failed: $_" -ForegroundColor Yellow
    Write-Host "   💡 EasyPIM module may handle Graph auth internally" -ForegroundColor Yellow
}

# Step 7: Execute EasyPIM (simulation)
Write-Host "`n🚀 Step 7: Testing EasyPIM execution..." -ForegroundColor Cyan
Write-Host "   Command would be: Invoke-EasyPIMOrchestrator -KeyVaultName '$KeyVaultName' -SecretName '$SecretName' -WhatIf:`$$WhatIf -Mode '$Mode' -Verbose" -ForegroundColor Gray

if ($WhatIf) {
    Write-Host "`n🎯 SIMULATION MODE: Would execute EasyPIM with parameters:" -ForegroundColor Yellow
    Write-Host "   KeyVaultName: $KeyVaultName" -ForegroundColor Gray
    Write-Host "   SecretName: $SecretName" -ForegroundColor Gray
    Write-Host "   WhatIf: $WhatIf" -ForegroundColor Gray
    Write-Host "   Mode: $Mode" -ForegroundColor Gray
    Write-Host "`n💡 To actually run EasyPIM, use: .\test-pipeline-execution.ps1 -WhatIf `$false" -ForegroundColor Cyan
} else {
    Write-Host "`n🚀 EXECUTING EasyPIM for real..." -ForegroundColor Red
    try {
        Invoke-EasyPIMOrchestrator -KeyVaultName $KeyVaultName -SecretName $SecretName -WhatIf:$WhatIf -Mode $Mode -Verbose
        Write-Host "✅ EasyPIM execution completed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "❌ EasyPIM execution failed: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n✅ All pipeline simulation steps completed successfully!" -ForegroundColor Green
Write-Host "⏰ Test completed at: $(Get-Date)" -ForegroundColor Gray
Write-Host "`n💡 If this works locally but fails in pipeline, the issue is authentication context in Azure DevOps." -ForegroundColor Cyan
