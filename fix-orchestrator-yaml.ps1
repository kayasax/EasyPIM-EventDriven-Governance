# Quick Fix for Orchestrator Pipeline YAML Error
# Manual update guide for Azure DevOps

Write-Host "🚨 URGENT: Azure DevOps Pipeline YAML Fix Required" -ForegroundColor Red
Write-Host "=================================================" -ForegroundColor Red

Write-Host "`n🐛 Problem:" -ForegroundColor Yellow
Write-Host "   Line 39 in azure-pipelines-orchestrator.yml has a YAML syntax error" -ForegroundColor Gray
Write-Host "   Template expression is malformed causing pipeline parsing to fail" -ForegroundColor Gray

Write-Host "`n✅ Solution:" -ForegroundColor Green
Write-Host "   1. Go to Azure DevOps:" -ForegroundColor White
Write-Host "      https://dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD" -ForegroundColor Cyan

Write-Host "`n   2. Navigate to: templates/azure-pipelines-orchestrator.yml" -ForegroundColor White

Write-Host "`n   3. Find line 39 (around line 39):" -ForegroundColor White
Write-Host "      name: EasyPIM_`${{ parameters.WhatIf == true && 'Preview' || 'Apply' }}_`$(Date:yyyyMMdd)_`$(Rev:r)" -ForegroundColor Red

Write-Host "`n   4. Replace with:" -ForegroundColor White
Write-Host "      name: 'EasyPIM_Orchestrator_`$(Date:yyyyMMdd)_`$(Rev:r)'" -ForegroundColor Green

Write-Host "`n   5. Commit the change" -ForegroundColor White

Write-Host "`n🔧 Alternative - REST API Fix:" -ForegroundColor Cyan
Write-Host "   If you have a PAT with Code permissions, run:" -ForegroundColor Gray
Write-Host "   .\sync-to-ado.ps1 -PersonalAccessToken `"YOUR-CODE-PAT`"" -ForegroundColor Gray

Write-Host "`n⚡ This fix will resolve the YAML parsing error immediately!" -ForegroundColor Green
