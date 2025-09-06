# Configure CI/CD Platform for EasyPIM Event-Driven Governance
# This script automates the setup of secrets and variables for both GitHub Actions and Azure DevOps
# after running the deployment script.

# Check for help first before parameter validation
if ($args -contains "-Help" -or $args -contains "-h" -or $args -contains "--help" -or $args -contains "-?") {
    # Display help and usage
    Write-Host @"
🚀 EasyPIM Event-Driven Governance - CI/CD Configuration
=======================================================

This script configures secrets and variables for your chosen CI/CD platform(s).

USAGE:
  .\configure-cicd.ps1 -Platform <GitHub|AzureDevOps|Both> [options]

PARAMETERS:
  -Platform              CI/CD platform to configure (required)
                         Options: GitHub, AzureDevOps, Both

  -GitHubRepository      GitHub repository in format 'owner/repo'
                         Required when Platform is GitHub or Both

  -AzureDevOpsProject    Azure DevOps project name
                         Required when Platform is AzureDevOps or Both

  -AzureDevOpsOrganization  Azure DevOps organization name
                           Required when Platform is AzureDevOps or Both

  -ResourceGroupName     Azure resource group name (default: rg-easypim-cicd-test)

  -Force                 Skip confirmation prompts

EXAMPLES:
  # Configure GitHub Actions only
  .\configure-cicd.ps1 -Platform GitHub -GitHubRepository "contoso/easypim-governance"

  # Configure Azure DevOps only
  .\configure-cicd.ps1 -Platform AzureDevOps -AzureDevOpsProject "EasyPIM" -AzureDevOpsOrganization "contoso"

  # Configure both platforms
  .\configure-cicd.ps1 -Platform Both -GitHubRepository "contoso/easypim-governance" -AzureDevOpsProject "EasyPIM" -AzureDevOpsOrganization "contoso"

PREREQUISITES:
  • Azure CLI authenticated (az login)
  • For GitHub: GitHub CLI authenticated (gh auth login)
  • For Azure DevOps: Azure DevOps CLI extension (az extension add --name azure-devops)
  • Appropriate permissions on target repositories/projects

"@ -ForegroundColor Cyan
    exit 0
}

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("GitHub", "AzureDevOps", "Both")]
    [string]$Platform,

    [Parameter(Mandatory = $false)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsProject,

    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsOrganization,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd-test",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Display help and usage
function Show-Usage {
    # This function is now handled above in the help check
}

# Validate parameters based on platform selection
function Test-Parameters {
    $errors = @()

    switch ($Platform) {
        "GitHub" {
            if (-not $GitHubRepository) {
                $errors += "GitHubRepository parameter is required when Platform is GitHub"
            }
        }
        "AzureDevOps" {
            if (-not $AzureDevOpsProject) {
                $errors += "AzureDevOpsProject parameter is required when Platform is AzureDevOps"
            }
            if (-not $AzureDevOpsOrganization) {
                $errors += "AzureDevOpsOrganization parameter is required when Platform is AzureDevOps"
            }
        }
        "Both" {
            if (-not $GitHubRepository) {
                $errors += "GitHubRepository parameter is required when Platform is Both"
            }
            if (-not $AzureDevOpsProject) {
                $errors += "AzureDevOpsProject parameter is required when Platform is Both"
            }
            if (-not $AzureDevOpsOrganization) {
                $errors += "AzureDevOpsOrganization parameter is required when Platform is Both"
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "❌ Parameter validation failed:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "   • $error" -ForegroundColor Red
        }
        Write-Host "`n" -NoNewline
        Show-Usage
        return $false
    }

    return $true
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
            $azAccount = az account show --query "{id: id, tenantId: tenantId}" | ConvertFrom-Json
            if (-not $azAccount) {
                Write-Error "❌ Azure CLI is not authenticated. Please run: az login"
                $allGood = $false
            } else {
                Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "❌ Azure CLI authentication check failed: $_"
            $allGood = $false
        }
    }

    # Check GitHub CLI if GitHub platform is selected
    if ($Platform -eq "GitHub" -or $Platform -eq "Both") {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-Error "❌ GitHub CLI (gh) is not installed. Please install it from: https://cli.github.com/"
            $allGood = $false
        } else {
            # Check GitHub CLI authentication
            try {
                $ghAuth = gh auth status 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "❌ GitHub CLI is not authenticated. Please run: gh auth login"
                    $allGood = $false
                } else {
                    Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "❌ GitHub CLI authentication check failed: $_"
                $allGood = $false
            }
        }
    }

    # Check Azure DevOps CLI if Azure DevOps platform is selected
    if ($Platform -eq "AzureDevOps" -or $Platform -eq "Both") {
        try {
            $adoExtensions = az extension list --query "[?name=='azure-devops'].name" | ConvertFrom-Json
            if (-not $adoExtensions -or $adoExtensions.Count -eq 0) {
                Write-Host "⚠️  Azure DevOps CLI extension not found. Installing..." -ForegroundColor Yellow
                az extension add --name azure-devops
                Write-Host "✅ Azure DevOps CLI extension installed" -ForegroundColor Green
            } else {
                Write-Host "✅ Azure DevOps CLI extension available" -ForegroundColor Green
            }

            # Check Azure DevOps authentication
            try {
                $adoOrgs = az devops project list --organization "https://dev.azure.com/$AzureDevOpsOrganization" --query "value[0].name" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Azure DevOps authenticated for organization: $AzureDevOpsOrganization" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Azure DevOps authentication may be required. Please ensure you have access to: https://dev.azure.com/$AzureDevOpsOrganization" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "⚠️  Could not verify Azure DevOps authentication. Please ensure you have access to: https://dev.azure.com/$AzureDevOpsOrganization" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Error "❌ Azure DevOps CLI extension check failed: $_"
            $allGood = $false
        }
    }

    return $allGood
}

# Get deployment outputs from Azure
function Get-AzureDeploymentOutputs {
    param([string]$ResourceGroupName)

    Write-Host "🔍 Retrieving Azure deployment outputs..." -ForegroundColor Cyan

    try {
        # Get current Azure context
        $azAccount = az account show --query "{id: id, tenantId: tenantId}" | ConvertFrom-Json

        # Get Key Vault information using tags to identify EasyPIM resources
        $keyVaults = az keyvault list --resource-group $ResourceGroupName --query "[].{name:name, uri:properties.vaultUri, tags:tags}" | ConvertFrom-Json
        if (-not $keyVaults -or $keyVaults.Count -eq 0) {
            throw "No Key Vault found in resource group $ResourceGroupName"
        }

        # Handle Key Vault selection using tags
        $keyVault = $null
        if ($keyVaults.Count -eq 1) {
            $keyVault = $keyVaults[0]
            Write-Host "✅ Found Key Vault: $($keyVault.name)" -ForegroundColor Green
        } else {
            # Multiple Key Vaults - use tags to find the EasyPIM CI/CD one
            $easypimKeyVaults = $keyVaults | Where-Object {
                $_.tags -and (
                    $_.tags.Project -eq "EasyPIM-CICD-Testing" -or
                    $_.tags.Purpose -eq "EasyPIM-CI-CD-Testing" -or
                    $_.tags.Purpose -eq "CI-CD-Automation" -or
                    ($_.tags.Project -like "*EasyPIM*" -and $_.tags.Environment -eq "test")
                )
            }

            if ($easypimKeyVaults.Count -eq 1) {
                $keyVault = $easypimKeyVaults[0]
                Write-Host "✅ Found EasyPIM Key Vault by tags: $($keyVault.name)" -ForegroundColor Green
                Write-Host "   Tags: Project=$($keyVault.tags.Project), Purpose=$($keyVault.tags.Purpose)" -ForegroundColor Gray
            } elseif ($easypimKeyVaults.Count -gt 1) {
                # Multiple EasyPIM Key Vaults - sort by name and take the latest
                $easypimKeyVaults = $easypimKeyVaults | Sort-Object name -Descending
                $keyVault = $easypimKeyVaults[0]
                Write-Host "✅ Found multiple EasyPIM Key Vaults, using latest: $($keyVault.name)" -ForegroundColor Green
                Write-Host "   Available: $($easypimKeyVaults.name -join ', ')" -ForegroundColor Gray
            } else {
                # Fallback to name pattern matching
                $easypimKeyVaults = $keyVaults | Where-Object { $_.name -like "*easypim*" -or $_.name -like "*pim*" }

                if ($easypimKeyVaults.Count -gt 0) {
                    $keyVault = $easypimKeyVaults[0]
                    Write-Host "⚠️  No Key Vault found with EasyPIM tags, using name pattern: $($keyVault.name)" -ForegroundColor Yellow
                } else {
                    $keyVault = $keyVaults[0]
                    Write-Host "⚠️  No EasyPIM Key Vault identified, using first available: $($keyVault.name)" -ForegroundColor Yellow
                }
            }
        }

        # Get Service Principal information from deployment
        # Try multiple patterns for the Azure AD application name
        $appPatterns = @(
            "EasyPIM-CI-CD-Test",
            "EasyPIM-CICD-$($ResourceGroupName.Replace('rg-', ''))",
            "EasyPIM CICD",
            "EasyPIM-EventDriven-Governance"
        )

        $app = $null
        foreach ($pattern in $appPatterns) {
            $apps = az ad app list --display-name $pattern --query "[].{appId:appId, displayName:displayName}" | ConvertFrom-Json
            if ($apps -and $apps.Count -gt 0) {
                $app = $apps[0]
                Write-Host "✅ Found Azure AD application: $($app.displayName)" -ForegroundColor Green
                break
            }
        }

        if (-not $app) {
            throw "No Azure AD application found for EasyPIM CICD. Tried patterns: $($appPatterns -join ', ')"
        }

        # Return deployment outputs
        return @{
            TenantId = $azAccount.tenantId
            SubscriptionId = $azAccount.id
            ClientId = $app.appId
            ResourceGroup = $ResourceGroupName
            KeyVaultName = $keyVault.name
            KeyVaultUri = $keyVault.uri
            SecretName = "easypim-config-json"
        }
    }
    catch {
        Write-Error "❌ Failed to retrieve Azure deployment outputs: $_"
        return $null
    }
}

# Configure GitHub Actions secrets and variables
function Set-GitHubConfiguration {
    param(
        [string]$Repository,
        [hashtable]$Outputs,
        [bool]$Force
    )

    Write-Host "🔧 Configuring GitHub Actions for repository: $Repository" -ForegroundColor Cyan

    # Define secrets to set
    $secrets = @{
        "AZURE_TENANT_ID" = $Outputs.TenantId
        "AZURE_SUBSCRIPTION_ID" = $Outputs.SubscriptionId
        "AZURE_CLIENT_ID" = $Outputs.ClientId
    }

    # Define variables to set
    $variables = @{
        "AZURE_RESOURCE_GROUP" = $Outputs.ResourceGroup
        "AZURE_KEY_VAULT_NAME" = $Outputs.KeyVaultName
        "AZURE_KEY_VAULT_URI" = $Outputs.KeyVaultUri
        "EASYPIM_SECRET_NAME" = $Outputs.SecretName
    }

    # Set secrets
    Write-Host "   📝 Setting GitHub secrets..." -ForegroundColor Gray
    foreach ($secret in $secrets.GetEnumerator()) {
        try {
            if ($Force) {
                gh secret set $secret.Key --body $secret.Value --repo $Repository
            } else {
                $existingSecret = gh secret list --repo $Repository | Select-String $secret.Key
                if ($existingSecret) {
                    $overwrite = Read-Host "Secret '$($secret.Key)' already exists. Overwrite? (y/N)"
                    if ($overwrite -match "^[Yy]") {
                        gh secret set $secret.Key --body $secret.Value --repo $Repository
                    }
                } else {
                    gh secret set $secret.Key --body $secret.Value --repo $Repository
                }
            }
            Write-Host "      ✅ $($secret.Key)" -ForegroundColor Green
        }
        catch {
            Write-Host "      ❌ Failed to set $($secret.Key): $_" -ForegroundColor Red
        }
    }

    # Set variables
    Write-Host "   📝 Setting GitHub variables..." -ForegroundColor Gray
    foreach ($variable in $variables.GetEnumerator()) {
        try {
            if ($Force) {
                gh variable set $variable.Key --body $variable.Value --repo $Repository
            } else {
                $existingVariable = gh variable list --repo $Repository | Select-String $variable.Key
                if ($existingVariable) {
                    $overwrite = Read-Host "Variable '$($variable.Key)' already exists. Overwrite? (y/N)"
                    if ($overwrite -match "^[Yy]") {
                        gh variable set $variable.Key --body $variable.Value --repo $Repository
                    }
                } else {
                    gh variable set $variable.Key --body $variable.Value --repo $Repository
                }
            }
            Write-Host "      ✅ $($variable.Key)" -ForegroundColor Green
        }
        catch {
            Write-Host "      ❌ Failed to set $($variable.Key): $_" -ForegroundColor Red
        }
    }

    Write-Host "✅ GitHub Actions configuration completed!" -ForegroundColor Green
}

# Configure Azure DevOps variables and service connections
function Set-AzureDevOpsConfiguration {
    param(
        [string]$Organization,
        [string]$Project,
        [hashtable]$Outputs,
        [bool]$Force
    )

    Write-Host "🔧 Configuring Azure DevOps for project: $Organization/$Project" -ForegroundColor Cyan

    $orgUrl = "https://dev.azure.com/$Organization"

    # Define variables to set (Azure DevOps uses variables for both secrets and regular values)
    $variables = @{
        "AZURE_TENANT_ID" = @{ value = $Outputs.TenantId; isSecret = $true }
        "AZURE_SUBSCRIPTION_ID" = @{ value = $Outputs.SubscriptionId; isSecret = $true }
        "AZURE_CLIENT_ID" = @{ value = $Outputs.ClientId; isSecret = $true }
        "AZURE_RESOURCE_GROUP" = @{ value = $Outputs.ResourceGroup; isSecret = $false }
        "AZURE_KEY_VAULT_NAME" = @{ value = $Outputs.KeyVaultName; isSecret = $false }
        "AZURE_KEY_VAULT_URI" = @{ value = $Outputs.KeyVaultUri; isSecret = $false }
        "EASYPIM_SECRET_NAME" = @{ value = $Outputs.SecretName; isSecret = $false }
    }

    # Create or update variable group
    $variableGroupName = "EasyPIM-EventDriven-Governance"

    Write-Host "   📝 Creating/updating variable group: $variableGroupName" -ForegroundColor Gray

    try {
        # Check if variable group exists
        $existingGroup = az pipelines variable-group list --organization $orgUrl --project $Project --group-name $variableGroupName 2>$null | ConvertFrom-Json

        if ($existingGroup -and $existingGroup.Count -gt 0) {
            $groupId = $existingGroup[0].id
            Write-Host "      ✅ Found existing variable group (ID: $groupId)" -ForegroundColor Green

            # Update existing variables
            foreach ($variable in $variables.GetEnumerator()) {
                try {
                    if ($variable.Value.isSecret) {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value --secret $true 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            # Variable might exist, try to update
                            az pipelines variable-group variable update --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value --secret $true 2>$null
                        }
                    } else {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            # Variable might exist, try to update
                            az pipelines variable-group variable update --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value 2>$null
                        }
                    }
                    Write-Host "      ✅ $($variable.Key)" -ForegroundColor Green
                }
                catch {
                    Write-Host "      ❌ Failed to set $($variable.Key): $_" -ForegroundColor Red
                }
            }
        } else {
            # Create new variable group
            Write-Host "      📋 Creating new variable group..." -ForegroundColor Gray

            # Create the variable group first
            $newGroup = az pipelines variable-group create --organization $orgUrl --project $Project --name $variableGroupName --description "EasyPIM Event-Driven Governance CI/CD Variables" | ConvertFrom-Json
            $groupId = $newGroup.id

            # Add variables to the new group
            foreach ($variable in $variables.GetEnumerator()) {
                try {
                    if ($variable.Value.isSecret) {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value --secret $true
                    } else {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value
                    }
                    Write-Host "      ✅ $($variable.Key)" -ForegroundColor Green
                }
                catch {
                    Write-Host "      ❌ Failed to set $($variable.Key): $_" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "      ❌ Failed to configure variable group: $_" -ForegroundColor Red
        return
    }

    Write-Host "✅ Azure DevOps configuration completed!" -ForegroundColor Green
    Write-Host "   📋 Variable Group: $variableGroupName (ID: $groupId)" -ForegroundColor Gray
    Write-Host "   🔗 Manage at: $orgUrl/$Project/_library?itemType=VariableGroups&view=VariableGroupView&variableGroupId=$groupId" -ForegroundColor Gray
}

# Main script execution
Write-Host @"
🚀 EasyPIM Event-Driven Governance - CI/CD Configuration
========================================================
Platform: $Platform
Resource Group: $ResourceGroupName

"@ -ForegroundColor Magenta

# Validate parameters
if (-not (Test-Parameters)) {
    exit 1
}

# Display configuration summary
Write-Host "📋 Configuration Summary:" -ForegroundColor Yellow
Write-Host "• Platform: $Platform" -ForegroundColor White
if ($GitHubRepository) {
    Write-Host "• GitHub Repository: $GitHubRepository" -ForegroundColor White
}
if ($AzureDevOpsOrganization -and $AzureDevOpsProject) {
    Write-Host "• Azure DevOps: $AzureDevOpsOrganization/$AzureDevOpsProject" -ForegroundColor White
}
Write-Host "• Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "• Force Mode: $($Force.IsPresent)" -ForegroundColor White

# Check prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

# Get Azure deployment outputs
$outputs = Get-AzureDeploymentOutputs -ResourceGroupName $ResourceGroupName
if (-not $outputs) {
    exit 1
}

Write-Host "`n📋 Retrieved deployment information:" -ForegroundColor Green
Write-Host "• Tenant ID: $($outputs.TenantId)" -ForegroundColor White
Write-Host "• Subscription ID: $($outputs.SubscriptionId)" -ForegroundColor White
Write-Host "• Client ID: $($outputs.ClientId)" -ForegroundColor White
Write-Host "• Resource Group: $($outputs.ResourceGroup)" -ForegroundColor White
Write-Host "• Key Vault Name: $($outputs.KeyVaultName)" -ForegroundColor White
Write-Host "• Key Vault URI: $($outputs.KeyVaultUri)" -ForegroundColor White
Write-Host "• Secret Name: $($outputs.SecretName)" -ForegroundColor White

# Confirm before proceeding
if (-not $Force) {
    Write-Host "`n⚠️  This will configure CI/CD platform(s) with the above information" -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to continue? (y/N)"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
        exit 0
    }
}

# Configure platforms
Write-Host "`n🔧 Configuring CI/CD platform(s)..." -ForegroundColor Cyan

switch ($Platform) {
    "GitHub" {
        Set-GitHubConfiguration -Repository $GitHubRepository -Outputs $outputs -Force $Force.IsPresent
    }
    "AzureDevOps" {
        Set-AzureDevOpsConfiguration -Organization $AzureDevOpsOrganization -Project $AzureDevOpsProject -Outputs $outputs -Force $Force.IsPresent
    }
    "Both" {
        Set-GitHubConfiguration -Repository $GitHubRepository -Outputs $outputs -Force $Force.IsPresent
        Write-Host ""
        Set-AzureDevOpsConfiguration -Organization $AzureDevOpsOrganization -Project $AzureDevOpsProject -Outputs $outputs -Force $Force.IsPresent
    }
}

Write-Host "`n🎉 CI/CD configuration completed!" -ForegroundColor Green

# Display next steps based on platform
Write-Host "`n✅ Next Steps:" -ForegroundColor Green

if ($Platform -eq "GitHub" -or $Platform -eq "Both") {
    Write-Host @"
GitHub Actions:
1. Test Phase 1 authentication: Go to GitHub Actions → 'Phase 1: Authentication Test' → Run workflow
2. Grant admin consent for Azure AD application permissions (if not done already)
3. Review the Step-by-Step Guide: docs/Step-by-Step-Guide.md

🔗 Repository: https://github.com/$GitHubRepository
🔗 Actions: https://github.com/$GitHubRepository/actions

"@ -ForegroundColor White
}

if ($Platform -eq "AzureDevOps" -or $Platform -eq "Both") {
    Write-Host @"
Azure DevOps:
1. Create Azure DevOps pipelines using the provided templates (coming in Phase 2)
2. Test authentication and Key Vault access
3. Grant admin consent for Azure AD application permissions (if not done already)

🔗 Project: https://dev.azure.com/$AzureDevOpsOrganization/$AzureDevOpsProject
🔗 Variable Groups: https://dev.azure.com/$AzureDevOpsOrganization/$AzureDevOpsProject/_library

"@ -ForegroundColor White
}

Write-Host "📖 For detailed implementation guide, see: docs/Azure-DevOps-Integration-Plan.md" -ForegroundColor Cyan
