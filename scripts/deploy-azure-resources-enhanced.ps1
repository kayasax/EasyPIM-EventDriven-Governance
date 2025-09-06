# Deploy Azure Resources for EasyPIM Event-Driven Governance
# Enhanced deployment script that supports both GitHub Actions and Azure DevOps platforms

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("GitHub", "AzureDevOps", "Both")]
    [string]$TargetPlatform = "GitHub",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd-test",

    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",

    [Parameter(Mandatory = $false)]
    [string]$AppName,

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [string]$ConfigurationFile = "scripts\deploy-azure-resources.parameters.json",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Display help and usage
function Show-Usage {
    Write-Host @"
🚀 EasyPIM Event-Driven Governance - Azure Resources Deployment
==============================================================

This script deploys Azure resources for EasyPIM Event-Driven Governance
with support for multiple CI/CD platforms.

USAGE:
  .\deploy-azure-resources-enhanced.ps1 [options]

PARAMETERS:
  -TargetPlatform        CI/CD platform to optimize for (default: GitHub)
                         Options: GitHub, AzureDevOps, Both

  -ResourceGroupName     Azure resource group name (default: rg-easypim-cicd-test)

  -Location              Azure region for deployment (default: East US)

  -AppName               Application name prefix (auto-generated if not provided)

  -KeyVaultName          Key Vault name (auto-generated if not provided)

  -ConfigurationFile     Path to parameters file (default: scripts\deploy-azure-resources.parameters.json)

  -WhatIf                Preview deployment without making changes

  -Force                 Skip confirmation prompts

EXAMPLES:
  # Deploy for GitHub Actions (default)
  .\deploy-azure-resources-enhanced.ps1

  # Deploy for Azure DevOps with custom names
  .\deploy-azure-resources-enhanced.ps1 -TargetPlatform AzureDevOps -AppName "contoso-easypim" -Location "West Europe"

  # Deploy for both platforms with preview
  .\deploy-azure-resources-enhanced.ps1 -TargetPlatform Both -WhatIf

  # Force deployment without prompts
  .\deploy-azure-resources-enhanced.ps1 -TargetPlatform Both -Force

PREREQUISITES:
  • Azure CLI authenticated (az login)
  • Appropriate Azure subscription permissions
  • Bicep CLI (included with Azure CLI)

"@ -ForegroundColor Cyan
}

# Prerequisites check
function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan
    $allGood = $true

    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "❌ Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        $allGood = $false
    } else {
        # Check Azure CLI authentication
        try {
            $azAccount = az account show --query "{id: id, tenantId: tenantId, name: name}" | ConvertFrom-Json
            if (-not $azAccount) {
                Write-Error "❌ Azure CLI is not authenticated. Please run: az login"
                $allGood = $false
            } else {
                Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
                Write-Host "   Account: $($azAccount.name)" -ForegroundColor Gray
                Write-Host "   Subscription: $($azAccount.id)" -ForegroundColor Gray
                Write-Host "   Tenant: $($azAccount.tenantId)" -ForegroundColor Gray
            }
        }
        catch {
            Write-Error "❌ Azure CLI authentication check failed: $_"
            $allGood = $false
        }
    }

    # Check Bicep
    try {
        $bicepVersion = az bicep version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Bicep CLI available" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Bicep CLI not found. Installing..." -ForegroundColor Yellow
            az bicep install
            Write-Host "✅ Bicep CLI installed" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️  Could not verify Bicep CLI. It will be installed during deployment if needed." -ForegroundColor Yellow
    }

    # Check if configuration file exists
    if (-not (Test-Path $ConfigurationFile)) {
        Write-Error "❌ Configuration file not found: $ConfigurationFile"
        $allGood = $false
    } else {
        Write-Host "✅ Configuration file found: $ConfigurationFile" -ForegroundColor Green
    }

    # Check if Bicep template exists
    $bicepFile = "scripts\deploy-azure-resources.bicep"
    if (-not (Test-Path $bicepFile)) {
        Write-Error "❌ Bicep template not found: $bicepFile"
        $allGood = $false
    } else {
        Write-Host "✅ Bicep template found: $bicepFile" -ForegroundColor Green
    }

    return $allGood
}

# Generate platform-specific resource names
function Get-PlatformResourceNames {
    param(
        [string]$Platform,
        [string]$BaseAppName,
        [string]$BaseKeyVaultName
    )

    $timestamp = Get-Date -Format "MMdd"
    $suffix = switch ($Platform) {
        "GitHub" { "gh" }
        "AzureDevOps" { "ado" }
        "Both" { "multi" }
        default { "gh" }
    }

    if (-not $BaseAppName) {
        $BaseAppName = "easypim-$suffix-$timestamp"
    }

    if (-not $BaseKeyVaultName) {
        # Key Vault names have restrictions (3-24 chars, alphanumeric and hyphens)
        $BaseKeyVaultName = "kv-easypim-$suffix-$timestamp"
        if ($BaseKeyVaultName.Length -gt 24) {
            $BaseKeyVaultName = "kv-pim-$suffix-$timestamp"
        }
    }

    return @{
        AppName = $BaseAppName
        KeyVaultName = $BaseKeyVaultName
        FunctionAppName = "func-$BaseAppName"
        StorageAccountName = "st$($BaseAppName.Replace('-', ''))$timestamp"
        ApplicationInsightsName = "ai-$BaseAppName"
        ServicePrincipalName = "sp-$BaseAppName"
    }
}

# Update parameters file with platform-specific values
function Update-ParametersFile {
    param(
        [string]$FilePath,
        [hashtable]$ResourceNames,
        [string]$Platform,
        [string]$Location
    )

    Write-Host "📝 Updating parameters file for platform: $Platform" -ForegroundColor Cyan

    try {
        $parameters = Get-Content $FilePath | ConvertFrom-Json

        # Update resource names
        $parameters.parameters.appName.value = $ResourceNames.AppName
        $parameters.parameters.keyVaultName.value = $ResourceNames.KeyVaultName
        $parameters.parameters.location.value = $Location

        # Add platform-specific tags
        if (-not $parameters.parameters.PSObject.Properties["tags"]) {
            $parameters.parameters | Add-Member -MemberType NoteProperty -Name "tags" -Value @{
                value = @{}
            }
        }

        $parameters.parameters.tags.value["Platform"] = $Platform
        $parameters.parameters.tags.value["Project"] = "EasyPIM-EventDriven-Governance"
        $parameters.parameters.tags.value["Environment"] = "test"
        $parameters.parameters.tags.value["DeployedAt"] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")

        # Create a backup of the original file
        $backupFile = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $FilePath $backupFile
        Write-Host "   📋 Backup created: $backupFile" -ForegroundColor Gray

        # Save updated parameters
        $parameters | ConvertTo-Json -Depth 10 | Set-Content $FilePath
        Write-Host "   ✅ Parameters file updated" -ForegroundColor Green

        return @{
            OriginalFile = $FilePath
            BackupFile = $backupFile
            UpdatedParameters = $parameters
        }
    }
    catch {
        Write-Error "❌ Failed to update parameters file: $_"
        return $null
    }
}

# Deploy Azure resources
function Deploy-AzureResources {
    param(
        [string]$ResourceGroupName,
        [string]$Location,
        [string]$BicepFile,
        [string]$ParametersFile,
        [hashtable]$ResourceNames,
        [bool]$WhatIf
    )

    Write-Host "🚀 Deploying Azure resources..." -ForegroundColor Cyan

    try {
        # Create resource group if it doesn't exist
        $existingRg = az group show --name $ResourceGroupName 2>$null | ConvertFrom-Json
        if (-not $existingRg) {
            Write-Host "   📋 Creating resource group: $ResourceGroupName" -ForegroundColor Gray
            if (-not $WhatIf) {
                az group create --name $ResourceGroupName --location $Location
                Write-Host "   ✅ Resource group created" -ForegroundColor Green
            } else {
                Write-Host "   📋 [WHAT-IF] Would create resource group: $ResourceGroupName" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ✅ Resource group exists: $ResourceGroupName" -ForegroundColor Green
        }

        # Prepare deployment command
        $deploymentName = "easypim-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        $deployCmd = @(
            "az", "deployment", "group", "create"
            "--resource-group", $ResourceGroupName
            "--name", $deploymentName
            "--template-file", $BicepFile
            "--parameters", "@$ParametersFile"
        )

        if ($WhatIf) {
            $deployCmd += "--what-if"
        }

        Write-Host "   🔧 Deployment name: $deploymentName" -ForegroundColor Gray
        Write-Host "   📋 Template: $BicepFile" -ForegroundColor Gray
        Write-Host "   📋 Parameters: $ParametersFile" -ForegroundColor Gray

        if ($WhatIf) {
            Write-Host "   📋 [WHAT-IF MODE] Previewing changes..." -ForegroundColor Yellow
        } else {
            Write-Host "   🚀 Starting deployment..." -ForegroundColor Green
        }

        # Execute deployment
        $deploymentResult = & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)] | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            if ($WhatIf) {
                Write-Host "   ✅ What-if analysis completed successfully" -ForegroundColor Green
            } else {
                Write-Host "   ✅ Deployment completed successfully" -ForegroundColor Green
                Write-Host "   📋 Deployment ID: $($deploymentResult.id)" -ForegroundColor Gray
            }
            return $deploymentResult
        } else {
            throw "Deployment failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "❌ Deployment failed: $_"
        return $null
    }
}

# Main script execution
Write-Host @"
🚀 EasyPIM Event-Driven Governance - Azure Resources Deployment
===============================================================
Target Platform: $TargetPlatform
Resource Group: $ResourceGroupName
Location: $Location
What-If Mode: $($WhatIf.IsPresent)

"@ -ForegroundColor Magenta

# Show usage if help requested
if ($Help -or $args -contains "-h" -or $args -contains "--help" -or $args -contains "-?") {
    Show-Usage
    exit 0
}

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Host "`n💡 Run with -h for usage information" -ForegroundColor Cyan
    exit 1
}

# Generate resource names
$resourceNames = Get-PlatformResourceNames -Platform $TargetPlatform -BaseAppName $AppName -BaseKeyVaultName $KeyVaultName

Write-Host "`n📋 Generated Resource Names:" -ForegroundColor Yellow
Write-Host "• App Name: $($resourceNames.AppName)" -ForegroundColor White
Write-Host "• Key Vault: $($resourceNames.KeyVaultName)" -ForegroundColor White
Write-Host "• Function App: $($resourceNames.FunctionAppName)" -ForegroundColor White
Write-Host "• Storage Account: $($resourceNames.StorageAccountName)" -ForegroundColor White
Write-Host "• Application Insights: $($resourceNames.ApplicationInsightsName)" -ForegroundColor White
Write-Host "• Service Principal: $($resourceNames.ServicePrincipalName)" -ForegroundColor White

# Confirm before proceeding
if (-not $Force -and -not $WhatIf) {
    Write-Host "`n⚠️  This will deploy Azure resources to subscription and resource group:" -ForegroundColor Yellow
    $azAccount = az account show --query "{id: id, name: name}" | ConvertFrom-Json
    Write-Host "   Subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor White
    Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "   Location: $Location" -ForegroundColor White
    $confirm = Read-Host "Do you want to continue? (y/N)"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
        exit 0
    }
}

# Update parameters file
$parameterUpdate = Update-ParametersFile -FilePath $ConfigurationFile -ResourceNames $resourceNames -Platform $TargetPlatform -Location $Location
if (-not $parameterUpdate) {
    exit 1
}

# Deploy resources
$deploymentResult = Deploy-AzureResources -ResourceGroupName $ResourceGroupName -Location $Location -BicepFile "scripts\deploy-azure-resources.bicep" -ParametersFile $ConfigurationFile -ResourceNames $resourceNames -WhatIf $WhatIf.IsPresent

if ($deploymentResult) {
    if ($WhatIf) {
        Write-Host "`n🎉 What-if analysis completed!" -ForegroundColor Green
        Write-Host @"

📋 What-If Summary:
The deployment would create/update resources for $TargetPlatform platform.
No actual changes were made to Azure resources.

To deploy for real, run the same command without -WhatIf parameter.

"@ -ForegroundColor Cyan
    } else {
        Write-Host "`n🎉 Deployment completed!" -ForegroundColor Green
        Write-Host @"

✅ Next Steps:
1. Configure CI/CD platform secrets and variables:
   .\scripts\configure-cicd.ps1 -Platform $TargetPlatform [additional parameters]

2. Test the deployment by triggering workflows

3. Review the integration guide:
   docs/Azure-DevOps-Integration-Plan.md

📋 Deployed Resources:
• Resource Group: $ResourceGroupName
• App Name: $($resourceNames.AppName)
• Key Vault: $($resourceNames.KeyVaultName)
• Function App: $($resourceNames.FunctionAppName)

🔗 Azure Portal: https://portal.azure.com/#@/resource/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroupName

"@ -ForegroundColor Green
    }

    # Restore original parameters file
    if ($parameterUpdate.BackupFile) {
        Write-Host "🔄 Restoring original parameters file..." -ForegroundColor Cyan
        Copy-Item $parameterUpdate.BackupFile $parameterUpdate.OriginalFile
        Remove-Item $parameterUpdate.BackupFile
        Write-Host "✅ Original parameters file restored" -ForegroundColor Green
    }
} else {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    exit 1
}
