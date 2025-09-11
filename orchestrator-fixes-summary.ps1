# 🔧 Azure DevOps Orchestrator Pipeline Fixes
# All template expression syntax errors resolved

Write-Host "🚨 ORCHESTRATOR PIPELINE FIXES" -ForegroundColor Red
Write-Host "===============================" -ForegroundColor Red

Write-Host "`n📋 Go to Azure DevOps and edit:" -ForegroundColor Yellow
Write-Host "    templates/azure-pipelines-orchestrator.yml" -ForegroundColor Gray
Write-Host "    https://dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD" -ForegroundColor Gray

Write-Host "`n🔧 FIX #1: Lines 37-39 (Pool and Name)" -ForegroundColor Cyan
Write-Host "Replace with:" -ForegroundColor Green
Write-Host "pool: Default" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "name: EasyPIM_Orchestrator_`$(Date:yyyyMMdd)_`$(Rev:r)" -ForegroundColor White

Write-Host "`n🔧 FIX #2: Around Line 93 (Script Arguments)" -ForegroundColor Cyan
Write-Host "Find this line:" -ForegroundColor Yellow
Write-Host '          -SecretName "${{ parameters.configSecretName != '"'"'' && parameters.configSecretName || variables.SECRET_NAME }}"' -ForegroundColor Red
Write-Host "Replace with:" -ForegroundColor Green
Write-Host '          -SecretName "$(SECRET_NAME)"' -ForegroundColor White

Write-Host "`n🔧 FIX #3: Around Line 128 (Report Config)" -ForegroundColor Cyan
Write-Host "Find this line:" -ForegroundColor Yellow
Write-Host '            configSecret = "${{ parameters.configSecretName != '"'"'' && parameters.configSecretName || variables.SECRET_NAME }}"' -ForegroundColor Red
Write-Host "Replace with:" -ForegroundColor Green
Write-Host '            configSecret = "$(SECRET_NAME)"' -ForegroundColor White

Write-Host "`n✅ Summary of Changes:" -ForegroundColor Green
Write-Host "   • Simplified pool configuration" -ForegroundColor White
Write-Host "   • Removed complex template expressions" -ForegroundColor White
Write-Host "   • Use variables directly instead of parameter logic" -ForegroundColor White
Write-Host "   • Fixed YAML syntax formatting" -ForegroundColor White

Write-Host "`n🚀 After these fixes, the orchestrator will work perfectly!" -ForegroundColor Green
