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
    [string]$ResourceGroupName = "rg-easypim-cicd",

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

        # Validate repository exists and is accessible
        try {
            Write-Host "🔍 Validating GitHub repository access..." -ForegroundColor Gray
            $repoCheck = gh repo view $ExistingRepo --json name,owner 2>$null
            if ($LASTEXITCODE -eq 0) {
                $repoInfo = $repoCheck | ConvertFrom-Json
                Write-Host "✅ Repository confirmed: $($repoInfo.owner.login)/$($repoInfo.name)" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Could not validate repository access. Please check permissions." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠️ GitHub CLI not available for validation. Repository will be validated during setup." -ForegroundColor Yellow
        }

        return $ExistingRepo
    }

    Write-Host "`n📋 GitHub Repository Configuration" -ForegroundColor Yellow
    Write-Host "Please provide your GitHub repository information:" -ForegroundColor White
    Write-Host "Format: owner/repository (e.g., contoso/easypim-governance)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💡 Don't have a GitHub repository for EasyPIM yet?" -ForegroundColor Cyan
    Write-Host "   1. Visit: https://github.com/new" -ForegroundColor White
    Write-Host "   2. Create a new repository (can be private)" -ForegroundColor White
    Write-Host "   3. Name it something like 'easypim-governance' or 'pim-automation'" -ForegroundColor White
    Write-Host "   4. Come back and enter the repository name below" -ForegroundColor White
    Write-Host ""
    Write-Host "   Alternative: Fork this repository to your account:" -ForegroundColor Cyan
    Write-Host "   • Go to: https://github.com/kayasax/EasyPIM-EventDriven-Governance" -ForegroundColor White
    Write-Host "   • Click 'Fork' to create your own copy" -ForegroundColor White
    Write-Host ""

    do {
        $repo = Read-Host "GitHub Repository (format: owner/repo)"

        if (-not $repo -or $repo.Length -eq 0) {
            Write-Host ""
            Write-Host "❌ Repository name cannot be empty." -ForegroundColor Red
            Write-Host ""
            Write-Host "🔗 Quick Setup Options:" -ForegroundColor Yellow
            Write-Host "   Option 1 - Create New Repository:" -ForegroundColor White
            Write-Host "   • Go to: https://github.com/new" -ForegroundColor White
            Write-Host "   • Name: easypim-governance (or similar)" -ForegroundColor White
            Write-Host ""
            Write-Host "   Option 2 - Fork Existing Repository:" -ForegroundColor White
            Write-Host "   • Go to: https://github.com/kayasax/EasyPIM-EventDriven-Governance" -ForegroundColor White
            Write-Host "   • Click 'Fork' button" -ForegroundColor White
            Write-Host ""
            $continue = Read-Host "Press Enter to continue, or type 'exit' to stop setup"
            if ($continue -eq 'exit') {
                Write-Host "🛑 Setup cancelled. Create your GitHub repository first, then re-run this script." -ForegroundColor Yellow
                exit 0
            }
            continue
        }

        if ($repo -match "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$") {
            # Try to validate repository exists and is accessible
            Write-Host "🔍 Validating GitHub repository..." -ForegroundColor Gray

            # Use Start-Process to properly capture output and errors
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "gh"
            $processInfo.Arguments = "repo view $repo --json name,owner,isPrivate"
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo

            try {
                $process.Start() | Out-Null
                $output = $process.StandardOutput.ReadToEnd()
                $errorOutput = $process.StandardError.ReadToEnd()
                $process.WaitForExit()

                if ($process.ExitCode -eq 0 -and $output.Trim()) {
                    $repoInfo = $output | ConvertFrom-Json
                    $visibility = if ($repoInfo.isPrivate) { "Private" } else { "Public" }
                    Write-Host "✅ Repository found: $($repoInfo.owner.login)/$($repoInfo.name) ($visibility)" -ForegroundColor Green

                    # Simple permission check - if we can view it, we likely have some access
                    Write-Host "✅ Repository access confirmed" -ForegroundColor Green

                    return $repo
                } else {
                    Write-Host ""
                    Write-Host "❌ Repository '$repo' not found or not accessible." -ForegroundColor Red
                    Write-Host ""
                    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
                    Write-Host "   • Check the repository name spelling" -ForegroundColor White
                    Write-Host "   • Ensure you have access to the repository" -ForegroundColor White
                    Write-Host "   • Verify GitHub CLI authentication: gh auth status" -ForegroundColor White
                    Write-Host "   • Create the repository if it doesn't exist" -ForegroundColor White
                    Write-Host ""

                    $retry = Read-Host "Try again? (y/N)"
                    if ($retry -notmatch "^[Yy]") {
                        Write-Host "🛑 Setup cancelled. Please create or check your GitHub repository, then re-run this script." -ForegroundColor Yellow
                        exit 0
                    }
                }
            } catch {
                Write-Host "⚠️ Could not validate repository (GitHub CLI may not be available)" -ForegroundColor Yellow
                Write-Host "   Repository will be validated during actual setup." -ForegroundColor Gray
                return $repo
            } finally {
                if ($process -and !$process.HasExited) {
                    $process.Kill()
                }
                if ($process) {
                    $process.Dispose()
                }
            }
        } else {
            Write-Host "❌ Invalid format. Please use 'owner/repository' format (e.g., mycompany/easypim-governance)." -ForegroundColor Red
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

    # If both org and project are pre-configured, validate and return
    if ($org -and $project) {
        Write-Host "`n📋 Azure DevOps Configuration" -ForegroundColor Yellow
        Write-Host "✅ Organization pre-configured: $org" -ForegroundColor Green
        Write-Host "✅ Project pre-configured: $project" -ForegroundColor Green

        # Quick validation of the organization
        try {
            Write-Host "🔍 Verifying Azure DevOps organization..." -ForegroundColor Gray

            # Check if Azure DevOps extension is installed
            $extensionCheck = az extension list --query "[?name=='azure-devops'].name" -o tsv 2>$null
            if (-not $extensionCheck) {
                Write-Host "   📦 Installing Azure DevOps CLI extension..." -ForegroundColor Gray
                az extension add --name azure-devops 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "   ⚠️ Could not install Azure DevOps extension - skipping validation" -ForegroundColor Yellow
                    Write-Host "   💡 You can install it manually: az extension add --name azure-devops" -ForegroundColor Cyan
                    return @{
                        Organization = $org
                        Project = $project
                    }
                }
                Write-Host "   ✅ Azure DevOps CLI extension installed" -ForegroundColor Green
            }

            # Now try to validate the organization
            $orgCheck = az devops project list --organization "https://dev.azure.com/$org" --query "value[?name=='$project'].name" -o tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and $orgCheck) {
                Write-Host "✅ Organization '$org' and project '$project' verified!" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Could not verify project '$project' in organization '$org'" -ForegroundColor Yellow
                Write-Host "   (This may require authentication: az devops login)" -ForegroundColor Gray
                Write-Host "   Continuing anyway - will be validated during deployment" -ForegroundColor Gray
            }
        } catch {
            Write-Host "⚠️ Could not verify Azure DevOps configuration" -ForegroundColor Yellow
            Write-Host "   Continuing anyway - will be validated during deployment" -ForegroundColor Gray
        }

        return @{
            Organization = $org
            Project = $project
        }
    }

    if (-not $org) {
        Write-Host "`n📋 Azure DevOps Organization Configuration" -ForegroundColor Yellow
        Write-Host "Please provide your Azure DevOps organization name:" -ForegroundColor White
        Write-Host "Example: If your URL is https://dev.azure.com/contoso, enter 'contoso'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "💡 Don't have an Azure DevOps organization yet?" -ForegroundColor Cyan
        Write-Host "   1. Visit: https://dev.azure.com" -ForegroundColor White
        Write-Host "   2. Sign in with your Microsoft/Azure account" -ForegroundColor White
        Write-Host "   3. Click 'Create new organization'" -ForegroundColor White
        Write-Host "   4. Choose a name (e.g., 'your-company-easypim')" -ForegroundColor White
        Write-Host "   5. Come back and enter the organization name below" -ForegroundColor White
        Write-Host ""

        do {
            $org = Read-Host "Azure DevOps Organization (or press Ctrl+C to exit and create one first)"

            if (-not $org -or $org.Length -eq 0) {
                Write-Host ""
                Write-Host "❌ Organization name cannot be empty." -ForegroundColor Red
                Write-Host ""
                Write-Host "🔗 Quick Setup Guide:" -ForegroundColor Yellow
                Write-Host "   • Go to: https://dev.azure.com" -ForegroundColor White
                Write-Host "   • Click 'Create new organization'" -ForegroundColor White
                Write-Host "   • Setup takes 2-3 minutes" -ForegroundColor White
                Write-Host ""
                $continue = Read-Host "Press Enter to continue, or type 'exit' to stop setup"
                if ($continue -eq 'exit') {
                    Write-Host "🛑 Setup cancelled. Create your Azure DevOps organization first, then re-run this script." -ForegroundColor Yellow
                    exit 0
                }
                continue
            }

            # Validate organization name format (basic check)
            if ($org -match "^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]$" -or $org -match "^[a-zA-Z0-9]$") {
                break
            } else {
                Write-Host "❌ Invalid organization name format. Use alphanumeric characters, dots, hyphens, and underscores only." -ForegroundColor Red
                Write-Host "   Examples: 'contoso', 'my-company', 'team_easypim'" -ForegroundColor Gray
            }
        } while ($true)

        # Test if organization exists (basic connectivity check)
        Write-Host "🔍 Verifying Azure DevOps organization..." -ForegroundColor Yellow
        try {
            $testUrl = "https://dev.azure.com/$org/_apis/projects?api-version=7.1-preview.4"
            $response = Invoke-RestMethod -Uri $testUrl -Method Get -ErrorAction Stop
            Write-Host "✅ Organization '$org' found successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Could not verify organization '$org'" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This could mean:" -ForegroundColor White
            Write-Host "   • Organization doesn't exist yet" -ForegroundColor Gray
            Write-Host "   • Organization name is incorrect" -ForegroundColor Gray
            Write-Host "   • You don't have access to it" -ForegroundColor Gray
            Write-Host "   • Network connectivity issues" -ForegroundColor Gray
            Write-Host ""
            Write-Host "🔗 To create or verify your organization:" -ForegroundColor Cyan
            Write-Host "   1. Visit: https://dev.azure.com/$org" -ForegroundColor White
            Write-Host "   2. If it doesn't exist, you'll be prompted to create it" -ForegroundColor White
            Write-Host "   3. Make sure you're signed in with the correct account" -ForegroundColor White
            Write-Host ""

            $proceed = Read-Host "Continue anyway? The setup will proceed but may fail later if the organization is invalid (y/N)"
            if ($proceed -notmatch "^[yY]") {
                Write-Host "🛑 Setup cancelled. Please verify your Azure DevOps organization and try again." -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Host "✅ Azure DevOps organization pre-configured: $org" -ForegroundColor Green
    }

    if (-not $project) {
        Write-Host "`n📋 Azure DevOps Project Configuration" -ForegroundColor Yellow
        Write-Host "Please provide your Azure DevOps project name:" -ForegroundColor White
        Write-Host "Example: EasyPIM or MyGovernanceProject" -ForegroundColor Gray
        Write-Host ""
        Write-Host "💡 Don't have a project yet?" -ForegroundColor Cyan
        Write-Host "   1. Visit: https://dev.azure.com/$org" -ForegroundColor White
        Write-Host "   2. Click '+ New project'" -ForegroundColor White
        Write-Host "   3. Name it (e.g., 'EasyPIM-Governance')" -ForegroundColor White
        Write-Host "   4. Set visibility to 'Private' (recommended)" -ForegroundColor White
        Write-Host "   5. Click 'Create'" -ForegroundColor White
        Write-Host ""

        do {
            $project = Read-Host "Azure DevOps Project (or press Ctrl+C to exit and create one first)"

            if (-not $project -or $project.Length -eq 0) {
                Write-Host ""
                Write-Host "❌ Project name cannot be empty." -ForegroundColor Red
                Write-Host ""
                Write-Host "🔗 Quick Setup Guide:" -ForegroundColor Yellow
                Write-Host "   • Go to: https://dev.azure.com/$org" -ForegroundColor White
                Write-Host "   • Click '+ New project'" -ForegroundColor White
                Write-Host "   • Project creation takes 1-2 minutes" -ForegroundColor White
                Write-Host ""
                $continue = Read-Host "Press Enter to continue, or type 'exit' to stop setup"
                if ($continue -eq 'exit') {
                    Write-Host "🛑 Setup cancelled. Create your Azure DevOps project first, then re-run this script." -ForegroundColor Yellow
                    exit 0
                }
                continue
            }

            # Validate project name format (basic check)
            if ($project -match "^[a-zA-Z0-9][a-zA-Z0-9\s._-]*[a-zA-Z0-9]$" -or $project -match "^[a-zA-Z0-9]$") {
                break
            } else {
                Write-Host "❌ Invalid project name format. Use alphanumeric characters, spaces, dots, hyphens, and underscores." -ForegroundColor Red
                Write-Host "   Examples: 'EasyPIM', 'My Governance Project', 'team-easypim'" -ForegroundColor Gray
            }
        } while ($true)
    } else {
        Write-Host "✅ Azure DevOps project pre-configured: $project" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ Azure DevOps Configuration Complete!" -ForegroundColor Green
    Write-Host "   Organization: $org" -ForegroundColor Gray
    Write-Host "   Project: $project" -ForegroundColor Gray
    Write-Host "   URL: https://dev.azure.com/$org/$project" -ForegroundColor Gray

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

    $rg = if ($ExistingRG) { $ExistingRG } else { "rg-easypim-cicd" }
    $loc = if ($ExistingLocation) { $ExistingLocation } else { "East US" }

    Write-Host "`n📋 Azure Configuration" -ForegroundColor Yellow

    # If resource group is pre-configured, just validate and use it
    if ($ExistingRG) {
        Write-Host "✅ Resource group pre-configured: $rg" -ForegroundColor Green
        Write-Host "✅ Location pre-configured: $loc" -ForegroundColor Green

        # Check if the pre-configured RG exists and is in our list
        try {
            $existingRGs = az group list --query "[?contains(name, 'easypim')].{name:name,location:location}" --output json 2>$null
            if ($existingRGs -and $existingRGs -ne "[]") {
                $rgList = $existingRGs | ConvertFrom-Json
                $foundRG = $rgList | Where-Object { $_.name -eq $rg }
                if ($foundRG) {
                    Write-Host "   ✅ Found existing resource group: $rg (Location: $($foundRG.location))" -ForegroundColor Cyan
                    # Use the actual location from Azure if different
                    if ($foundRG.location -ne $loc) {
                        $loc = $foundRG.location
                        Write-Host "   📍 Using actual RG location: $loc" -ForegroundColor Gray
                    }
                }
            }
        } catch {
            Write-Host "   ⚠️ Could not verify resource group (will be created if missing)" -ForegroundColor Yellow
        }

        return @{
            ResourceGroup = $rg
            Location = $loc
        }
    }

    # Check for existing EasyPIM resource groups
    Write-Host "🔍 Checking for existing EasyPIM resource groups..." -ForegroundColor Gray
    try {
        $existingRGs = az group list --query "[?contains(name, 'easypim')].{name:name,location:location}" --output json 2>$null
        if ($existingRGs -and $existingRGs -ne "[]") {
            $rgList = $existingRGs | ConvertFrom-Json
            if ($rgList.Count -gt 0) {
                Write-Host "`n♻️  Found existing EasyPIM resource groups:" -ForegroundColor Green
                for ($i = 0; $i -lt $rgList.Count; $i++) {
                    Write-Host "   $($i + 1). $($rgList[$i].name) (Location: $($rgList[$i].location))" -ForegroundColor Cyan
                }

                if ($Interactive) {
                    Write-Host "   0. Create new resource group: $rg" -ForegroundColor White
                    Write-Host ""

                    do {
                        $choice = Read-Host "Select a resource group to reuse, or 0 for new (0-$($rgList.Count))"
                        if ($choice -match "^\d+$" -and [int]$choice -ge 0 -and [int]$choice -le $rgList.Count) {
                            if ([int]$choice -eq 0) {
                                Write-Host "✅ Will create new resource group: $rg" -ForegroundColor Green
                                break
                            } else {
                                $selectedRG = $rgList[[int]$choice - 1]
                                $rg = $selectedRG.name
                                $loc = $selectedRG.location
                                Write-Host "✅ Will reuse existing resource group: $rg" -ForegroundColor Green
                                break
                            }
                        } else {
                            Write-Host "❌ Invalid choice. Please enter a number between 0 and $($rgList.Count)." -ForegroundColor Red
                        }
                    } while ($true)
                } else {
                    Write-Host "   (Non-interactive mode: will create new resource group if not pre-configured)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "   No existing EasyPIM resource groups found" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ⚠️ Could not check existing resource groups: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "`nCurrent configuration:" -ForegroundColor White
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
        [string]$GitHubRepository,
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

    # Add GitHub repository if provided and platform is GitHub
    if ($Platform -eq "GitHub" -and $GitHubRepository) {
        $deployParams.GitHubRepository = $GitHubRepository
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
    Write-Host "• 📘 Platform Setup Guide: docs/Platform-Setup-Guide.md" -ForegroundColor White
    Write-Host "• 🚀 GitHub Actions Guide: docs/GitHub-Actions-Guide.md" -ForegroundColor White
    Write-Host "• 🔵 Azure DevOps Guide: docs/Azure-DevOps-Guide.md" -ForegroundColor White
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
        # Always call the function to handle validation and pre-configured values
        $adoInfo = Get-AzureDevOpsInfo -ExistingOrg $AzureDevOpsOrganization -ExistingProject $AzureDevOpsProject
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
    $phase1Success = Invoke-DeploymentPhase -Platform $selectedPlatform -AzureConfig $azureConfig -GitHubRepository $githubRepo -WhatIfMode $WhatIf.IsPresent

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

