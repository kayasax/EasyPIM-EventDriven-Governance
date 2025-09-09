# Deploy Azure Resources for EasyPIM Event-Driven Governance
# Enhanced deployment script that supports both GitHub Actions and Azure DevOps platforms

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("GitHub", "AzureDevOps", "Both")]
    [string]$TargetPlatform = "GitHub",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd",

    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",

    [Parameter(Mandatory = $false)]
    [string]$AppName,

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [string]$ConfigurationFile = "templates\deploy-azure-resources-working.parameters.json",

    [Parameter(Mandatory = $false)]
    [string]$BicepTemplate = "templates\deploy-azure-resources-working.bicep",

    [Parameter(Mandatory = $false)]
    [string]$GitHubRepository,

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
    $bicepFile = $BicepTemplate
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

# Check for existing resources and suggest reuse
function Test-ExistingResources {
    param(
        [string]$ResourceGroupName,
        [hashtable]$ProposedNames,
        [string]$Platform
    )

    Write-Host "🔍 Checking for existing resources..." -ForegroundColor Cyan
    $existingResources = @{}
    $conflicts = @()
    
    try {
        # Check if resource group exists
        $rgExists = az group show --name $ResourceGroupName --query "name" -o tsv 2>$null
        if ($rgExists) {
            Write-Host "   ✅ Resource group '$ResourceGroupName' exists" -ForegroundColor Green
            
            # Check for Key Vault with similar naming pattern
            $kvPattern = "*easypim*kv*"
            $existingKvs = az keyvault list --resource-group $ResourceGroupName --query "[?contains(name, 'easypim') && contains(name, 'kv')].{name:name,id:id}" -o json 2>$null
            if ($existingKvs -and $existingKvs -ne "[]") {
                $kvs = $existingKvs | ConvertFrom-Json
                foreach ($kv in $kvs) {
                    Write-Host "   🔑 Found existing Key Vault: $($kv.name)" -ForegroundColor Yellow
                    $existingResources["KeyVault"] = @{
                        Name = $kv.name
                        Id = $kv.id
                        Type = "Microsoft.KeyVault/vaults"
                    }
                }
            }
            
            # Check for Storage Accounts with similar naming pattern
            $storagePattern = "*easypim*"
            $existingStorage = az storage account list --resource-group $ResourceGroupName --query "[?contains(name, 'easypim')].{name:name,id:id,location:primaryLocation}" -o json 2>$null
            if ($existingStorage -and $existingStorage -ne "[]") {
                $storageAccounts = $existingStorage | ConvertFrom-Json
                foreach ($sa in $storageAccounts) {
                    Write-Host "   💾 Found existing Storage Account: $($sa.name)" -ForegroundColor Yellow
                    $existingResources["StorageAccount"] = @{
                        Name = $sa.name
                        Id = $sa.id
                        Location = $sa.location
                        Type = "Microsoft.Storage/storageAccounts"
                    }
                }
            }
            
            # Check for Function Apps with similar naming pattern
            $funcPattern = "*easypim*"
            $existingFuncs = az functionapp list --resource-group $ResourceGroupName --query "[?contains(name, 'easypim')].{name:name,id:id,location:location}" -o json 2>$null
            if ($existingFuncs -and $existingFuncs -ne "[]") {
                $functions = $existingFuncs | ConvertFrom-Json
                foreach ($func in $functions) {
                    Write-Host "   ⚡ Found existing Function App: $($func.name)" -ForegroundColor Yellow
                    $existingResources["FunctionApp"] = @{
                        Name = $func.name
                        Id = $func.id
                        Location = $func.location
                        Type = "Microsoft.Web/sites"
                    }
                }
            }
        } else {
            Write-Host "   📋 Resource group '$ResourceGroupName' will be created" -ForegroundColor Gray
        }
        
        # Check for naming conflicts with proposed names
        foreach ($resourceType in $ProposedNames.Keys) {
            if ($resourceType -eq "GitHubRepository") { continue }
            
            $proposedName = $ProposedNames[$resourceType]
            switch ($resourceType) {
                "KeyVaultName" {
                    $existing = az keyvault show --name $proposedName --query "name" -o tsv 2>$null
                    if ($existing -and !$existingResources.ContainsKey("KeyVault")) {
                        $conflicts += "Key Vault '$proposedName' already exists in another resource group"
                    }
                }
                "StorageAccountName" {
                    $existing = az storage account check-name --name $proposedName --query "nameAvailable" -o tsv 2>$null
                    if ($existing -eq "false" -and !$existingResources.ContainsKey("StorageAccount")) {
                        $conflicts += "Storage Account '$proposedName' name is not available"
                    }
                }
                "FunctionAppName" {
                    $existing = az functionapp show --name $proposedName --resource-group $ResourceGroupName --query "name" -o tsv 2>$null
                    if ($existing -and !$existingResources.ContainsKey("FunctionApp")) {
                        $conflicts += "Function App '$proposedName' already exists"
                    }
                }
            }
        }
        
        return @{
            ExistingResources = $existingResources
            Conflicts = $conflicts
            CanReuse = $existingResources.Count -gt 0
        }
        
    } catch {
        Write-Host "   ⚠️ Could not fully check existing resources: $($_.Exception.Message)" -ForegroundColor Yellow
        return @{
            ExistingResources = @{}
            Conflicts = @()
            CanReuse = $false
        }
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
        $updated = $false

        # Update location if different
        if ($parameters.parameters.location.value -ne $Location) {
            $parameters.parameters.location.value = $Location
            Write-Host "   📍 Updated location to: $Location" -ForegroundColor Gray
            $updated = $true
        }

        # Update GitHub repository if provided and different
        if ($ResourceNames.ContainsKey("GitHubRepository") -and $parameters.parameters.githubRepository.value -ne $ResourceNames.GitHubRepository) {
            $parameters.parameters.githubRepository.value = $ResourceNames.GitHubRepository
            Write-Host "   📋 Updated GitHub repository to: $($ResourceNames.GitHubRepository)" -ForegroundColor Gray
            $updated = $true
        }

        # Update tags with platform and deployment information
        if ($parameters.parameters.tags -and $parameters.parameters.tags.value) {
            # Convert tags to hashtable for easier manipulation
            $tagsValue = $parameters.parameters.tags.value
            
            # Update platform-specific tags
            $tagsValue | Add-Member -MemberType NoteProperty -Name "Platform" -Value $Platform -Force
            $tagsValue | Add-Member -MemberType NoteProperty -Name "Project" -Value "EasyPIM-EventDriven-Governance" -Force
            $tagsValue | Add-Member -MemberType NoteProperty -Name "DeployedAt" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC") -Force
            
            if ($ResourceNames.ContainsKey("GitHubRepository")) {
                $tagsValue | Add-Member -MemberType NoteProperty -Name "Repository" -Value $ResourceNames.GitHubRepository -Force
            }
            
            Write-Host "   🏷️ Updated tags with platform: $Platform" -ForegroundColor Gray
            $updated = $true
        }

        # Create backup and save only if there were changes
        $backupFile = $null
        if ($updated) {
            $backupFile = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $FilePath $backupFile
            Write-Host "   📋 Backup created: $backupFile" -ForegroundColor Gray

            # Save updated parameters
            $parameters | ConvertTo-Json -Depth 10 | Set-Content $FilePath
            Write-Host "   ✅ Parameters file updated" -ForegroundColor Green
        } else {
            Write-Host "   ✅ Parameters file already up-to-date" -ForegroundColor Green
        }

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
        if ($WhatIf) {
            # For what-if, just capture the output without JSON parsing
            $deploymentOutput = & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ What-if analysis completed successfully" -ForegroundColor Green
                return @{ whatif = $true; output = $deploymentOutput }
            } else {
                throw "Deployment failed with exit code: $LASTEXITCODE"
            }
        } else {
            # For actual deployment, parse JSON result
            $deploymentResult = & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)] | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Deployment completed successfully" -ForegroundColor Green
                Write-Host "   📋 Deployment ID: $($deploymentResult.id)" -ForegroundColor Gray
                return $deploymentResult
            } else {
                throw "Deployment failed with exit code: $LASTEXITCODE"
            }
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

# Add GitHub repository information if provided
if ($GitHubRepository) {
    $resourceNames["GitHubRepository"] = $GitHubRepository
}

Write-Host "`n📋 Generated Resource Names:" -ForegroundColor Yellow
Write-Host "• App Name: $($resourceNames.AppName)" -ForegroundColor White
Write-Host "• Key Vault: $($resourceNames.KeyVaultName)" -ForegroundColor White
Write-Host "• Function App: $($resourceNames.FunctionAppName)" -ForegroundColor White
Write-Host "• Storage Account: $($resourceNames.StorageAccountName)" -ForegroundColor White
Write-Host "• Application Insights: $($resourceNames.ApplicationInsightsName)" -ForegroundColor White
Write-Host "• Service Principal: $($resourceNames.ServicePrincipalName)" -ForegroundColor White

# Check for existing resources that can be reused
$resourceCheck = Test-ExistingResources -ResourceGroupName $ResourceGroupName -ProposedNames $resourceNames -Platform $TargetPlatform

if ($resourceCheck.ExistingResources.Count -gt 0) {
    Write-Host "`n♻️  Existing Resources Found:" -ForegroundColor Green
    foreach ($resourceType in $resourceCheck.ExistingResources.Keys) {
        $resource = $resourceCheck.ExistingResources[$resourceType]
        Write-Host "• ${resourceType}: $($resource.Name) (will be reused)" -ForegroundColor Cyan
    }
    
    if (-not $Force -and -not $WhatIf) {
        Write-Host "`n💡 The deployment will reuse existing compatible resources and only create missing ones." -ForegroundColor Yellow
        $continue = Read-Host "Continue with reusing existing resources? (Y/n)"
        if ($continue -match "^[Nn]") {
            Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
            exit 0
        }
    }
}

if ($resourceCheck.Conflicts.Count -gt 0) {
    Write-Host "`n⚠️ Resource Name Conflicts Detected:" -ForegroundColor Red
    foreach ($conflict in $resourceCheck.Conflicts) {
        Write-Host "• $conflict" -ForegroundColor Yellow
    }
    Write-Host "`nPlease resolve these conflicts before proceeding." -ForegroundColor Red
    exit 1
}

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

# Choose template based on existing resources
if ($resourceCheck.ExistingResources.Count -gt 0) {
    # Use simple template that only creates monitoring resources and references existing ones
    $selectedTemplate = "templates\deploy-azure-resources-simple.bicep"
    $selectedParams = "templates\deploy-azure-resources-simple.parameters.json"
    
    # Update simple parameters with existing storage account name
    if ($resourceCheck.ExistingResources.ContainsKey("StorageAccount")) {
        $simpleParams = Get-Content $selectedParams | ConvertFrom-Json
        $simpleParams.parameters.storageAccountName.value = $resourceCheck.ExistingResources.StorageAccount.Name
        $simpleParams | ConvertTo-Json -Depth 10 | Set-Content $selectedParams
    }
    Write-Host "🔄 Using simplified template to work with existing resources" -ForegroundColor Cyan
} else {
    # Use full template to create new resources
    $selectedTemplate = $BicepTemplate
    $selectedParams = $ConfigurationFile
    
    # Update parameters file
    $parameterUpdate = Update-ParametersFile -FilePath $ConfigurationFile -ResourceNames $resourceNames -Platform $TargetPlatform -Location $Location
    if (-not $parameterUpdate) {
        exit 1
    }
}

# Deploy resources
$deploymentResult = Deploy-AzureResources -ResourceGroupName $ResourceGroupName -Location $Location -BicepFile $selectedTemplate -ParametersFile $selectedParams -ResourceNames $resourceNames -WhatIf $WhatIf.IsPresent

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
