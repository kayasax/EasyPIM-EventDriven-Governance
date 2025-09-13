#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault

<#
.SYNOPSIS
    Deploy Azure infrastructure for EasyPIM CI/CD integration

.DESCRIPTION
    This script deploys the Azure infrastructure required for EasyPIM Event-Driven Governance,
    including Key Vault, RBAC assignments, and initial configuration.

.PARAMETER ResourceGroupName
    Name of the Azure resource group (will be created if it doesn't exist)

.PARAMETER Location
    Azure region for resource deployment

.PARAMETER ParametersFile
    Path to the parameters file (defaults to deploy-azure-resources.parameters.json)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current context if not specified)

.PARAMETER WhatIf
    Show what would be deployed without actually deploying

.EXAMPLE
    .\deploy-azure-resources.ps1 -ResourceGroupName "rg-easypim-prod" -Location "East US"
    
.EXAMPLE
    .\deploy-azure-resources.ps1 -ResourceGroupName "rg-easypim-prod" -Location "East US" -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "./deploy-azure-resources.parameters.json",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Import required modules
Write-Host "📦 Checking required PowerShell modules..." -ForegroundColor Yellow

$requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.KeyVault')
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
    Import-Module -Name $module -Force
}

Write-Host "✅ PowerShell modules ready!" -ForegroundColor Green

# Authenticate to Azure
Write-Host "🔐 Checking Azure authentication..." -ForegroundColor Yellow
$context = Get-AzContext

if (!$context) {
    Write-Host "Please sign in to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
    $context = Get-AzContext
}

if ($SubscriptionId) {
    Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $SubscriptionId
    $context = Get-AzContext
}

Write-Host "✅ Authenticated as: $($context.Account.Id)" -ForegroundColor Green
Write-Host "📋 Subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
Write-Host "🏢 Tenant: $($context.Tenant.Id)" -ForegroundColor Cyan

# Check if parameters file exists
if (!(Test-Path $ParametersFile)) {
    Write-Error "Parameters file not found: $ParametersFile"
    Write-Host "Please create the parameters file or specify a different path." -ForegroundColor Red
    exit 1
}

# Create or verify resource group
Write-Host "🏗️ Checking resource group: $ResourceGroupName" -ForegroundColor Yellow
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (!$resourceGroup) {
    if ($WhatIf) {
        Write-Host "Would create resource group: $ResourceGroupName in $Location" -ForegroundColor Cyan
    } else {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "✅ Resource group created!" -ForegroundColor Green
    }
} else {
    Write-Host "✅ Resource group exists: $($resourceGroup.Location)" -ForegroundColor Green
}

# Deploy Bicep template
Write-Host "🚀 Starting Azure deployment..." -ForegroundColor Yellow
Write-Host "📁 Template: deploy-azure-resources.bicep" -ForegroundColor Cyan
Write-Host "📄 Parameters: $ParametersFile" -ForegroundColor Cyan

try {
    $deploymentParams = @{
        ResourceGroupName     = $ResourceGroupName
        TemplateFile         = "./deploy-azure-resources.bicep"
        TemplateParameterFile = $ParametersFile
        Name                 = "EasyPIM-Deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Verbose              = $true
    }

    if ($WhatIf) {
        Write-Host "🔍 WHAT-IF MODE - Showing what would be deployed:" -ForegroundColor Magenta
        $result = New-AzResourceGroupDeployment @deploymentParams -WhatIf
        Write-Host "✅ What-if analysis completed" -ForegroundColor Green
    } else {
        Write-Host "🔄 Deploying infrastructure..." -ForegroundColor Yellow
        $deployment = New-AzResourceGroupDeployment @deploymentParams
        
        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
            
            # Display outputs
            Write-Host "`n📋 Deployment Outputs:" -ForegroundColor Cyan
            $deployment.Outputs.GetEnumerator() | ForEach-Object {
                Write-Host "  $($_.Key): $($_.Value.Value)" -ForegroundColor White
            }
            
            Write-Host "`n🔧 Next Steps:" -ForegroundColor Yellow
            Write-Host "1. Create Azure AD Application and Service Principal" -ForegroundColor White
            Write-Host "2. Set up OIDC federation for GitHub Actions" -ForegroundColor White
            Write-Host "3. Grant required Microsoft Graph permissions" -ForegroundColor White
            Write-Host "4. Configure GitHub repository secrets" -ForegroundColor White
            Write-Host "5. Update pipeline variables with Key Vault name" -ForegroundColor White
            
        } else {
            Write-Error "Deployment failed with state: $($deployment.ProvisioningState)"
        }
    }
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    Write-Host "Check Azure portal for detailed error information." -ForegroundColor Red
}

Write-Host "`n✅ Script execution completed!" -ForegroundColor Green
