# EasyPIM Complete Setup and Validation Master Script
# This script handles the complete setup of EasyPIM permissions for Azure DevOps integration
# Ensures ALL required permissions are properly configured

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",
    [switch]$WhatIf = $false,
    [switch]$Force = $false,
    [switch]$SkipValidation = $false,
    [switch]$TestPipeline = $false
)

Write-Host "🚀 EasyPIM Complete CICD Setup Master Script" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "📋 Service Principal App ID: $ServicePrincipalAppId" -ForegroundColor Cyan
Write-Host "🎯 What-If Mode: $WhatIf" -ForegroundColor Cyan
Write-Host "🔄 Force Mode: $Force" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# Step 1: Initial Validation
if (-not $SkipValidation) {
    Write-Host "`n📊 STEP 1: Initial Permission Validation" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Yellow
    
    try {
        & "$PSScriptRoot\validate-all-permissions.ps1" -ServicePrincipalAppId $ServicePrincipalAppId
        Write-Host "   ✅ Initial validation completed" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ Initial validation encountered issues (this is expected if permissions are missing)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n⏭️ STEP 1: Skipping initial validation (as requested)" -ForegroundColor Gray
}

# Step 2: Grant Permissions
Write-Host "`n🔑 STEP 2: Granting ALL Required Permissions" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Yellow

try {
    $grantArgs = @("-ServicePrincipalAppId", $ServicePrincipalAppId)
    if ($WhatIf) { $grantArgs += "-WhatIf" }
    if ($Force) { $grantArgs += "-Force" }
    
    Write-Host "🚀 Executing permission granting script..." -ForegroundColor Cyan
    & "$PSScriptRoot\grant-all-easypim-permissions.ps1" @grantArgs
    
    $grantSuccessful = $LASTEXITCODE -eq 0
    
    if ($grantSuccessful) {
        Write-Host "✅ Permission granting completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Permission granting completed with some issues" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Permission granting failed: $($_.Exception.Message)" -ForegroundColor Red
    $grantSuccessful = $false
}

# Step 3: Post-Grant Validation
if (-not $WhatIf) {
    Write-Host "`n✅ STEP 3: Post-Grant Validation" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Yellow
    
    try {
        Write-Host "🔍 Validating all permissions after granting..." -ForegroundColor Cyan
        & "$PSScriptRoot\validate-all-permissions.ps1" -ServicePrincipalAppId $ServicePrincipalAppId -Detailed
        
        $finalValidationPassed = $LASTEXITCODE -eq 0
        
        if ($finalValidationPassed) {
            Write-Host "✅ All permissions are now correctly configured!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Some permissions still need manual admin consent" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Final validation failed: $($_.Exception.Message)" -ForegroundColor Red
        $finalValidationPassed = $false
    }
} else {
    Write-Host "`n⏭️ STEP 3: Skipping post-grant validation (What-If mode)" -ForegroundColor Gray
    $finalValidationPassed = $false
}

# Step 4: Pipeline Testing (Optional)
if ($TestPipeline -and -not $WhatIf) {
    Write-Host "`n🧪 STEP 4: Pipeline Testing" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Yellow
    
    if ($env:AZURE_DEVOPS_PAT) {
        Write-Host "🚀 Testing Azure DevOps pipeline with current permissions..." -ForegroundColor Cyan
        try {
            & "$PSScriptRoot\trigger-build.ps1" -PAT $env:AZURE_DEVOPS_PAT
            Write-Host "✅ Pipeline test completed!" -ForegroundColor Green
        } catch {
            Write-Host "❌ Pipeline test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ Cannot test pipeline - AZURE_DEVOPS_PAT environment variable not set" -ForegroundColor Yellow
        Write-Host "   To test pipeline, set: `$env:AZURE_DEVOPS_PAT = 'your_token'" -ForegroundColor Gray
    }
} elseif ($TestPipeline -and $WhatIf) {
    Write-Host "`n⏭️ STEP 4: Skipping pipeline test (What-If mode)" -ForegroundColor Gray
} else {
    Write-Host "`n⏭️ STEP 4: Pipeline testing not requested" -ForegroundColor Gray
}

# Final Summary Report
Write-Host "`n📊 FINAL SETUP SUMMARY" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Green

$overallSuccess = if (-not $WhatIf) { $finalValidationPassed } else { $true }

Write-Host "Service Principal: $ServicePrincipalAppId" -ForegroundColor White
Write-Host "Setup Mode: $(if ($WhatIf) { 'What-If (Preview)' } else { 'Live Execution' })" -ForegroundColor White

if ($WhatIf) {
    Write-Host "`n🎯 WHAT-IF SUMMARY:" -ForegroundColor Yellow
    Write-Host "   - Permission granting script would be executed" -ForegroundColor Gray
    Write-Host "   - All required permissions would be processed" -ForegroundColor Gray
    Write-Host "   - No actual changes made to Azure AD" -ForegroundColor Gray
    Write-Host "`n   To apply changes, run without -WhatIf parameter" -ForegroundColor Yellow
} else {
    if ($overallSuccess) {
        Write-Host "`n🎉 SUCCESS! EasyPIM is fully configured for Azure DevOps!" -ForegroundColor Green
        Write-Host "   ✅ All required Microsoft Graph permissions granted" -ForegroundColor Green
        Write-Host "   ✅ Service principal is ready for EasyPIM operations" -ForegroundColor Green
        Write-Host "   ✅ Azure DevOps pipeline should work correctly" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ PARTIAL SUCCESS - Manual intervention required" -ForegroundColor Yellow
        Write-Host "   🔧 Some permissions may need manual admin consent" -ForegroundColor Yellow
        Write-Host "   📋 Check validation output above for specific permissions" -ForegroundColor Yellow
    }
}

Write-Host "`n🚀 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "1. 🔧 Run the actual setup:" -ForegroundColor White
    Write-Host "   .\setup-easypim-complete.ps1" -ForegroundColor Yellow
} elseif ($overallSuccess) {
    Write-Host "1. 🧪 Test your Azure DevOps pipeline:" -ForegroundColor White
    Write-Host "   .\trigger-build.ps1" -ForegroundColor Yellow
    Write-Host "`n2. 🎯 Monitor EasyPIM execution in Azure DevOps" -ForegroundColor White
    Write-Host "`n3. 📊 Check logs for successful privileged access management" -ForegroundColor White
} else {
    Write-Host "1. 🔑 Grant admin consent for failed permissions:" -ForegroundColor White
    Write-Host "   - Azure Portal > Azure AD > App registrations > $ServicePrincipalAppId" -ForegroundColor Gray
    Write-Host "   - API permissions > Grant admin consent" -ForegroundColor Gray
    
    Write-Host "`n2. ✅ Re-validate permissions:" -ForegroundColor White
    Write-Host "   .\validate-all-permissions.ps1 -Detailed" -ForegroundColor Yellow
    
    Write-Host "`n3. 🧪 Test pipeline once permissions are complete:" -ForegroundColor White
    Write-Host "   .\trigger-build.ps1" -ForegroundColor Yellow
}

Write-Host "`n📚 Available Helper Scripts:" -ForegroundColor Cyan
Write-Host "   - .\grant-all-easypim-permissions.ps1 - Grant permissions" -ForegroundColor Gray
Write-Host "   - .\validate-all-permissions.ps1 - Validate permissions" -ForegroundColor Gray
Write-Host "   - .\trigger-build.ps1 - Test Azure DevOps pipeline" -ForegroundColor Gray
Write-Host "   - .\setup-easypim-complete.ps1 -WhatIf - Preview changes" -ForegroundColor Gray

if (-not $WhatIf -and $overallSuccess) {
    Write-Host "`n✨ Your EasyPIM CICD setup is complete and ready for production! ✨" -ForegroundColor Green
} elseif (-not $WhatIf) {
    Write-Host "`n🔧 Your EasyPIM CICD setup is partially complete - follow next steps above" -ForegroundColor Yellow
} else {
    Write-Host "`n🎯 Ready to execute the actual EasyPIM CICD setup when you're ready!" -ForegroundColor Cyan
}

# Set exit code based on success
if ($WhatIf -or $overallSuccess) {
    exit 0
} else {
    exit 1
}
