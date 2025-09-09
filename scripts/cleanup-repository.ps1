# Repository Cleanup Script
# Creates a clean, customer-ready template from the development repository

param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Write-Host @"
🧹 EasyPIM Repository Cleanup - Customer Template Creation
=========================================================

This script will transform the development repository into a clean,
customer-ready template by removing obsolete scripts and reorganizing files.

"@ -ForegroundColor Cyan

# Define what to keep vs remove
$keepScripts = @(
    "setup-platform.ps1",           # ⭐ MAIN ENTRY POINT
    "configure-cicd.ps1",           # Platform configuration 
    "deploy-azure-resources-enhanced.ps1"  # Azure deployment
)

$keepBicepFiles = @(
    "deploy-azure-resources-working.bicep",
    "deploy-azure-resources-working.parameters.json",
    "deploy-azure-resources-simple.bicep", 
    "deploy-azure-resources-simple.parameters.json"
)

$moveToExamples = @(
    "update-function.ps1",
    "quick-test.ps1",
    "manual-test-guide.ps1"
)

$obsoleteScripts = @(
    "configure-github-cicd.ps1",    # Replaced by configure-cicd.ps1
    "deploy-azure-function.ps1",    # Integrated into enhanced script
    "deploy-azure-resources.ps1",   # Replaced by enhanced version
    "grant-subscription-owner.ps1", # Development script
    "Invoke-DriftDetection.ps1",    # Development script
    "Invoke-OrchestratorWorkflow.ps1", # Development script
    "test-function-parameters.ps1", # Testing script
    "test-multi-environment.ps1",   # Testing script
    "test-validation-and-parameters.ps1" # Testing script
)

$obsoleteBicepFiles = @(
    "deploy-azure-resources.bicep",
    "deploy-azure-resources.parameters.json",
    "deploy-azure-resources-reuse.bicep"
)

if ($WhatIf) {
    Write-Host "`n📋 WHAT-IF MODE - Showing what would be done:" -ForegroundColor Yellow
    
    Write-Host "`n✅ KEEP - Essential Customer Scripts:" -ForegroundColor Green
    foreach ($script in $keepScripts) {
        Write-Host "   📄 $script" -ForegroundColor White
    }
    
    Write-Host "`n🔄 MOVE TO templates/ - Bicep Files:" -ForegroundColor Cyan
    foreach ($file in $keepBicepFiles) {
        Write-Host "   📋 $file" -ForegroundColor White
    }
    
    Write-Host "`n🔄 MOVE TO examples/ - Optional Scripts:" -ForegroundColor Cyan
    foreach ($script in $moveToExamples) {
        Write-Host "   📄 $script" -ForegroundColor White
    }
    
    Write-Host "`n❌ REMOVE - Obsolete Scripts:" -ForegroundColor Red
    foreach ($script in $obsoleteScripts) {
        if (Test-Path "scripts\$script") {
            Write-Host "   🗑️  $script" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n🧹 CLEANUP - Backup Files:" -ForegroundColor Yellow
    Get-ChildItem "scripts\*.backup-*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "   🗑️  $($_.Name)" -ForegroundColor Gray
    }
    
    Write-Host "`n💡 Run without -WhatIf to perform actual cleanup" -ForegroundColor Cyan
    return
}

# Confirmation
if (-not $Force) {
    Write-Host "`n⚠️  This will reorganize the repository structure and remove obsolete files." -ForegroundColor Yellow
    $confirm = Read-Host "Continue with cleanup? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "❌ Cleanup cancelled" -ForegroundColor Red
        return
    }
}

Write-Host "`n🚀 Starting repository cleanup..." -ForegroundColor Green

# Create new folder structure
Write-Host "📁 Creating organized folder structure..." -ForegroundColor Cyan
$templates = "templates"
$examples = "examples\event-grid"

if (-not (Test-Path $templates)) {
    New-Item -ItemType Directory -Path $templates -Force | Out-Null
    Write-Host "   ✅ Created: $templates\" -ForegroundColor Gray
}

if (-not (Test-Path $examples)) {
    New-Item -ItemType Directory -Path $examples -Force | Out-Null
    Write-Host "   ✅ Created: $examples\" -ForegroundColor Gray
}

# Move Bicep templates to templates folder
Write-Host "`n📋 Moving Bicep templates to templates/..." -ForegroundColor Cyan
foreach ($file in $keepBicepFiles) {
    if (Test-Path "scripts\$file") {
        Move-Item "scripts\$file" "$templates\$file" -Force
        Write-Host "   ✅ Moved: $file" -ForegroundColor Gray
    }
}

# Move example scripts to examples folder
Write-Host "`n📄 Moving example scripts to examples/event-grid/..." -ForegroundColor Cyan
foreach ($script in $moveToExamples) {
    if (Test-Path "scripts\$script") {
        Move-Item "scripts\$script" "$examples\$script" -Force
        Write-Host "   ✅ Moved: $script" -ForegroundColor Gray
    }
}

# Remove obsolete scripts
Write-Host "`n🗑️  Removing obsolete scripts..." -ForegroundColor Red
$removedCount = 0
foreach ($script in ($obsoleteScripts + $obsoleteBicepFiles)) {
    if (Test-Path "scripts\$script") {
        Remove-Item "scripts\$script" -Force
        Write-Host "   ❌ Removed: $script" -ForegroundColor Gray
        $removedCount++
    }
}

# Clean up backup files
Write-Host "`n🧹 Cleaning up backup files..." -ForegroundColor Yellow
$backupFiles = Get-ChildItem "scripts\*.backup-*" -ErrorAction SilentlyContinue
foreach ($file in $backupFiles) {
    Remove-Item $file.FullName -Force
    Write-Host "   🗑️  Removed: $($file.Name)" -ForegroundColor Gray
}

# Update setup-platform.ps1 to use new template paths
Write-Host "`n🔧 Updating script paths..." -ForegroundColor Cyan
$setupScript = "scripts\setup-platform.ps1"
if (Test-Path $setupScript) {
    $content = Get-Content $setupScript -Raw
    $content = $content -replace 'scripts\\deploy-azure-resources-working\.bicep', 'templates\deploy-azure-resources-working.bicep'
    $content = $content -replace 'scripts\\deploy-azure-resources-working\.parameters\.json', 'templates\deploy-azure-resources-working.parameters.json'
    $content = $content -replace 'scripts\\deploy-azure-resources-simple\.bicep', 'templates\deploy-azure-resources-simple.bicep'
    $content = $content -replace 'scripts\\deploy-azure-resources-simple\.parameters\.json', 'templates\deploy-azure-resources-simple.parameters.json'
    Set-Content $setupScript -Value $content
    Write-Host "   ✅ Updated template paths in setup-platform.ps1" -ForegroundColor Gray
}

Write-Host @"

✅ Repository Cleanup Completed!

📊 Cleanup Summary:
• Removed $removedCount obsolete scripts
• Moved $($keepBicepFiles.Count) Bicep templates to templates/
• Moved $($moveToExamples.Count) example scripts to examples/event-grid/
• Cleaned up $($backupFiles.Count) backup files
• Updated script paths

📁 New Repository Structure:
scripts/
├── setup-platform.ps1          ⭐ MAIN ENTRY POINT
├── configure-cicd.ps1           (Platform configuration)
├── deploy-azure-resources-enhanced.ps1  (Azure deployment)
└── workflows/                   (GitHub Actions workflows)

templates/
├── deploy-azure-resources-working.bicep
├── deploy-azure-resources-working.parameters.json
├── deploy-azure-resources-simple.bicep
└── deploy-azure-resources-simple.parameters.json

examples/event-grid/
├── update-function.ps1          (Event Grid automation)
├── quick-test.ps1              (Testing utilities)
└── manual-test-guide.ps1       (Testing guide)

🎯 Next Steps:
1. Update README.md with simplified customer instructions
2. Test the streamlined setup process
3. Create customer customization guide

💡 Customer Entry Point: .\scripts\setup-platform.ps1

"@ -ForegroundColor Green
