# EasyPIM Module Installation Script
# This script handles EasyPIM module installation and setup with version tracking

Write-Host "🚀 Installing EasyPIM modules from PowerShell Gallery..." -ForegroundColor Cyan

try {
    # Install modules efficiently - install both together to share dependencies
    Write-Host "📦 Installing EasyPIM and EasyPIM.Orchestrator (with shared dependencies)..." -ForegroundColor Gray
    Install-Module -Name EasyPIM, EasyPIM.Orchestrator -Force -Scope CurrentUser -AllowClobber

    Write-Host "📦 Importing EasyPIM.Orchestrator module..." -ForegroundColor Gray
    Import-Module EasyPIM.Orchestrator -Force

    # Get and display installed versions
    Write-Host "`n📋 Installed Module Versions:" -ForegroundColor Yellow

    $easypimModule = Get-Module -Name EasyPIM -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $orchestratorModule = Get-Module -Name EasyPIM.Orchestrator -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

    if ($easypimModule) {
        Write-Host "   ✅ EasyPIM: v$($easypimModule.Version)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ EasyPIM: Not found" -ForegroundColor Yellow
    }

    if ($orchestratorModule) {
        Write-Host "   ✅ EasyPIM.Orchestrator: v$($orchestratorModule.Version)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ EasyPIM.Orchestrator: Not found" -ForegroundColor Yellow
    }

    # Create version manifest for tracking
    $versionInfo = @{
        Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        EasyPIM = @{
            Version = $easypimModule.Version.ToString()
            Path = $easypimModule.ModuleBase
        }
        EasyPIMOrchestrator = @{
            Version = $orchestratorModule.Version.ToString()
            Path = $orchestratorModule.ModuleBase
        }
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Platform = $PSVersionTable.Platform
    }

    # Export version info as JSON for artifact collection
    $versionInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath "./easypim-module-versions.json" -Encoding utf8

    Write-Host "`n✅ EasyPIM modules installed and imported successfully!" -ForegroundColor Green
    return $true
}
catch {
    Write-Host "❌ Failed to install EasyPIM modules: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error details:" -ForegroundColor Red
    $_ | Format-List * -Force
    return $false
}
