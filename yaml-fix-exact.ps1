# 🚨 YAML Fix for Azure DevOps
# Copy and paste the exact text below into Azure DevOps

Write-Host "🔧 EXACT YAML FIX for Azure DevOps" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

Write-Host "`n📋 Go to Azure DevOps and edit templates/azure-pipelines-orchestrator.yml" -ForegroundColor Yellow
Write-Host "    https://dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD" -ForegroundColor Gray

Write-Host "`n🎯 Replace lines 37-38 with exactly this:" -ForegroundColor Green
Write-Host "pool: Default" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "name: EasyPIM_Orchestrator_`$(Date:yyyyMMdd)_`$(Rev:r)" -ForegroundColor White

Write-Host "`n❌ REMOVE any quotes around the name field" -ForegroundColor Red
Write-Host "❌ ENSURE proper spacing - no tabs, just spaces" -ForegroundColor Red
Write-Host "❌ ENSURE pool: Default (with capital D)" -ForegroundColor Red

Write-Host "`n✅ The fixed section should look like:" -ForegroundColor Green
Write-Host "  value: `$(EASYPIM_SECRET_NAME)" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "pool: Default" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "name: EasyPIM_Orchestrator_`$(Date:yyyyMMdd)_`$(Rev:r)" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "stages:" -ForegroundColor Gray

Write-Host "`n🚀 This will fix the YAML parsing error!" -ForegroundColor Green
