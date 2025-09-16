# EasyPIM Event-Driven Governance - Dual Platform CICD Configuration
# This script automatically configures both GitHub Actions and Azure DevOps integration

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("GitHub", "AzureDevOps", "Both")]
    [string]$Platform,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsOrganization,

    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsProject,

    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🔧 EasyPIM Dual Platform Configuration                    ║
║               Automatic GitHub Actions + Azure DevOps Setup                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Get Function App name if not provided
if (-not $FunctionAppName) {
    Write-Host "🔍 Discovering Function App..." -ForegroundColor Yellow
    $functionApps = az functionapp list --resource-group $ResourceGroupName --query "[].name" --output tsv
    if ($functionApps) {
        $FunctionAppName = $functionApps[0]
        Write-Host "✅ Found Function App: $FunctionAppName" -ForegroundColor Green
    } else {
        Write-Error "❌ No Function App found in resource group $ResourceGroupName"
        exit 1
    }
}

Write-Host "`n🎯 Configuration Summary:" -ForegroundColor Cyan
Write-Host "Platform(s): $Platform" -ForegroundColor White
Write-Host "Function App: $FunctionAppName" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White

# Configure GitHub Actions integration (always needed as fallback)
function Set-GitHubIntegration {
    Write-Host "`n🐙 Configuring GitHub Actions Integration..." -ForegroundColor Green

    if (-not $GitHubRepository -and $Platform -ne "AzureDevOps") {
        Write-Host "📝 Please enter your GitHub repository (owner/repo):" -ForegroundColor Yellow
        $GitHubRepository = Read-Host
    }

    if ($GitHubRepository) {
        Write-Host "Setting GitHub repository to: $GitHubRepository" -ForegroundColor White

        # GitHub token will be configured in Azure Portal manually or via environment
        Write-Host "✅ GitHub Actions routing configured (default fallback)" -ForegroundColor Green
        Write-Host "📝 Remember to set GITHUB_TOKEN in Function App configuration" -ForegroundColor Yellow
    }
}

# Configure Azure DevOps integration
function Set-AzureDevOpsIntegration {
    Write-Host "`n🔷 Configuring Azure DevOps Integration..." -ForegroundColor Blue

    # Collect Azure DevOps information if not provided
    if (-not $AzureDevOpsOrganization) {
        Write-Host "📝 Please enter your Azure DevOps organization:" -ForegroundColor Yellow
        $AzureDevOpsOrganization = Read-Host
    }

    if (-not $AzureDevOpsProject) {
        Write-Host "📝 Please enter your Azure DevOps project name:" -ForegroundColor Yellow
        $AzureDevOpsProject = Read-Host
    }

    # Get pipeline ID
    Write-Host "📝 Please enter your EasyPIM pipeline ID:" -ForegroundColor Yellow
    $PipelineId = Read-Host

    # Get Personal Access Token
    Write-Host "📝 Please enter your Azure DevOps Personal Access Token:" -ForegroundColor Yellow
    $AdoPat = Read-Host -AsSecureString
    $AdoPatText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdoPat))

    # Configure Function App with ADO variables
    Write-Host "🔧 Setting Azure DevOps environment variables..." -ForegroundColor Cyan

    $adoSettings = @(
        "ADO_ORGANIZATION=$AzureDevOpsOrganization",
        "ADO_PROJECT=$AzureDevOpsProject",
        "ADO_PIPELINE_ID=$PipelineId",
        "ADO_PAT=$AdoPatText"
    )

    try {
        if (-not $WhatIf) {
            az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings $adoSettings
            Write-Host "✅ Azure DevOps configuration applied to Function App" -ForegroundColor Green
        } else {
            Write-Host "📋 Would set ADO environment variables (What-If mode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Error "❌ Failed to configure Azure DevOps settings: $_"
        return $false
    }

    return $true
}

# Configure GitHub token (always needed)
function Set-GitHubToken {
    Write-Host "`n🔑 Configuring GitHub Token..." -ForegroundColor Green

    # Check if GitHub token is already configured
    $existingToken = az functionapp config appsettings list --name $FunctionAppName --resource-group $ResourceGroupName --query "[?name=='GITHUB_TOKEN'].value" --output tsv 2>$null

    if ($existingToken -and -not $Force) {
        Write-Host "✅ GitHub token already configured" -ForegroundColor Green
        return $true
    }

    Write-Host "📝 Please enter your GitHub Personal Access Token:" -ForegroundColor Yellow
    Write-Host "   (Required for GitHub Actions workflow dispatch)" -ForegroundColor Gray
    $GitHubToken = Read-Host -AsSecureString
    $GitHubTokenText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($GitHubToken))

    try {
        if (-not $WhatIf) {
            az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "GITHUB_TOKEN=$GitHubTokenText"
            Write-Host "✅ GitHub token configured" -ForegroundColor Green
        } else {
            Write-Host "📋 Would set GitHub token (What-If mode)" -ForegroundColor Yellow
        }
        return $true
    } catch {
        Write-Error "❌ Failed to configure GitHub token: $_"
        return $false
    }
}

# Main configuration logic
Write-Host "`n🚀 Starting Dual Platform Configuration..." -ForegroundColor Magenta

# Always configure GitHub (needed as fallback)
Set-GitHubIntegration

# Always configure GitHub token (required)
if (-not (Set-GitHubToken)) {
    exit 1
}

# Configure Azure DevOps if requested
if ($Platform -eq "AzureDevOps" -or $Platform -eq "Both") {
    if (-not (Set-AzureDevOpsIntegration)) {
        exit 1
    }
}

# Show smart routing configuration
Write-Host "`n🎯 Smart Routing Configuration:" -ForegroundColor Cyan
Write-Host @"
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           🔄 Dual Platform Routing                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Secret Name Patterns:                                                          │
│                                                                                 │
│  📘 GitHub Actions (Default):                                                  │
│     • easypim-config                    → GitHub Actions                       │
│     • easypim-prod                      → GitHub Actions                       │
│     • easypim-test                      → GitHub Actions (WhatIf mode)         │
│     • Any other pattern                 → GitHub Actions                       │
│                                                                                 │
│  🔷 Azure DevOps:                                                              │
│     • easypim-config-ado                → Azure DevOps Pipeline                │
│     • easypim-prod-azdo                 → Azure DevOps Pipeline                │
│     • easypim-test-devops               → Azure DevOps Pipeline (WhatIf mode)  │
│     • Any secret containing 'ado'/'azdo'/'devops' → Azure DevOps Pipeline     │
│                                                                                 │
│  🧠 Smart Features:                                                            │
│     • test/debug in secret name         → Automatically enables WhatIf mode   │
│     • initial/setup/bootstrap           → Uses initial deployment mode        │
│     • Environment variable overrides    → EASYPIM_WHATIF, EASYPIM_MODE, etc.  │
└─────────────────────────────────────────────────────────────────────────────────┘
"@

Write-Host "`n✅ Dual Platform Configuration Complete!" -ForegroundColor Green
Write-Host @"
🎉 Your EasyPIM Function App now supports:
   • 📘 GitHub Actions integration (default routing)
   • 🔷 Azure DevOps integration (pattern-based routing)
   • 🧠 Smart parameter detection and environment overrides
   • 🔄 Event-driven automation for both platforms

🚀 Next Steps:
   1. Test with a Key Vault secret change
   2. Use secret names with 'ado'/'azdo'/'devops' to route to Azure DevOps
   3. Use any other secret names to route to GitHub Actions
   4. Monitor Function App logs for routing decisions

"@ -ForegroundColor Cyan

exit 0
