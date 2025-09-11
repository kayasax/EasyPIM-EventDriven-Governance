# 🚀 EasyPIM Orchestrator Execution Script
# This script runs in Azure DevOps with the AzurePowerShell@5 task

param(
    [string]$KeyVaultName,
    [string]$SecretName,
    [bool]$WhatIf = $true,
    [string]$Mode = "delta"
)

# Enable verbose output and error handling
$VerbosePreference = "Continue"
$ErrorActionPreference = "Continue"

Write-Host "🚀 Starting EasyPIM Policy Orchestrator execution..." -ForegroundColor Green
Write-Host "⏰ Execution started at: $(Get-Date)" -ForegroundColor Gray

# Import required modules with detailed logging
Write-Host "📦 Importing required modules..." -ForegroundColor Cyan
try {
    Write-Host "   🔄 Importing EasyPIM.Orchestrator..." -ForegroundColor Gray
    Import-Module EasyPIM.Orchestrator -Force -Verbose
    Write-Host "   ✅ EasyPIM.Orchestrator imported successfully" -ForegroundColor Green
    
    Write-Host "   🔄 Importing Microsoft.Graph.Authentication..." -ForegroundColor Gray
    Import-Module Microsoft.Graph.Authentication -Force -Verbose
    Write-Host "   ✅ Microsoft.Graph.Authentication imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Module import failed: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    throw $_
}

# Verify Azure PowerShell context
Write-Host "🔐 Verifying Azure PowerShell context..." -ForegroundColor Cyan
try {
    $context = Get-AzContext
    if ($context) {
        Write-Host "✅ Azure PowerShell authenticated as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "     Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Gray
        Write-Host "     Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
    } else {
        throw "No Azure PowerShell context found"
    }
} catch {
    Write-Host "❌ Azure PowerShell context verification failed: $_" -ForegroundColor Red
    throw $_
}

# Authenticate to Microsoft Graph
Write-Host "🔐 Authenticating to Microsoft Graph..." -ForegroundColor Cyan
try {
    # Method 1: Try using Azure CLI method (which we know works)
    Write-Host "   🔄 Getting Graph token via Azure CLI..." -ForegroundColor Gray
    
    # Use Azure CLI to get Graph token (this works with our service principal)
    $graphToken = az account get-access-token --resource https://graph.microsoft.com --query "accessToken" -o tsv
    
    if ($graphToken) {
        Write-Host "   ✅ Microsoft Graph token acquired via Azure CLI" -ForegroundColor Green
        
        # Connect to Microsoft Graph using the token
        $secureToken = ConvertTo-SecureString $graphToken -AsPlainText -Force
        Connect-MgGraph -AccessToken $secureToken -NoWelcome
        
        $mgContext = Get-MgContext
        if ($mgContext) {
            Write-Host "   ✅ Microsoft Graph authenticated successfully" -ForegroundColor Green
            Write-Host "      Account: $($mgContext.Account)" -ForegroundColor Gray
            Write-Host "      Scopes: $($mgContext.Scopes -join ', ')" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️ Microsoft Graph context is null after connection" -ForegroundColor Yellow
        }
    } else {
        throw "Failed to get Graph access token via Azure CLI"
    }
} catch {
    Write-Host "   ⚠️ Azure CLI Graph authentication failed: $_" -ForegroundColor Yellow
    
    # Method 2: Fallback to direct authentication
    Write-Host "   🔄 Trying direct Microsoft Graph authentication..." -ForegroundColor Cyan
    try {
        Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory" -NoWelcome
        
        $mgContext = Get-MgContext
        if ($mgContext) {
            Write-Host "   ✅ Microsoft Graph authenticated via direct connection" -ForegroundColor Green
            Write-Host "      Account: $($mgContext.Account)" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️ Microsoft Graph direct connection succeeded but context is null" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ Microsoft Graph authentication failed: $_" -ForegroundColor Red
        Write-Host "   💡 Continuing anyway - EasyPIM module may handle Graph auth internally" -ForegroundColor Yellow
        # Don't throw here - let EasyPIM module try to authenticate itself
    }
}

Write-Host "📋 Executing with parameters:" -ForegroundColor Cyan
Write-Host "   KeyVaultName: $KeyVaultName" -ForegroundColor Gray
Write-Host "   SecretName: $SecretName" -ForegroundColor Gray
Write-Host "   WhatIf: $WhatIf" -ForegroundColor Gray
Write-Host "   Mode: $Mode" -ForegroundColor Gray

# Execute EasyPIM Orchestrator with enhanced error handling
Write-Host "🎯 Starting EasyPIM Orchestrator execution..." -ForegroundColor Green
try {
    Write-Host "🎯 Converted parameters:" -ForegroundColor Cyan
    Write-Host "   WhatIf parameter: $WhatIf" -ForegroundColor Gray
    Write-Host "   Mode parameter: '$Mode'" -ForegroundColor Gray
    
    # Verify EasyPIM module commands are available
    Write-Host "🔍 Verifying EasyPIM commands..." -ForegroundColor Cyan
    $easyPIMCommand = Get-Command -Name "Invoke-EasyPIMOrchestrator" -ErrorAction SilentlyContinue
    if ($easyPIMCommand) {
        Write-Host "   ✅ Invoke-EasyPIMOrchestrator command found" -ForegroundColor Green
        Write-Host "      Module: $($easyPIMCommand.ModuleName)" -ForegroundColor Gray
        Write-Host "      Version: $($easyPIMCommand.Version)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Invoke-EasyPIMOrchestrator command not found" -ForegroundColor Red
        Write-Host "   🔍 Available EasyPIM commands:" -ForegroundColor Yellow
        Get-Command -Module EasyPIM.Orchestrator | ForEach-Object { Write-Host "      - $($_.Name)" -ForegroundColor Gray }
        throw "EasyPIM Orchestrator command not available"
    }
    
    # Execute EasyPIM with verbose output
    Write-Host "🚀 Executing Invoke-EasyPIMOrchestrator..." -ForegroundColor Green
    Write-Host "   Command: Invoke-EasyPIMOrchestrator -KeyVaultName '$KeyVaultName' -SecretName '$SecretName' -WhatIf:`$$WhatIf -Mode '$Mode' -Verbose" -ForegroundColor Gray
    
    Invoke-EasyPIMOrchestrator -KeyVaultName $KeyVaultName -SecretName $SecretName -WhatIf:$WhatIf -Mode $Mode -Verbose

    Write-Host "✅ EasyPIM execution completed successfully!" -ForegroundColor Green
    Write-Host "⏰ Execution completed at: $(Get-Date)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Error during EasyPIM execution: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Additional debugging information
    Write-Host "🔍 Debugging information:" -ForegroundColor Yellow
    Write-Host "   PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "   Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Gray
    Write-Host "   Current Location: $(Get-Location)" -ForegroundColor Gray
    
    throw $_
}
