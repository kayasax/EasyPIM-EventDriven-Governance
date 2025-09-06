# EasyPIM Event-Driven Governance - Platform Setup Orchestrator
# This script guides users through platform selection and automated setup

param(
    [Parameter(Mandatory = $false)]
    [switch]$Interactive = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet("GitHub", "AzureDevOps", "Both")]
    [string]$Platform,

    [Parameter(Mandatory = $false)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsOrganization,

    [Parameter(Mandatory = $false)]
    [string]$AzureDevOpsProject,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim-cicd-test",

    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Display banner
function Show-Banner {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                     🚀 EasyPIM Event-Driven Governance                       ║
║                           Platform Setup Orchestrator                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

Welcome to the EasyPIM Event-Driven Governance setup wizard!
This tool will help you deploy Azure resources and configure your chosen CI/CD platform.

"@ -ForegroundColor Cyan
}

# Display help and usage
function Show-Usage {
    Write-Host @"
🚀 EasyPIM Event-Driven Governance - Platform Setup Orchestrator
===============================================================

USAGE:
  .\setup-platform.ps1 [options]

PARAMETERS:
  -Platform              CI/CD platform to configure
                         Options: GitHub, AzureDevOps, Both

  -Interactive           Enable interactive mode (default: true)
                         Use -Interactive:`$false for non-interactive setup

  -GitHubRepository      GitHub repository in format 'owner/repo'
                         Required when Platform is GitHub or Both

  -AzureDevOpsOrganization  Azure DevOps organization name
                           Required when Platform is AzureDevOps or Both

  -AzureDevOpsProject    Azure DevOps project name
                         Required when Platform is AzureDevOps or Both

  -ResourceGroupName     Azure resource group name (default: rg-easypim-cicd-test)

  -Location              Azure location (default: East US)

  -WhatIf                Preview deployment without making changes

  -Force                 Skip confirmation prompts

  -Help                  Show this help message

EXAMPLES:
  # Interactive setup (recommended)
  .\setup-platform.ps1

  # Preview deployment
  .\setup-platform.ps1 -WhatIf

  # Non-interactive GitHub setup
  .\setup-platform.ps1 -Interactive:`$false -Platform GitHub -GitHubRepository "contoso/easypim"

  # Non-interactive Azure DevOps setup
  .\setup-platform.ps1 -Interactive:`$false -Platform AzureDevOps -AzureDevOpsOrganization "contoso" -AzureDevOpsProject "EasyPIM"

  # Setup both platforms
  .\setup-platform.ps1 -Platform Both -GitHubRepository "contoso/easypim" -AzureDevOpsOrganization "contoso" -AzureDevOpsProject "EasyPIM"

PREREQUISITES:
  • Azure CLI authenticated (az login)
  • For GitHub: GitHub CLI authenticated (gh auth login)
  • For Azure DevOps: Azure DevOps CLI extension (auto-installed)
  • Appropriate permissions on target repositories/projects

"@ -ForegroundColor Cyan
}

# Interactive platform selection
function Select-Platform {
    if ($Platform) {
        Write-Host "✅ Platform pre-selected: $Platform" -ForegroundColor Green
        return $Platform
    }

    Write-Host "🎯 Platform Selection" -ForegroundColor Yellow
    Write-Host "Please choose your CI/CD platform:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. GitHub Actions (recommended for open source projects)" -ForegroundColor White
    Write-Host "2. Azure DevOps (recommended for enterprise environments)" -ForegroundColor White
    Write-Host "3. Both platforms (maximum flexibility)" -ForegroundColor White
    Write-Host ""

    do {
        $choice = Read-Host "Enter your choice (1-3)"
        switch ($choice) {
            "1" { return "GitHub" }
            "2" { return "AzureDevOps" }
            "3" { return "Both" }
            default {
                Write-Host "❌ Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
            }
        }
    } while ($true)
}

# Get GitHub repository information
function Get-GitHubInfo {
    param([string]$ExistingRepo)

    if ($ExistingRepo) {
        Write-Host "✅ GitHub repository pre-configured: $ExistingRepo" -ForegroundColor Green
        return $ExistingRepo
    }

    Write-Host "`n📋 GitHub Repository Configuration" -ForegroundColor Yellow
    Write-Host "Please provide your GitHub repository information:" -ForegroundColor White
    Write-Host "Format: owner/repository (e.g., contoso/easypim-governance)" -ForegroundColor Gray

    do {
        $repo = Read-Host "GitHub Repository"
        if ($repo -match "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$") {
            return $repo
        } else {
            Write-Host "❌ Invalid format. Please use 'owner/repository' format." -ForegroundColor Red
        }
    } while ($true)
}

# Get Azure DevOps information
function Get-AzureDevOpsInfo {
    param(
        [string]$ExistingOrg,
        [string]$ExistingProject
    )

    $org = $ExistingOrg
    $project = $ExistingProject

    if (-not $org) {
        Write-Host "`n📋 Azure DevOps Organization Configuration" -ForegroundColor Yellow
        Write-Host "Please provide your Azure DevOps organization name:" -ForegroundColor White
        Write-Host "Example: If your URL is https://dev.azure.com/contoso, enter 'contoso'" -ForegroundColor Gray

        do {
            $org = Read-Host "Azure DevOps Organization"
            if ($org -and $org.Length -gt 0) {
                break
            } else {
                Write-Host "❌ Organization name cannot be empty." -ForegroundColor Red
            }
        } while ($true)
    } else {
        Write-Host "✅ Azure DevOps organization pre-configured: $org" -ForegroundColor Green
    }

    if (-not $project) {
        Write-Host "`nPlease provide your Azure DevOps project name:" -ForegroundColor White
        Write-Host "Example: EasyPIM or MyGovernanceProject" -ForegroundColor Gray

        do {
            $project = Read-Host "Azure DevOps Project"
            if ($project -and $project.Length -gt 0) {
                break
            } else {
                Write-Host "❌ Project name cannot be empty." -ForegroundColor Red
            }
        } while ($true)
    } else {
        Write-Host "✅ Azure DevOps project pre-configured: $project" -ForegroundColor Green
    }

    return @{
        Organization = $org
        Project = $project
    }
}

# Get Azure configuration
function Get-AzureConfig {
    param(
        [string]$ExistingRG,
        [string]$ExistingLocation
    )

    $rg = if ($ExistingRG) { $ExistingRG } else { "rg-easypim-cicd-test" }
    $loc = if ($ExistingLocation) { $ExistingLocation } else { "East US" }

    Write-Host "`n📋 Azure Configuration" -ForegroundColor Yellow
    Write-Host "Current configuration:" -ForegroundColor White
    Write-Host "• Resource Group: $rg" -ForegroundColor Gray
    Write-Host "• Location: $loc" -ForegroundColor Gray

    if ($Interactive) {
        $changeConfig = Read-Host "Do you want to change these settings? (y/N)"
        if ($changeConfig -match "^[Yy]") {
            $newRg = Read-Host "Resource Group Name [$rg]"
            if ($newRg) { $rg = $newRg }

            $newLoc = Read-Host "Azure Location [$loc]"
            if ($newLoc) { $loc = $newLoc }
        }
    }

    return @{
        ResourceGroup = $rg
        Location = $loc
    }
}

# Display configuration summary
function Show-ConfigSummary {
    param(
        [string]$Platform,
        [string]$GitHubRepo,
        [hashtable]$AdoInfo,
        [hashtable]$AzureConfig
    )

    Write-Host "`n📋 Configuration Summary" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "Platform: $Platform" -ForegroundColor White

    if ($GitHubRepo) {
        Write-Host "GitHub Repository: $GitHubRepo" -ForegroundColor White
    }

    if ($AdoInfo) {
        Write-Host "Azure DevOps: $($AdoInfo.Organization)/$($AdoInfo.Project)" -ForegroundColor White
    }

    Write-Host "Resource Group: $($AzureConfig.ResourceGroup)" -ForegroundColor White
    Write-Host "Location: $($AzureConfig.Location)" -ForegroundColor White
    Write-Host "What-If Mode: $($WhatIf.IsPresent)" -ForegroundColor White
    Write-Host "═══════════════════════════════════════" -ForegroundColor Yellow
}

# Execute deployment phase
function Invoke-DeploymentPhase {
    param(
        [string]$Platform,
        [hashtable]$AzureConfig,
        [bool]$WhatIfMode
    )

    Write-Host "`n🚀 Phase 1: Azure Resources Deployment" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta

    # Build parameters hashtable for splatting
    $deployParams = @{
        TargetPlatform = $Platform
        ResourceGroupName = $AzureConfig.ResourceGroup
        Location = $AzureConfig.Location
    }

    if ($WhatIfMode) {
        $deployParams.WhatIf = $true
    }

    if ($Force) {
        $deployParams.Force = $true
    }

    Write-Host "Executing: .\scripts\deploy-azure-resources-enhanced.ps1 with parameters:" -ForegroundColor Gray
    foreach ($param in $deployParams.GetEnumerator()) {
        Write-Host "   -$($param.Key): $($param.Value)" -ForegroundColor Gray
    }

    try {
        & ".\scripts\deploy-azure-resources-enhanced.ps1" @deployParams
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Phase 1 completed successfully!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Phase 1 failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Phase 1 failed: $_" -ForegroundColor Red
        return $false
    }
}

# Execute configuration phase
function Invoke-ConfigurationPhase {
    param(
        [string]$Platform,
        [string]$GitHubRepo,
        [hashtable]$AdoInfo,
        [hashtable]$AzureConfig
    )

    if ($WhatIf) {
        Write-Host "`n📋 Phase 2: CI/CD Configuration (Skipped in What-If mode)" -ForegroundColor Yellow
        Write-Host "In real deployment, this phase would configure:" -ForegroundColor Gray
        Write-Host "• Platform secrets and variables" -ForegroundColor Gray
        Write-Host "• Service connections and permissions" -ForegroundColor Gray
        Write-Host "• Repository configuration" -ForegroundColor Gray
        return $true
    }

    Write-Host "`n🔧 Phase 2: CI/CD Configuration" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta

    # Build parameters hashtable for splatting
    $configParams = @{
        Platform = $Platform
        ResourceGroupName = $AzureConfig.ResourceGroup
    }

    if ($GitHubRepo) {
        $configParams.GitHubRepository = $GitHubRepo
    }

    if ($AdoInfo) {
        $configParams.AzureDevOpsOrganization = $AdoInfo.Organization
        $configParams.AzureDevOpsProject = $AdoInfo.Project
    }

    if ($Force) {
        $configParams.Force = $true
    }

    Write-Host "Executing: .\scripts\configure-cicd.ps1 with parameters:" -ForegroundColor Gray
    foreach ($param in $configParams.GetEnumerator()) {
        Write-Host "   -$($param.Key): $($param.Value)" -ForegroundColor Gray
    }

    try {
        & ".\scripts\configure-cicd.ps1" @configParams
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Phase 2 completed successfully!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Phase 2 failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Phase 2 failed: $_" -ForegroundColor Red
        return $false
    }
}

# Display final instructions
function Show-FinalInstructions {
    param(
        [string]$Platform,
        [string]$GitHubRepo,
        [hashtable]$AdoInfo
    )

    Write-Host "`n🎉 Setup Completed Successfully!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green

    Write-Host "`n✅ What's been configured:" -ForegroundColor Yellow
    Write-Host "• Azure resources deployed and configured" -ForegroundColor White
    Write-Host "• CI/CD platform secrets and variables set" -ForegroundColor White
    Write-Host "• Event Grid integration ready" -ForegroundColor White
    Write-Host "• Azure Function deployed and configured" -ForegroundColor White

    Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow

    if ($Platform -eq "GitHub" -or $Platform -eq "Both") {
        Write-Host "`nGitHub Actions:" -ForegroundColor Cyan
        Write-Host "1. 🔗 Visit: https://github.com/$GitHubRepo/actions" -ForegroundColor White
        Write-Host "2. 🧪 Run 'Phase 1: Authentication Test' workflow" -ForegroundColor White
        Write-Host "3. 📝 Test Key Vault secret triggers" -ForegroundColor White
    }

    if ($Platform -eq "AzureDevOps" -or $Platform -eq "Both") {
        Write-Host "`nAzure DevOps:" -ForegroundColor Cyan
        Write-Host "1. 🔗 Visit: https://dev.azure.com/$($AdoInfo.Organization)/$($AdoInfo.Project)" -ForegroundColor White
        Write-Host "2. 📋 Create pipelines using templates (see integration plan)" -ForegroundColor White
        Write-Host "3. 🧪 Test variable group configuration" -ForegroundColor White
    }

    Write-Host "`n📖 Documentation:" -ForegroundColor Yellow
    Write-Host "• 📘 Step-by-Step Guide: docs/Step-by-Step-Guide.md" -ForegroundColor White
    Write-Host "• 🔄 Azure DevOps Integration: docs/Azure-DevOps-Integration-Plan.md" -ForegroundColor White
    Write-Host "• 🧪 Testing Guide: Available in repository documentation" -ForegroundColor White

    Write-Host "`n💡 Pro Tips:" -ForegroundColor Cyan
    Write-Host "• Test in a non-production environment first" -ForegroundColor Gray
    Write-Host "• Monitor Azure Function logs for troubleshooting" -ForegroundColor Gray
    Write-Host "• Use What-If mode for production deployments" -ForegroundColor Gray

    Write-Host "`n🎊 Happy Governance! Your EasyPIM Event-Driven system is ready to use." -ForegroundColor Magenta
}

# Main orchestrator execution
function Main {
    Show-Banner

    # Interactive setup if enabled
    if ($Interactive -and -not $Platform) {
        $selectedPlatform = Select-Platform
    } else {
        $selectedPlatform = $Platform
        if (-not $selectedPlatform) {
            Write-Host "❌ Platform must be specified in non-interactive mode" -ForegroundColor Red
            Write-Host "Use -Help for usage information" -ForegroundColor Cyan
            exit 1
        }
    }

    # Gather configuration based on platform
    $githubRepo = $null
    $adoInfo = $null

    if ($selectedPlatform -eq "GitHub" -or $selectedPlatform -eq "Both") {
        $githubRepo = if ($Interactive) { Get-GitHubInfo -ExistingRepo $GitHubRepository } else { $GitHubRepository }
        if (-not $githubRepo) {
            Write-Host "❌ GitHub repository must be specified for GitHub platform" -ForegroundColor Red
            Write-Host "Use -Help for usage information" -ForegroundColor Cyan
            exit 1
        }
    }

    if ($selectedPlatform -eq "AzureDevOps" -or $selectedPlatform -eq "Both") {
        $adoInfo = if ($Interactive) { Get-AzureDevOpsInfo -ExistingOrg $AzureDevOpsOrganization -ExistingProject $AzureDevOpsProject } else { @{ Organization = $AzureDevOpsOrganization; Project = $AzureDevOpsProject } }
        if (-not $adoInfo.Organization -or -not $adoInfo.Project) {
            Write-Host "❌ Azure DevOps organization and project must be specified for Azure DevOps platform" -ForegroundColor Red
            Write-Host "Use -Help for usage information" -ForegroundColor Cyan
            exit 1
        }
    }

    # Azure configuration
    $azureConfig = Get-AzureConfig -ExistingRG $ResourceGroupName -ExistingLocation $Location

    # Show summary
    Show-ConfigSummary -Platform $selectedPlatform -GitHubRepo $githubRepo -AdoInfo $adoInfo -AzureConfig $azureConfig

    # Confirm before proceeding
    if ($Interactive -and -not $Force -and -not $WhatIf) {
        $confirm = Read-Host "`nProceed with this configuration? (y/N)"
        if ($confirm -notmatch "^[Yy]") {
            Write-Host "❌ Setup cancelled by user" -ForegroundColor Red
            exit 0
        }
    }

    # Execute deployment phases
    $phase1Success = Invoke-DeploymentPhase -Platform $selectedPlatform -AzureConfig $azureConfig -WhatIfMode $WhatIf.IsPresent

    if ($phase1Success) {
        $phase2Success = Invoke-ConfigurationPhase -Platform $selectedPlatform -GitHubRepo $githubRepo -AdoInfo $adoInfo -AzureConfig $azureConfig

        if ($phase2Success -or $WhatIf) {
            if (-not $WhatIf) {
                Show-FinalInstructions -Platform $selectedPlatform -GitHubRepo $githubRepo -AdoInfo $adoInfo
            } else {
                Write-Host "`n📋 What-If Summary: All phases would execute successfully" -ForegroundColor Green
                Write-Host "Run without -WhatIf to perform actual deployment" -ForegroundColor Cyan
            }
        } else {
            Write-Host "`n❌ Setup failed during configuration phase" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "`n❌ Setup failed during deployment phase" -ForegroundColor Red
        exit 1
    }
}

# Script entry point
try {
    # Show usage if help requested
    if ($Help -or $args -contains "-h" -or $args -contains "--help" -or $args -contains "-?") {
        Show-Usage
        exit 0
    }

    Main
}
catch {
    Write-Host "`n❌ Orchestrator failed: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
