# EasyPIM Module Installation Script
# This script handles EasyPIM module installation and setup

Write-Host "🚀 Installing EasyPIM modules from PowerShell Gallery..." -ForegroundColor Cyan

# Install modules efficiently - install both together to share dependencies
Write-Host "📦 Installing EasyPIM and EasyPIM.Orchestrator (with shared dependencies)..."
Install-Module -Name EasyPIM, EasyPIM.Orchestrator -Force -Scope CurrentUser -AllowClobber

Write-Host "📦 Importing EasyPIM.Orchestrator module..."
Import-Module EasyPIM.Orchestrator -Force

Write-Host "✅ EasyPIM modules installed and imported successfully!" -ForegroundColor Green
