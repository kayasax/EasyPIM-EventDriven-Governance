#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Az.Functions"; ModuleVersion="4.0.0" }

<#
.SYNOPSIS
    🚀 EasyPIM Dual Platform Setup - Intelligent Event-Driven Governance
    
.DESCRIPTION
    Configures EasyPIM with intelligent dual-platform routing between GitHub Actions and Azure DevOps.
    Automatically sets up smart routing based on Key Vault secret naming patterns.
    
.PARAMETER Platform
    Platform to configure: 'GitHub', 'AzureDevOps', or 'Both' (default)
    
.EXAMPLE
    # 🚀 Complete dual platform setup (recommended)
    .\scripts\setup-platform.ps1
    
.EXAMPLE
    # 📘 GitHub Actions only
    .\scripts\setup-platform.ps1 -Platform GitHub
    
.EXAMPLE
    # �� Azure DevOps only  
    .\scripts\setup-platform.ps1 -Platform AzureDevOps
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('GitHub', 'AzureDevOps', 'Both')]
    [string]$Platform = 'Both',
    
    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName = 'easypimAKV2GH',
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'rg-easypim-cicd-test'
)

# 🎨 UI Functions
function Write-Header {
    param([string]$Text, [string]$Color = "Cyan")
    Write-Host "`n🚀 " -ForegroundColor Yellow -NoNewline
    Write-Host $Text -ForegroundColor $Color
    Write-Host ("=" * ($Text.Length + 3)) -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ " -ForegroundColor Green -NoNewline
    Write-Host $Text -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️ " -ForegroundColor Blue -NoNewline
    Write-Host $Text -ForegroundColor Cyan
}

# 📘 GitHub Functions
function Setup-GitHub {
    Write-Header "GitHub Actions Setup" "Blue"
    
    Write-Info "GitHub Personal Access Token required with permissions: repo, workflow, actions:read"
    $githubToken = Read-Host "Enter GitHub Personal Access Token" -AsSecureString
    $githubTokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($githubToken))
    
    $githubRepo = Read-Host "Enter GitHub repository (format: owner/repo)"
    
    try {
        Update-AzFunctionAppSetting -ResourceGroupName $ResourceGroupName -Name $FunctionAppName -AppSetting @{
            GITHUB_TOKEN = $githubTokenPlain
            GITHUB_REPOSITORY = $githubRepo
        }
        Write-Success "GitHub Actions configuration completed!"
        return $true
    }
    catch {
        Write-Error "Failed to configure GitHub Actions: $($_.Exception.Message)"
        return $false
    }
}

# 🔷 Azure DevOps Functions
function Setup-AzureDevOps {
    Write-Header "Azure DevOps Setup" "Magenta"
    
    $adoOrg = Read-Host "Enter Azure DevOps Organization name"
    $adoProject = Read-Host "Enter Azure DevOps Project name"
    $adoPipelineId = Read-Host "Enter Azure DevOps Pipeline ID (numeric)"
    
    Write-Info "Azure DevOps PAT required with permissions: Build (read & execute), Code (read), Project and Team (read)"
    $adoPat = Read-Host "Enter Azure DevOps Personal Access Token" -AsSecureString
    $adoPatPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adoPat))
    
    try {
        Update-AzFunctionAppSetting -ResourceGroupName $ResourceGroupName -Name $FunctionAppName -AppSetting @{
            ADO_ORGANIZATION = $adoOrg
            ADO_PROJECT = $adoProject
            ADO_PIPELINE_ID = $adoPipelineId
            ADO_PAT = $adoPatPlain
        }
        Write-Success "Azure DevOps configuration completed!"
        return $true
    }
    catch {
        Write-Error "Failed to configure Azure DevOps: $($_.Exception.Message)"
        return $false
    }
}

# 🚀 Main Logic
Clear-Host
Write-Header "EasyPIM Dual Platform Setup" "Yellow"
Write-Host "Intelligent Event-Driven Governance with Smart Routing" -ForegroundColor Gray

# Validate Azure connection
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Please run 'Connect-AzAccount' first."
        exit 1
    }
    Write-Info "Connected to Azure: $($context.Account.Id)"
}
catch {
    Write-Error "Failed to get Azure context: $($_.Exception.Message)"
    exit 1
}

# Platform setup
$githubSuccess = $false
$adoSuccess = $false

switch ($Platform) {
    'GitHub' { $githubSuccess = Setup-GitHub }
    'AzureDevOps' { $adoSuccess = Setup-AzureDevOps }
    'Both' { 
        $githubSuccess = Setup-GitHub
        $adoSuccess = Setup-AzureDevOps
    }
}

# Summary
Write-Header "🎯 Setup Complete!" "Green"
if ($githubSuccess -and $adoSuccess) {
    Write-Success "Both platforms configured! Smart routing is active."
} elseif ($githubSuccess) {
    Write-Success "GitHub Actions configured!"
} elseif ($adoSuccess) {
    Write-Success "Azure DevOps configured!"
}

Write-Host "`n📖 Complete documentation: docs/Dual-Platform-Setup-Guide.md" -ForegroundColor Yellow
