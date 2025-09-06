#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Trigger EasyPIM Policy Drift Detection workflow via GitHub CLI

.DESCRIPTION
    This script provides an easy way to trigger the EasyPIM Policy Drift Detection workflow
    with various parameters using GitHub CLI.

.PARAMETER Verbose
    Enable verbose output for detailed drift detection information

.PARAMETER ConfigSecretName
    Name of the Key Vault secret containing the configuration (optional - uses repository default if not provided)

.PARAMETER Repository
    GitHub repository in format 'owner/repo' (default: 'kayasax/EasyPIM-EventDriven-Governance')

.EXAMPLE
    # Basic drift detection run
    .\Invoke-DriftDetection.ps1

.EXAMPLE
    # Verbose drift detection
    .\Invoke-DriftDetection.ps1 -Verbose $true

.EXAMPLE
    # Test environment drift detection
    .\Invoke-DriftDetection.ps1 -ConfigSecretName "pim-config-test" -Verbose $true

.EXAMPLE
    # Production environment drift detection
    .\Invoke-DriftDetection.ps1 -ConfigSecretName "pim-config-prod"

.EXAMPLE
    # Different repository
    .\Invoke-DriftDetection.ps1 -Repository "myorg/my-easypim-repo" -Verbose $true
#>

param(
    [bool]$Verbose = $false,

    [string]$ConfigSecretName = "",

    [string]$Repository = "kayasax/EasyPIM-EventDriven-Governance"
)

# Check if GitHub CLI is installed
try {
    $ghVersion = gh --version
    Write-Host "✅ GitHub CLI found: $($ghVersion[0])" -ForegroundColor Green
} catch {
    Write-Error "❌ GitHub CLI not found. Please install it first: winget install --id GitHub.cli"
    exit 1
}

# Check authentication
try {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ GitHub CLI not authenticated. Please run: gh auth login"
        exit 1
    }
    Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
} catch {
    Write-Error "❌ GitHub CLI authentication check failed. Please run: gh auth login"
    exit 1
}

# Display configuration
Write-Host "`n🔍 EasyPIM Policy Drift Detection Trigger" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host "Repository: $Repository" -ForegroundColor White
Write-Host "Parameters:" -ForegroundColor Yellow
Write-Host "  Verbose: $Verbose" -ForegroundColor White
if ($ConfigSecretName) {
    Write-Host "  ConfigSecretName: $ConfigSecretName" -ForegroundColor White
    Write-Host "  Configuration Source: Specific secret" -ForegroundColor Green
} else {
    Write-Host "  Configuration Source: Repository default" -ForegroundColor Blue
}

Write-Host "`n📊 Drift detection will compare current PIM state with configuration" -ForegroundColor Yellow

# Confirm execution
$confirm = Read-Host "`nDo you want to trigger the drift detection workflow? (y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "❌ Operation cancelled by user" -ForegroundColor Yellow
    exit 0
}

# Trigger workflow
Write-Host "`n🔄 Triggering drift detection workflow..." -ForegroundColor Cyan

try {
    $workflowParams = @(
        "--repo", $Repository,
        "-f", "Verbose=$Verbose"
    )

    if ($ConfigSecretName) {
        $workflowParams += @("-f", "configSecretName=$ConfigSecretName")
    }

    gh workflow run "03-policy-drift-check.yml" @workflowParams | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Drift detection workflow triggered successfully!" -ForegroundColor Green

        # Wait a moment for the workflow to start
        Start-Sleep -Seconds 3

        # Try to show the latest run
        Write-Host "`n📋 Checking workflow runs..." -ForegroundColor Cyan
        try {
            $runs = gh run list --repo $Repository --workflow="03-policy-drift-check.yml" --limit=3 --json status,conclusion,createdAt,url | ConvertFrom-Json
            if ($runs.Count -gt 0) {
                Write-Host "Latest runs:" -ForegroundColor Yellow
                foreach ($run in $runs) {
                    $status = if ($run.status -eq "completed") { $run.conclusion } else { $run.status }
                    $color = switch ($status) {
                        "success" { "Green" }
                        "failure" { "Red" }
                        "in_progress" { "Yellow" }
                        "queued" { "Cyan" }
                        default { "White" }
                    }
                    $createdAt = [DateTime]::Parse($run.createdAt).ToString("yyyy-MM-dd HH:mm:ss")
                    Write-Host "  $createdAt - Status: $status - URL: $($run.url)" -ForegroundColor $color
                }
            }
        } catch {
            Write-Host "Could not retrieve workflow runs (this is normal)" -ForegroundColor DarkGray
        }

        Write-Host "`n🎉 Monitor the workflow progress in GitHub Actions!" -ForegroundColor Green
        Write-Host "💡 Check for policy drift reports in the workflow output" -ForegroundColor Cyan

    } else {
        Write-Error "❌ Failed to trigger workflow (exit code: $LASTEXITCODE)"
        exit 1
    }

} catch {
    Write-Error "❌ Error triggering workflow: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n✨ Drift detection workflow triggered successfully!" -ForegroundColor Green
