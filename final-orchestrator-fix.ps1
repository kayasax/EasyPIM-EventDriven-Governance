# 🔧 Complete Azure DevOps Orchestrator Fix
# Making parameters optional like GitHub workflow

Write-Host "🎯 FINAL AZURE DEVOPS ORCHESTRATOR FIX" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

Write-Host "`n📋 Edit: templates/azure-pipelines-orchestrator.yml" -ForegroundColor Yellow
Write-Host "    https://dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD" -ForegroundColor Gray

Write-Host "`n🔧 FIX #1: Make parameters optional (lines 7-16)" -ForegroundColor Cyan
Write-Host "Add 'required: false' to both parameters:" -ForegroundColor Yellow

Write-Host "`nReplace:" -ForegroundColor Red
Write-Host "- name: run_description" -ForegroundColor Red
Write-Host "  displayName: 'Custom description for this run (optional)'" -ForegroundColor Red
Write-Host "  type: string" -ForegroundColor Red
Write-Host "  default: ''" -ForegroundColor Red
Write-Host "" -ForegroundColor Red
Write-Host "- name: configSecretName" -ForegroundColor Red
Write-Host "  displayName: 'Key Vault secret name containing PIM configuration'" -ForegroundColor Red
Write-Host "  type: string" -ForegroundColor Red
Write-Host "  default: ''" -ForegroundColor Red

Write-Host "`nWith:" -ForegroundColor Green
Write-Host "- name: run_description" -ForegroundColor White
Write-Host "  displayName: 'Custom description for this run (optional)'" -ForegroundColor White
Write-Host "  type: string" -ForegroundColor White
Write-Host "  default: ''" -ForegroundColor White
Write-Host "  required: false" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "- name: configSecretName" -ForegroundColor White
Write-Host "  displayName: 'Key Vault secret name containing PIM configuration (optional)'" -ForegroundColor White
Write-Host "  type: string" -ForegroundColor White
Write-Host "  default: ''" -ForegroundColor White
Write-Host "  required: false" -ForegroundColor Green

Write-Host "`n🔧 FIX #2: Conditional SECRET_NAME variable (lines 30-35)" -ForegroundColor Cyan
Write-Host "Replace:" -ForegroundColor Red
Write-Host "- name: SECRET_NAME" -ForegroundColor Red
Write-Host "  value: `$(EASYPIM_SECRET_NAME)" -ForegroundColor Red

Write-Host "`nWith:" -ForegroundColor Green
Write-Host "- name: SECRET_NAME" -ForegroundColor White
Write-Host "  `${{ if parameters.configSecretName }}:" -ForegroundColor White
Write-Host "    value: `${{ parameters.configSecretName }}" -ForegroundColor White
Write-Host "  `${{ else }}:" -ForegroundColor White
Write-Host "    value: `$(EASYPIM_SECRET_NAME)" -ForegroundColor White

Write-Host "`n✅ Key Benefits:" -ForegroundColor Green
Write-Host "   • Parameters are truly optional like GitHub" -ForegroundColor White
Write-Host "   • Manual runs work without filling all fields" -ForegroundColor White
Write-Host "   • Event Grid automation passes configSecretName dynamically" -ForegroundColor White
Write-Host "   • Falls back to default EASYPIM_SECRET_NAME when not provided" -ForegroundColor White

Write-Host "`n🚀 Result: Perfect GitHub Actions compatibility!" -ForegroundColor Green
