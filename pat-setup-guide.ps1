# Azure DevOps Personal Access Token Setup Guide
# For updating pipeline files via REST API

Write-Host "🔑 Azure DevOps PAT Setup Guide" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

Write-Host "`n📋 Steps to create/update PAT for code operations:" -ForegroundColor Yellow

Write-Host "`n1. Go to Azure DevOps:" -ForegroundColor White
Write-Host "   https://dev.azure.com/loic0161/_usersSettings/tokens" -ForegroundColor Gray

Write-Host "`n2. Click 'New Token' or edit existing token" -ForegroundColor White

Write-Host "`n3. Required Permissions:" -ForegroundColor White
Write-Host "   ✅ Code (read & write) - To update pipeline files" -ForegroundColor Green
Write-Host "   ✅ Agent Pools (read, manage) - For your existing agent" -ForegroundColor Green

Write-Host "`n4. Scope: Select your organization (loic0161)" -ForegroundColor White

Write-Host "`n5. Copy the new PAT and run:" -ForegroundColor White
Write-Host "   .\sync-to-ado.ps1 -PersonalAccessToken `"YOUR-NEW-PAT-HERE`"" -ForegroundColor Cyan

Write-Host "`n💡 Alternative - Manual Update in Web Interface:" -ForegroundColor Yellow
Write-Host "   If you prefer not to create a new PAT:" -ForegroundColor Gray
Write-Host "   1. Go to: https://dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD" -ForegroundColor Gray
Write-Host "   2. Edit templates/azure-pipelines-*.yml files" -ForegroundColor Gray
Write-Host "   3. Change 'pool: vmImage: windows-latest' to 'pool: Default'" -ForegroundColor Gray

Write-Host "`n🎯 The Key Change Needed:" -ForegroundColor Cyan
Write-Host "   Replace this:" -ForegroundColor Red
Write-Host "   pool:" -ForegroundColor Red
Write-Host "     vmImage: 'windows-latest'" -ForegroundColor Red
Write-Host "`n   With this:" -ForegroundColor Green
Write-Host "   pool: Default" -ForegroundColor Green

Write-Host "`n✅ Once updated, your pipelines will use the self-hosted agent!" -ForegroundColor Green
