# Configure GitHub Secrets and Variables for EasyPIM CI/CD
# This script automates the setup of GitHub repository secrets and variables
# after running the deployment script.

param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd-test",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Prerequisites check
function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan

    # Check GitHub CLI
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "❌ GitHub CLI (gh) is not installed. Please install it from: https://cli.github.com/"
        return $false
    }

    # Check GitHub CLI authentication
    try {
        $ghAuth = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ GitHub CLI is not authenticated. Please run: gh auth login"
            return $false
        }
        Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ GitHub CLI authentication check failed: $_"
        return $false
    }

    # Check Azure CLI and authentication
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "❌ Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return $false
    }

    try {
        $azAccount = az account show --query "{id: id, tenantId: tenantId}" | ConvertFrom-Json
        if (-not $azAccount) {
            Write-Error "❌ Azure CLI is not authenticated. Please run: az login"
            return $false
        }
        Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Azure CLI authentication check failed: $_"
        return $false
    }

    return $true
}

# Get deployment outputs from Azure
function Get-AzureDeploymentOutputs {
    param([string]$ResourceGroupName)

    Write-Host "🔍 Retrieving Azure deployment outputs..." -ForegroundColor Cyan

    try {
        # Get current Azure context
        $azAccount = az account show --query "{id: id, tenantId: tenantId}" | ConvertFrom-Json

        # Get Key Vault information
        $keyVaults = az keyvault list --resource-group $ResourceGroupName --query "[].{name:name, uri:properties.vaultUri}" | ConvertFrom-Json
        if (-not $keyVaults -or $keyVaults.Count -eq 0) {
            throw "No Key Vault found in resource group $ResourceGroupName"
        }

        $keyVault = $keyVaults[0]  # Assume first Key Vault

        # Get Service Principal information from deployment
        $apps = az ad app list --display-name "EasyPIM-CICD-$($ResourceGroupName.Replace('rg-', ''))" --query "[].{appId:appId, displayName:displayName}" | ConvertFrom-Json
        if (-not $apps -or $apps.Count -eq 0) {
            throw "No Azure AD application found for EasyPIM CICD"
        }

        $app = $apps[0]  # Assume first app

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

# Set GitHub secrets
function Set-GitHubSecrets {
    param(
        [string]$Repository,
        [hashtable]$Outputs,
        [switch]$Force
    )

    Write-Host "🔐 Setting GitHub repository secrets..." -ForegroundColor Cyan

    $secrets = @{
        "AZURE_CLIENT_ID" = $Outputs.ClientId
        "AZURE_TENANT_ID" = $Outputs.TenantId
        "AZURE_SUBSCRIPTION_ID" = $Outputs.SubscriptionId
    }

    foreach ($secret in $secrets.GetEnumerator()) {
        try {
            if ($Force) {
                Write-Host "🔑 Setting secret: $($secret.Key)" -ForegroundColor Yellow
                gh secret set $secret.Key --body $secret.Value --repo $Repository
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Secret $($secret.Key) set successfully" -ForegroundColor Green
                } else {
                    Write-Error "❌ Failed to set secret $($secret.Key)"
                }
            } else {
                # Check if secret exists
                $existing = gh secret list --repo $Repository --json name --jq ".[] | select(.name == `"$($secret.Key)`")"
                if ($existing) {
                    Write-Host "⚠️  Secret $($secret.Key) already exists. Use -Force to overwrite." -ForegroundColor Yellow
                } else {
                    Write-Host "🔑 Setting secret: $($secret.Key)" -ForegroundColor Yellow
                    gh secret set $secret.Key --body $secret.Value --repo $Repository
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✅ Secret $($secret.Key) set successfully" -ForegroundColor Green
                    } else {
                        Write-Error "❌ Failed to set secret $($secret.Key)"
                    }
                }
            }
        }
        catch {
            Write-Error "❌ Error setting secret $($secret.Key): $_"
        }
    }
}

# Set GitHub variables
function Set-GitHubVariables {
    param(
        [string]$Repository,
        [hashtable]$Outputs,
        [switch]$Force
    )

    Write-Host "📝 Setting GitHub repository variables..." -ForegroundColor Cyan

    $variables = @{
        "AZURE_KEYVAULT_NAME" = $Outputs.KeyVaultName
        "AZURE_KEYVAULT_SECRET_NAME" = $Outputs.SecretName
        "AZURE_RESOURCE_GROUP" = $Outputs.ResourceGroup
        "AZURE_KEY_VAULT_URI" = $Outputs.KeyVaultUri
    }

    foreach ($variable in $variables.GetEnumerator()) {
        try {
            if ($Force) {
                Write-Host "📝 Setting variable: $($variable.Key)" -ForegroundColor Yellow
                gh variable set $variable.Key --body $variable.Value --repo $Repository
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Variable $($variable.Key) set successfully" -ForegroundColor Green
                } else {
                    Write-Error "❌ Failed to set variable $($variable.Key)"
                }
            } else {
                # Check if variable exists
                $existing = gh variable list --repo $Repository --json name --jq ".[] | select(.name == `"$($variable.Key)`")"
                if ($existing) {
                    Write-Host "⚠️  Variable $($variable.Key) already exists. Use -Force to overwrite." -ForegroundColor Yellow
                } else {
                    Write-Host "📝 Setting variable: $($variable.Key)" -ForegroundColor Yellow
                    gh variable set $variable.Key --body $variable.Value --repo $Repository
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✅ Variable $($variable.Key) set successfully" -ForegroundColor Green
                    } else {
                        Write-Error "❌ Failed to set variable $($variable.Key)"
                    }
                }
            }
        }
        catch {
            Write-Error "❌ Error setting variable $($variable.Key): $_"
        }
    }
}

# Main script execution
Write-Host @"
🚀 EasyPIM CI/CD - GitHub Configuration Setup
============================================
Repository: $GitHubRepository
Resource Group: $ResourceGroupName
Force Mode: $($Force.IsPresent)

"@ -ForegroundColor Magenta

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
    Write-Host "`n⚠️  This will configure GitHub secrets and variables for repository: $GitHubRepository" -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to continue? (y/N)"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
        exit 0
    }
}

# Set GitHub secrets and variables
Write-Host "`n🔧 Configuring GitHub repository..." -ForegroundColor Cyan
Set-GitHubSecrets -Repository $GitHubRepository -Outputs $outputs -Force:$Force
Set-GitHubVariables -Repository $GitHubRepository -Outputs $outputs -Force:$Force

Write-Host "`n🎉 GitHub configuration completed!" -ForegroundColor Green
Write-Host @"

✅ Next Steps:
1. Test Phase 1 authentication: Go to GitHub Actions → 'Phase 1: Authentication Test' → Run workflow
2. Grant admin consent for Azure AD application permissions (if not done already)
3. Review the Step-by-Step Guide: docs/Step-by-Step-Guide.md

🔗 Repository: https://github.com/$GitHubRepository
🔗 Actions: https://github.com/$GitHubRepository/actions

"@ -ForegroundColor Green
