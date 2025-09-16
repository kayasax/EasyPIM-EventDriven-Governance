# EasyPIM Repository Cleanup Script
# This script removes all the temporary/duplicate files and restores the clean repository structure

param(
    [switch]$DryRun = $false
)

Write-Host "🧹 EasyPIM Repository Cleanup Script" -ForegroundColor Cyan
Write-Host "This will remove temporary files and restore clean repository structure" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "⚠️ DRY RUN MODE - No files will be deleted" -ForegroundColor Yellow
}

# Define files/folders that should be KEPT (clean repository structure)
$keepItems = @(
    ".git",
    ".github",
    ".gitignore",
    "docs",
    "scripts", 
    "templates",
    "LICENSE",
    "README.md"
)

# Define additional files that should be kept in specific folders
$keepInScripts = @(
    "configure-github-cicd.ps1",
    "deploy-azure-resources.bicep", 
    "deploy-azure-resources.parameters.json",
    "deploy-azure-resources.ps1",
    "grant-subscription-owner.ps1",
    "grant-required-permissions.ps1",
    "setup-platform.ps1",
    "configure-cicd.ps1", 
    "deploy-azure-resources-enhanced.ps1",
    "Invoke-OrchestratorWorkflow.ps1",
    "README.md"
)

$keepInScriptsWorkflows = @(
    "Apply-EasyPIMTelemetryHotpatch.ps1",
    "Install-EasyPIMModules.ps1", 
    "Invoke-EasyPIMDriftDetection.ps1",
    "Invoke-EasyPIMExecution.ps1",
    "Setup-EasyPIMAuthentication.ps1",
    "Test-UltimateTelemetry.ps1"
)

$keepInDocs = @(
    "Step-by-Step-Guide.md",
    "GitHub-Actions-Guide.md",
    "Platform-Setup-Guide.md",
    "Azure-DevOps-Guide.md"
)

# Get all items in root directory
$rootItems = Get-ChildItem -Path "." | Where-Object { $_.Name -notin $keepItems }

Write-Host "🔍 Found $($rootItems.Count) items to potentially remove from root:" -ForegroundColor Yellow

foreach ($item in $rootItems) {
    Write-Host "   ❌ $($item.Name)" -ForegroundColor Red
}

if (-not $DryRun) {
    $confirm = Read-Host "`n⚠️ This will DELETE $($rootItems.Count) files/folders from the root directory. Continue? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "❌ Cleanup cancelled by user" -ForegroundColor Red
        exit 0
    }
}

# Remove unwanted root items
$removed = 0
foreach ($item in $rootItems) {
    if (-not $DryRun) {
        try {
            if ($item.PSIsContainer) {
                Remove-Item -Path $item.FullName -Recurse -Force
            } else {
                Remove-Item -Path $item.FullName -Force
            }
            Write-Host "   ✅ Removed: $($item.Name)" -ForegroundColor Green
            $removed++
        } catch {
            Write-Host "   ❌ Failed to remove $($item.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   [DRY RUN] Would remove: $($item.Name)" -ForegroundColor Yellow
        $removed++
    }
}

# Check and clean scripts directory
if (Test-Path "scripts") {
    $scriptsItems = Get-ChildItem -Path "scripts" | Where-Object { $_.Name -notin $keepInScripts -and $_.Name -ne "workflows" }
    if ($scriptsItems.Count -gt 0) {
        Write-Host "`n🔍 Found $($scriptsItems.Count) extra items in scripts directory:" -ForegroundColor Yellow
        foreach ($item in $scriptsItems) {
            if (-not $DryRun) {
                try {
                    if ($item.PSIsContainer) {
                        Remove-Item -Path $item.FullName -Recurse -Force
                    } else {
                        Remove-Item -Path $item.FullName -Force  
                    }
                    Write-Host "   ✅ Removed scripts/$($item.Name)" -ForegroundColor Green
                    $removed++
                } catch {
                    Write-Host "   ❌ Failed to remove scripts/$($item.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "   [DRY RUN] Would remove: scripts/$($item.Name)" -ForegroundColor Yellow
                $removed++
            }
        }
    }
    
    # Check scripts/workflows directory
    if (Test-Path "scripts/workflows") {
        $workflowItems = Get-ChildItem -Path "scripts/workflows" | Where-Object { $_.Name -notin $keepInScriptsWorkflows }
        if ($workflowItems.Count -gt 0) {
            Write-Host "`n🔍 Found $($workflowItems.Count) extra items in scripts/workflows directory:" -ForegroundColor Yellow
            foreach ($item in $workflowItems) {
                if (-not $DryRun) {
                    try {
                        if ($item.PSIsContainer) {
                            Remove-Item -Path $item.FullName -Recurse -Force
                        } else {
                            Remove-Item -Path $item.FullName -Force
                        }
                        Write-Host "   ✅ Removed scripts/workflows/$($item.Name)" -ForegroundColor Green
                        $removed++
                    } catch {
                        Write-Host "   ❌ Failed to remove scripts/workflows/$($item.Name): $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "   [DRY RUN] Would remove: scripts/workflows/$($item.Name)" -ForegroundColor Yellow
                    $removed++
                }
            }
        }
    }
}

# Check and clean docs directory
if (Test-Path "docs") {
    $docsItems = Get-ChildItem -Path "docs" | Where-Object { $_.Name -notin $keepInDocs }
    if ($docsItems.Count -gt 0) {
        Write-Host "`n🔍 Found $($docsItems.Count) extra items in docs directory:" -ForegroundColor Yellow
        foreach ($item in $docsItems) {
            if (-not $DryRun) {
                try {
                    if ($item.PSIsContainer) {
                        Remove-Item -Path $item.FullName -Recurse -Force
                    } else {
                        Remove-Item -Path $item.FullName -Force
                    }
                    Write-Host "   ✅ Removed docs/$($item.Name)" -ForegroundColor Green
                    $removed++
                } catch {
                    Write-Host "   ❌ Failed to remove docs/$($item.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "   [DRY RUN] Would remove: docs/$($item.Name)" -ForegroundColor Yellow
                $removed++
            }
        }
    }
}

# Check and clean templates directory (remove everything - this should be clean Azure DevOps templates only)
if (Test-Path "templates") {
    $templateItems = Get-ChildItem -Path "templates"
    Write-Host "`n🔍 Checking templates directory..." -ForegroundColor Yellow
    Write-Host "   Found $($templateItems.Count) items in templates directory" -ForegroundColor Gray
    
    # For now, let's leave templates alone and let user decide what to keep
    Write-Host "   ⚠️ Templates directory left unchanged - please review manually" -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
if (-not $DryRun) {
    Write-Host "✅ Repository cleanup completed!" -ForegroundColor Green
    Write-Host "   Removed $removed items" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Clean repository structure restored:" -ForegroundColor Cyan
    Write-Host "   ├── .github/ (workflows)" -ForegroundColor White
    Write-Host "   ├── docs/ (documentation)" -ForegroundColor White  
    Write-Host "   ├── scripts/ (deployment scripts)" -ForegroundColor White
    Write-Host "   │   └── workflows/ (PowerShell workflow scripts)" -ForegroundColor White
    Write-Host "   ├── templates/ (Azure DevOps pipeline templates)" -ForegroundColor White
    Write-Host "   ├── LICENSE" -ForegroundColor White
    Write-Host "   └── README.md" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 Your repository is now clean and organized!" -ForegroundColor Green
} else {
    Write-Host "📊 Dry run completed - would have removed $removed items" -ForegroundColor Cyan
    Write-Host "   Run without -DryRun to actually clean the repository" -ForegroundColor White
}
