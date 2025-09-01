#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault

<#
.SYNOPSIS
    Deploy Azure infrastructure for EasyPIM CI/CD testing

.DESCRIPTION
    This script deploys the required Azure resources for EasyPIM CI/CD testing:
    - Creates Azure AD Application with required permissions
    - Sets up OIDC federation for GitHub Actions
    - Deploys Azure resources via Bicep (Key Vault, RBAC)
    - Configures security and access policies

.PARAMETER GitHubRepository
    GitHub repository in format 'owner/repo'

.PARAMETER ResourceGroupName
    Name of the Azure resource group to create/use

.PARAMETER Location
    Azure region for resource deployment (if not specified, reads from parameters file)

.PARAMETER ApplicationName
    Name for the Azure AD application

.PARAMETER BranchName
    GitHub branch for OIDC federation (default: main)

.PARAMETER SubscriptionId
    Azure subscription ID (optional, uses current context if not provided)

.PARAMETER ParametersFile
    Path to parameters file (default: deploy-azure-resources.parameters.json)

.EXAMPLE
    .\deploy-azure-resources-hybrid.ps1 -GitHubRepository "myorg/EasyPIM-test" -ResourceGroupName "rg-easypim-cicd-test"

.EXAMPLE
    .\deploy-azure-resources-hybrid.ps1 -GitHubRepository "myorg/EasyPIM-test" -ResourceGroupName "rg-easypim-cicd-test" -Location "francecentral"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$Location,

    [Parameter()]
    [string]$ApplicationName = "EasyPIM-CI-CD-Test",

    [Parameter()]
    [string]$BranchName = "main",

    [Parameter()]
    [string]$SubscriptionId,

    [Parameter()]
    [string]$ParametersFile = "deploy-azure-resources.parameters.json"
)

# Enhanced error handling and logging
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Read parameters from file if Location not specified
if (-not $Location) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $parametersFilePath = Join-Path $scriptPath $ParametersFile

    if (Test-Path $parametersFilePath) {
        try {
            $parametersContent = Get-Content -Path $parametersFilePath -Raw | ConvertFrom-Json
            $Location = $parametersContent.parameters.location.value
            Write-Host "📖 Using location from parameters file: $Location" -ForegroundColor Yellow
        } catch {
            Write-Warning "Failed to read location from parameters file. Using default: East US"
            $Location = "East US"
        }
    } else {
        Write-Warning "Parameters file not found: $parametersFilePath. Using default location: East US"
        $Location = "East US"
    }
}

# Console colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    $colorMap = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "Cyan" = [ConsoleColor]::Cyan
        "Magenta" = [ConsoleColor]::Magenta
        "White" = [ConsoleColor]::White
    }

    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

function Write-StepHeader {
    param([string]$Step)
    Write-Host "`n" -NoNewline
    Write-ColorOutput "🔧 $Step" "Cyan"
    Write-ColorOutput ("=" * 60) "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✅ $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠️  $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "❌ $Message" "Red"
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "ℹ️  $Message" "Blue"
}

# Banner
Write-Host "`n" -NoNewline
Write-ColorOutput @"
╔══════════════════════════════════════════════════════════════╗
║                    EasyPIM CI/CD Deployment                 ║
║          Azure Infrastructure for GitHub Actions            ║
╚══════════════════════════════════════════════════════════════╝
"@ "Magenta"

# Validate prerequisites
Write-StepHeader "Validating Prerequisites"

try {
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }
    Write-Success "PowerShell version: $($PSVersionTable.PSVersion)"

    # Check Azure CLI
    $azCliVersion = az --version 2>$null | Select-Object -First 1
    if (-not $azCliVersion) {
        throw "Azure CLI is not installed or not in PATH. Please install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }
    Write-Success "Azure CLI: $($azCliVersion -replace 'azure-cli\s+', '')"

    # Check Bicep CLI
    $bicepVersion = bicep --version 2>$null
    if (-not $bicepVersion) {
        Write-Warning "Bicep CLI not found. Installing via Azure CLI..."
        az bicep install

        # Verify installation
        $bicepVersion = bicep --version 2>$null
        if (-not $bicepVersion) {
            throw "Failed to install Bicep CLI. Please install manually."
        }
    }
    Write-Success "Bicep CLI: $bicepVersion"

    # Check required PowerShell modules
    $requiredModules = @("Az.Accounts", "Az.Resources", "Az.KeyVault")
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Warning "Installing PowerShell module: $module"
            Install-Module -Name $module -Force -AllowClobber
        }
        Write-Success "PowerShell module: $module"
    }

} catch {
    Write-Error "Prerequisites validation failed: $($_.Exception.Message)"
    Write-Info "Please install missing prerequisites and run the script again."
    exit 1
}

# Azure authentication and context
Write-StepHeader "Azure Authentication"

try {
    # Check if already logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        Write-Info "Please log in to Azure CLI..."
        az login
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Success "Azure CLI logged in as: $($azAccount.user.name)"
    Write-Info "Current subscription: $($azAccount.name) ($($azAccount.id))"

    # Set subscription if provided
    if ($SubscriptionId -and $SubscriptionId -ne $azAccount.id) {
        Write-Info "Switching to subscription: $SubscriptionId"
        az account set --subscription $SubscriptionId
        $azAccount = az account show | ConvertFrom-Json
    }

    # Connect PowerShell Az modules
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext -or $azContext.Subscription.Id -ne $azAccount.id) {
        Write-Info "Connecting PowerShell Az modules..."
        Connect-AzAccount -SubscriptionId $azAccount.id
    }

    Write-Success "PowerShell Az modules connected"

    $currentUser = Get-AzADUser -SignedIn
    Write-Info "Current user: $($currentUser.DisplayName) ($($currentUser.UserPrincipalName))"

} catch {
    Write-Error "Azure authentication failed: $($_.Exception.Message)"
    exit 1
}

# Create resource group
Write-StepHeader "Creating Resource Group"

try {
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        Write-Info "Creating resource group: $ResourceGroupName in $Location"
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Success "Resource group created: $($resourceGroup.ResourceGroupName)"
    } else {
        Write-Success "Resource group exists: $($resourceGroup.ResourceGroupName)"
    }
} catch {
    Write-Error "Failed to create resource group: $($_.Exception.Message)"
    exit 1
}

# Create Azure AD Application
Write-StepHeader "Creating Azure AD Application"

try {
    # Check if application already exists
    $existingApp = az ad app list --display-name $ApplicationName --query "[0]" | ConvertFrom-Json

    if ($existingApp) {
        Write-Warning "Application '$ApplicationName' already exists. Using existing application."
        $appId = $existingApp.appId
    } else {
        Write-Info "Creating Azure AD application: $ApplicationName"

        # Create the application
        $app = az ad app create --display-name $ApplicationName --query "appId" -o tsv
        $appId = $app

        Write-Success "Azure AD application created: $appId"
    }

    # Create service principal
    $existingSp = az ad sp list --filter "appId eq '$appId'" --query "[0]" | ConvertFrom-Json

    if ($existingSp) {
        Write-Info "Service principal already exists for application"
        $spObjectId = $existingSp.id
    } else {
        Write-Info "Creating service principal..."
        $sp = az ad sp create --id $appId --query "id" -o tsv
        $spObjectId = $sp
        Write-Success "Service principal created: $spObjectId"
    }

    # Add required Microsoft Graph API permissions for EasyPIM
    Write-Info "Configuring Microsoft Graph API permissions..."

    # Required Graph permissions for EasyPIM (complete list from official repository)
    $graphPermissions = @(
        @{ id = "df021288-bdef-4463-88db-98f22de89214"; type = "Role" },   # User.Read.All
        @{ id = "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8"; type = "Role" },   # RoleManagement.ReadWrite.Directory
        @{ id = "6f9d5abc-2db6-400b-a267-7de22a40fb87"; type = "Role" },   # PrivilegedAccess.ReadWrite.AzureResources
        @{ id = "31e08e0a-d3f7-4ca2-ac39-7343fb83e8ad"; type = "Role" },   # RoleManagementPolicy.ReadWrite.Directory
        @{ id = "b38dcc4d-a239-4ed6-aa84-6c65b284f97c"; type = "Role" },   # RoleManagementPolicy.ReadWrite.AzureADGroup
        @{ id = "618b6020-bca8-4de6-99f6-ef445fa4d857"; type = "Role" },   # PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup
        @{ id = "41202f2c-f7ab-45be-b001-85c9728b9d69"; type = "Role" },   # PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup
        @{ id = "2f6817f8-7b12-4f0f-bc18-eeaf60705a9e"; type = "Role" },   # PrivilegedAccess.ReadWrite.AzureADGroup
        @{ id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"; type = "Role" },   # Directory.Read.All
        @{ id = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"; type = "Role" }    # Group.Read.All (for group policies)
    )

    foreach ($permission in $graphPermissions) {
        try {
            # Check if permission already exists
            $existingPermissions = az ad app permission list --id $appId --query "[?resourceAppId=='00000003-0000-0000-c000-000000000000'].resourceAccess[?id=='$($permission.id)']" | ConvertFrom-Json

            if ($existingPermissions.Count -eq 0) {
                Write-Info "Adding Graph permission: $($permission.id)"
                az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions "$($permission.id)=$($permission.type)"
            } else {
                Write-Info "Graph permission already exists: $($permission.id)"
            }
        } catch {
            Write-Warning "Failed to add Graph permission $($permission.id): $($_.Exception.Message)"
        }
    }

    Write-Success "Microsoft Graph API permissions configured"
    Write-Warning "⚠️  IMPORTANT: You must grant admin consent for these permissions in the Azure Portal!"
    Write-Info "   Go to: Azure AD → App registrations → $ApplicationName → API permissions → Grant admin consent"

    # Create federated credential for GitHub OIDC
    $federatedCredentialName = "GitHub-$BranchName-federation"
    $gitHubSubject = "repo:$GitHubRepository`:ref:refs/heads/$BranchName"

    Write-Info "Setting up OIDC federated credential..."
    Write-Info "GitHub subject: $gitHubSubject"

    # Check if federated credential already exists
    $existingCredentials = az ad app federated-credential list --id $appId --query "[?name=='$federatedCredentialName']" | ConvertFrom-Json

    if ($existingCredentials.Count -gt 0) {
        Write-Warning "Federated credential '$federatedCredentialName' already exists"
    } else {
        # Create JSON file to avoid PowerShell quoting issues
        $federatedCredParams = @{
            name = $federatedCredentialName
            issuer = "https://token.actions.githubusercontent.com"
            subject = $gitHubSubject
            description = "GitHub OIDC federation for CI/CD"
            audiences = @("api://AzureADTokenExchange")
        }

        $tempJsonFile = Join-Path $env:TEMP "federated-credential.json"
        $federatedCredParams | ConvertTo-Json -Depth 3 | Set-Content -Path $tempJsonFile -Encoding UTF8

        try {
            az ad app federated-credential create --id $appId --parameters "@$tempJsonFile"
            Write-Success "OIDC federated credential created"
        } finally {
            # Clean up temp file
            if (Test-Path $tempJsonFile) {
                Remove-Item $tempJsonFile -Force
            }
        }
    }

} catch {
    Write-Error "Failed to create Azure AD resources: $($_.Exception.Message)"
    exit 1
}

# Deploy Azure resources via Bicep
Write-StepHeader "Deploying Azure Resources"

try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $bicepFile = Join-Path $scriptPath "deploy-azure-resources-simple.bicep"

    if (-not (Test-Path $bicepFile)) {
        throw "Bicep template not found: $bicepFile"
    }

    Write-Info "Deploying Bicep template: $bicepFile"
    Write-Info "Using location: $Location"

    $deploymentParams = @{
        ResourceGroupName = $ResourceGroupName
        TemplateFile = $bicepFile
        keyVaultName = "kv-easypim-$(Get-Random -Maximum 9999)"
        location = $Location
        currentUserObjectId = $currentUser.Id
        servicePrincipalObjectId = $spObjectId
        environmentSuffix = "test"
    }

    $deployment = New-AzResourceGroupDeployment @deploymentParams -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Success "Bicep deployment completed successfully"
    } else {
        throw "Bicep deployment failed with state: $($deployment.ProvisioningState)"
    }

} catch {
    Write-Error "Azure resources deployment failed: $($_.Exception.Message)"
    exit 1
}

# Configure RBAC assignments
Write-StepHeader "Configuring RBAC Assignments"

try {
    # Get Key Vault name from deployment output
    $keyVaultName = $deployment.Outputs.keyVaultName.Value

    Write-Info "Configuring RBAC for Key Vault: $keyVaultName"

    # Key Vault Secrets User role for service principal
    $keyVaultResource = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $ResourceGroupName
    $secretsUserRoleId = "4633458b-17de-408a-b874-0445c86b69e6"

    try {
        New-AzRoleAssignment -ObjectId $spObjectId -RoleDefinitionId $secretsUserRoleId -Scope $keyVaultResource.ResourceId -ErrorAction SilentlyContinue
        Write-Success "Key Vault Secrets User role assigned to service principal"
    } catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Info "Key Vault role assignment already exists"
        } else {
            throw
        }
    }

    # Contributor role for service principal (for EasyPIM operations)
    $contributorRoleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"

    try {
        New-AzRoleAssignment -ObjectId $spObjectId -RoleDefinitionId $contributorRoleId -Scope "/subscriptions/$($azAccount.id)/resourceGroups/$ResourceGroupName" -ErrorAction SilentlyContinue
        Write-Success "Contributor role assigned to service principal"
    } catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Info "Contributor role assignment already exists"
        } else {
            throw
        }
    }

} catch {
    Write-Error "RBAC configuration failed: $($_.Exception.Message)"
    exit 1
}

# Display results and next steps
Write-StepHeader "Deployment Complete"

Write-Success "All resources deployed successfully!"

Write-Host "`n" -NoNewline
Write-ColorOutput "📋 GitHub Repository Secrets" "Yellow"
Write-ColorOutput ("=" * 40) "Yellow"

$gitHubSecrets = @{
    "AZURE_CLIENT_ID" = $appId
    "AZURE_TENANT_ID" = $azAccount.tenantId
    "AZURE_SUBSCRIPTION_ID" = $azAccount.id
}

$gitHubVariables = @{
    "AZURE_RESOURCE_GROUP" = $ResourceGroupName
    "AZURE_KEYVAULT_NAME" = $keyVaultName
    "AZURE_KEYVAULT_SECRET_NAME" = "easypim-config-json"
    "AZURE_KEY_VAULT_URI" = $deployment.Outputs.keyVaultUri.Value
}

foreach ($secret in $gitHubSecrets.GetEnumerator()) {
    Write-Host "$($secret.Key): " -NoNewline -ForegroundColor White
    Write-Host $secret.Value -ForegroundColor Cyan
}

Write-Host "`n" -NoNewline
Write-ColorOutput "📋 GitHub Repository Variables" "Yellow"
Write-ColorOutput ("=" * 40) "Yellow"

foreach ($variable in $gitHubVariables.GetEnumerator()) {
    Write-Host "$($variable.Key): " -NoNewline -ForegroundColor White
    Write-Host $variable.Value -ForegroundColor Cyan
}

Write-Host "`n" -NoNewline
Write-ColorOutput "🚀 Next Steps" "Green"
Write-ColorOutput ("=" * 40) "Green"

Write-Info "1. Add the above secrets to your GitHub repository:"
Write-Info "   Repository Settings → Secrets and variables → Actions → Secrets → New repository secret"
Write-Info "2. Add the above variables to your GitHub repository:"
Write-Info "   Repository Settings → Secrets and variables → Actions → Variables → New repository variable"
Write-Info "3. Grant admin consent for the Azure AD application API permissions"
Write-Info "4. Test the CI/CD pipeline with the 01-auth-test.yml workflow"
Write-Info "5. Review the comprehensive guide: docs/Step-by-Step-Guide.md"

Write-Host "`n" -NoNewline
Write-ColorOutput "✨ Deployment Summary" "Magenta"
Write-ColorOutput ("=" * 40) "Magenta"
Write-Info "• Azure AD Application: $ApplicationName ($appId)"
Write-Info "• Resource Group: $ResourceGroupName"
Write-Info "• Key Vault: $keyVaultName"
Write-Info "• OIDC Federation: Configured for $GitHubRepository (branch: $BranchName)"
Write-Info "• RBAC: Service principal has required permissions"

Write-Host "`n" -NoNewline
Write-ColorOutput "🎉 Ready for EasyPIM CI/CD Testing!" "Green"
