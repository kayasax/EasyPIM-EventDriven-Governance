#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault

<#
.SYNOPSIS
    Deploys Azure resources for EasyPIM CI/CD testing using Bicep template

.DESCRIPTION
    This script deploys all required Azure resources for EasyPIM GitHub Actions CI/CD testing:
    - Service Principal with federated identity credentials
    - Key Vault for secure configuration storage
    - Required RBAC role assignments
    - Sample EasyPIM configuration

.PARAMETER ResourceGroupName
    Name of the resource group to create/use

.PARAMETER Location
    Azure region for resource deployment

.PARAMETER ResourcePrefix
    Prefix for all resource names

.PARAMETER Environment
    Environment suffix (dev, test, prod)

.PARAMETER GitHubRepository
    GitHub repository in format: owner/repo

.PARAMETER GitHubEnvironment
    GitHub environment name (optional)

.PARAMETER KeyVaultAdministrators
    Array of user/group object IDs that should have Key Vault admin access

.PARAMETER SubscriptionId
    Azure subscription ID (optional, uses current context if not specified)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\deploy-azure-resources.ps1 -ResourceGroupName "rg-easypim-cicd-test" -GitHubRepository "kayasax/EasyPIM-CICD-test"

.EXAMPLE
    .\deploy-azure-resources.ps1 -ResourceGroupName "rg-easypim-cicd-test" -GitHubRepository "kayasax/EasyPIM-CICD-test" -Environment "dev" -Force

.NOTES
    Author: EasyPIM CI/CD Testing
    Requires: Az PowerShell modules, appropriate Azure permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",

    [Parameter(Mandatory = $false)]
    [string]$ResourcePrefix = "easypim-cicd",

    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment = "test",

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $false)]
    [string]$GitHubEnvironment = "",

    [Parameter(Mandatory = $false)]
    [string[]]$KeyVaultAdministrators = @(),

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Helper function for colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $colors = @{
        "Info"    = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
    }

    Write-Host "[$Type] $Message" -ForegroundColor $colors[$Type]
}

# Validate script location
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$bicepPath = Join-Path $scriptPath "deploy-azure-resources.bicep"

if (-not (Test-Path $bicepPath)) {
    Write-ColorOutput "Bicep template not found at: $bicepPath" -Type "Error"
    exit 1
}

Write-ColorOutput "🚀 Starting EasyPIM CI/CD Azure Resources Deployment" -Type "Info"
Write-ColorOutput "Resource Group: $ResourceGroupName" -Type "Info"
Write-ColorOutput "Location: $Location" -Type "Info"
Write-ColorOutput "Environment: $Environment" -Type "Info"
Write-ColorOutput "GitHub Repository: $GitHubRepository" -Type "Info"

try {
    # Check if user is logged in to Azure
    Write-ColorOutput "Checking Azure authentication..." -Type "Info"
    $context = Get-AzContext
    if (-not $context) {
        Write-ColorOutput "Not logged in to Azure. Please run Connect-AzAccount first." -Type "Error"
        exit 1
    }

    Write-ColorOutput "Authenticated as: $($context.Account.Id)" -Type "Success"

    # Set subscription if provided
    if ($SubscriptionId) {
        Write-ColorOutput "Setting subscription to: $SubscriptionId" -Type "Info"
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }

    $currentSubscription = (Get-AzContext).Subscription
    Write-ColorOutput "Using subscription: $($currentSubscription.Name) ($($currentSubscription.Id))" -Type "Info"

    # Check if resource group exists, create if it doesn't
    Write-ColorOutput "Checking resource group: $ResourceGroupName" -Type "Info"
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (-not $resourceGroup) {
        if ($Force -or $PSCmdlet.ShouldProcess($ResourceGroupName, "Create Resource Group")) {
            Write-ColorOutput "Creating resource group: $ResourceGroupName" -Type "Info"
            $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{
                "Project" = "EasyPIM-CICD-Testing"
                "Environment" = $Environment
                "CreatedBy" = "PowerShell-Script"
                "CreatedDate" = (Get-Date).ToString("yyyy-MM-dd")
            }
            Write-ColorOutput "Resource group created successfully" -Type "Success"
        }
    } else {
        Write-ColorOutput "Resource group already exists" -Type "Success"
    }

    # Get current user for Key Vault admin access
    if ($KeyVaultAdministrators.Count -eq 0) {
        try {
            $currentUser = Get-AzADUser -UserPrincipalName $context.Account.Id -ErrorAction SilentlyContinue
            if ($currentUser) {
                $KeyVaultAdministrators = @($currentUser.Id)
                Write-ColorOutput "Added current user as Key Vault administrator: $($context.Account.Id)" -Type "Info"
            }
        } catch {
            Write-ColorOutput "Could not determine current user ID. Key Vault admin access will need to be configured manually." -Type "Warning"
        }
    }

    # Prepare deployment parameters
    $deploymentParams = @{
        resourcePrefix = $ResourcePrefix
        environment = $Environment
        githubRepository = $GitHubRepository
        location = $Location
    }

    if ($GitHubEnvironment) {
        $deploymentParams.githubEnvironment = $GitHubEnvironment
    }

    if ($KeyVaultAdministrators.Count -gt 0) {
        $deploymentParams.keyVaultAdministrators = $KeyVaultAdministrators
    }

    # Deploy Bicep template
    $deploymentName = "easypim-cicd-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    if ($Force -or $PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy Azure Resources")) {
        Write-ColorOutput "🚀 Starting Bicep deployment: $deploymentName" -Type "Info"
        Write-ColorOutput "This may take several minutes..." -Type "Info"

        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -Name $deploymentName `
            -TemplateFile $bicepPath `
            -TemplateParameterObject $deploymentParams `
            -Verbose

        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-ColorOutput "✅ Deployment completed successfully!" -Type "Success"

            # Display outputs
            Write-ColorOutput "`n📋 Deployment Outputs:" -Type "Info"
            Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type "Info"

            $outputs = $deployment.Outputs

            Write-ColorOutput "`n🔑 GitHub Repository Secrets (add these to your repository):" -Type "Info"
            if ($outputs.githubSecretsConfiguration) {
                $secrets = $outputs.githubSecretsConfiguration.Value
                foreach ($secret in $secrets.PSObject.Properties) {
                    Write-Host "  $($secret.Name): " -ForegroundColor Yellow -NoNewline
                    Write-Host $secret.Value -ForegroundColor White
                }
            }

            Write-ColorOutput "`n🔧 GitHub Repository Variables (add these to your repository):" -Type "Info"
            if ($outputs.githubVariablesConfiguration) {
                $variables = $outputs.githubVariablesConfiguration.Value
                foreach ($variable in $variables.PSObject.Properties) {
                    Write-Host "  $($variable.Name): " -ForegroundColor Yellow -NoNewline
                    Write-Host $variable.Value -ForegroundColor White
                }
            }

            Write-ColorOutput "`n🏗️ Deployed Resources:" -Type "Info"
            Write-Host "  Service Principal Client ID: " -ForegroundColor Yellow -NoNewline
            Write-Host $outputs.servicePrincipalClientId.Value -ForegroundColor White
            Write-Host "  Key Vault Name: " -ForegroundColor Yellow -NoNewline
            Write-Host $outputs.keyVaultName.Value -ForegroundColor White
            Write-Host "  Key Vault URI: " -ForegroundColor Yellow -NoNewline
            Write-Host $outputs.keyVaultUri.Value -ForegroundColor White

            Write-ColorOutput "`n⚠️ Required Graph API Permissions:" -Type "Warning"
            if ($outputs.requiredGraphPermissions) {
                foreach ($permission in $outputs.requiredGraphPermissions.Value) {
                    Write-Host "  • $($permission.permission) ($($permission.type)): $($permission.description)" -ForegroundColor Yellow
                }
            }

            Write-ColorOutput "`n📝 Post-Deployment Instructions:" -Type "Info"
            if ($outputs.postDeploymentInstructions) {
                foreach ($instruction in $outputs.postDeploymentInstructions.Value) {
                    Write-Host "  $instruction" -ForegroundColor Cyan
                }
            }

            Write-ColorOutput "`n🔗 Next Steps:" -Type "Info"
            Write-Host "1. Go to Azure Portal > Azure Active Directory > App registrations" -ForegroundColor Cyan
            Write-Host "2. Find your app: $ResourcePrefix-$Environment-sp" -ForegroundColor Cyan
            Write-Host "3. Go to API permissions > Grant admin consent" -ForegroundColor Cyan
            Write-Host "4. Configure GitHub repository secrets and variables as shown above" -ForegroundColor Cyan
            Write-Host "5. Run your GitHub Actions workflow to test authentication" -ForegroundColor Cyan

            Write-ColorOutput "`n✅ Deployment Summary:" -Type "Success"
            Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Green
            Write-Host "  Deployment Name: $deploymentName" -ForegroundColor Green
            Write-Host "  Status: $($deployment.ProvisioningState)" -ForegroundColor Green
            Write-Host "  Duration: $([math]::Round(($deployment.Timestamp - $deployment.StartTime).TotalMinutes, 2)) minutes" -ForegroundColor Green

        } else {
            Write-ColorOutput "❌ Deployment failed with status: $($deployment.ProvisioningState)" -Type "Error"
            if ($deployment.Error) {
                Write-ColorOutput "Error details: $($deployment.Error.Message)" -Type "Error"
            }
            exit 1
        }
    }

} catch {
    Write-ColorOutput "❌ Deployment failed with error: $($_.Exception.Message)" -Type "Error"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" -Type "Error"
    exit 1
}

Write-ColorOutput "`n🎉 EasyPIM CI/CD Azure resources deployment completed successfully!" -Type "Success"
Write-ColorOutput "You can now configure your GitHub repository and test the CI/CD workflow." -Type "Info"
