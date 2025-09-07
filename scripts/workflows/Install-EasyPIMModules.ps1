# EasyPIM Module Installation Script
# This script handles EasyPIM module installation and setup with version tracking

Write-Host "🚀 Installing EasyPIM modules from PowerShell Gallery..." -ForegroundColor Cyan

try {
    # Install latest versions from PowerShell Gallery
    Write-Host "📦 Installing latest EasyPIM and EasyPIM.Orchestrator..." -ForegroundColor Gray
    Install-Module -Name EasyPIM, EasyPIM.Orchestrator -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    Write-Host "   ✅ Latest versions installed successfully" -ForegroundColor Green

    # Install required Azure modules for EasyPIM orchestrator
    Write-Host "📦 Installing required Azure modules..." -ForegroundColor Gray
    Install-Module -Name Az.KeyVault, Az.Resources, Az.Accounts -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    Write-Host "   ✅ Azure modules installed successfully" -ForegroundColor Green

    Write-Host "📦 Importing EasyPIM module..." -ForegroundColor Gray
    try {
        Import-Module EasyPIM -Force -ErrorAction Stop
        Write-Host "   ✅ EasyPIM imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Failed to import EasyPIM: $($_.Exception.Message)" -ForegroundColor Red
        throw "EasyPIM module import failed: $($_.Exception.Message)"
    }

    Write-Host "📦 Importing EasyPIM.Orchestrator module..." -ForegroundColor Gray
    try {
        Import-Module EasyPIM.Orchestrator -Force -ErrorAction Stop
        Write-Host "   ✅ EasyPIM.Orchestrator imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Failed to import EasyPIM.Orchestrator: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   🔍 Checking module files..." -ForegroundColor Yellow

        # Get module path and check if files exist
        $moduleInfo = Get-Module -Name EasyPIM.Orchestrator -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if ($moduleInfo) {
            Write-Host "   📂 Module path: $($moduleInfo.ModuleBase)" -ForegroundColor White
            $moduleFiles = Get-ChildItem -Path $moduleInfo.ModuleBase -Recurse -ErrorAction SilentlyContinue
            Write-Host "   📄 Module files found: $($moduleFiles.Count)" -ForegroundColor White

            # Try to get more detailed error info
            Write-Host "   🔍 Attempting detailed import..." -ForegroundColor Yellow
            try {
                Import-Module $moduleInfo.ModuleBase -Force -Verbose -ErrorAction Stop
            }
            catch {
                Write-Host "   💥 Detailed error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "   📋 Full exception details:" -ForegroundColor Red
                $_ | Format-List * -Force
            }
        }
        throw "EasyPIM.Orchestrator module import failed: $($_.Exception.Message)"
    }

    # Verify modules are actually loaded
    Write-Host "🔍 Verifying module imports..." -ForegroundColor Gray
    $loadedEasyPIM = Get-Module -Name EasyPIM
    $loadedOrchestrator = Get-Module -Name EasyPIM.Orchestrator

    if (-not $loadedEasyPIM) {
        throw "EasyPIM module failed to import"
    }

    if (-not $loadedOrchestrator) {
        throw "EasyPIM.Orchestrator module failed to import"
    }

    # Get and display installed versions
    Write-Host "`n📋 Installed Module Versions:" -ForegroundColor Yellow

    $easypimModule = Get-Module -Name EasyPIM -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $orchestratorModule = Get-Module -Name EasyPIM.Orchestrator -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

    if ($easypimModule) {
        Write-Host "   ✅ EasyPIM: v$($easypimModule.Version) (Loaded: v$($loadedEasyPIM.Version))" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ EasyPIM: Not found" -ForegroundColor Yellow
    }

    if ($orchestratorModule) {
        Write-Host "   ✅ EasyPIM.Orchestrator: v$($orchestratorModule.Version) (Loaded: v$($loadedOrchestrator.Version))" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ EasyPIM.Orchestrator: Not found" -ForegroundColor Yellow
    }

    # Verify key functions are available
    Write-Host "`n🔍 Verifying key functions..." -ForegroundColor Gray
    $orchestratorFunction = Get-Command "Invoke-EasyPIMOrchestrator" -ErrorAction SilentlyContinue
    if ($orchestratorFunction) {
        Write-Host "   ✅ Invoke-EasyPIMOrchestrator function available" -ForegroundColor Green
    } else {
        throw "Invoke-EasyPIMOrchestrator function not found after module import"
    }

    # Create version manifest for tracking
    $versionInfo = @{
        Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        EasyPIM = @{
            Version = if ($easypimModule) { $easypimModule.Version.ToString() } else { "Not Available" }
            Path = if ($easypimModule) { $easypimModule.ModuleBase } else { "Not Available" }
            LoadedVersion = if ($loadedEasyPIM) { $loadedEasyPIM.Version.ToString() } else { "Not Loaded" }
        }
        EasyPIMOrchestrator = @{
            Version = if ($orchestratorModule) { $orchestratorModule.Version.ToString() } else { "Not Available" }
            Path = if ($orchestratorModule) { $orchestratorModule.ModuleBase } else { "Not Available" }
            LoadedVersion = if ($loadedOrchestrator) { $loadedOrchestrator.Version.ToString() } else { "Not Loaded" }
        }
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Platform = $PSVersionTable.Platform
        ModuleVerification = @{
            OrchestratorFunctionAvailable = if ($orchestratorFunction) { $true } else { $false }
        }
    }

    # Export version info as JSON for artifact collection
    $versionInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath "./easypim-module-versions.json" -Encoding utf8

    # Comprehensive validation of installed modules
    Write-Host "🔍 Verifying module imports..." -ForegroundColor Gray

    # Get installed versions
    $easypimModule = Get-Module -Name EasyPIM
    $orchestratorModule = Get-Module -Name EasyPIM.Orchestrator
    $easypimInstalled = Get-Module -Name EasyPIM -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $orchestratorInstalled = Get-Module -Name EasyPIM.Orchestrator -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

    Write-Host "📋 Installed Module Versions:" -ForegroundColor Cyan
    Write-Host "   ✅ EasyPIM: v$($easypimInstalled.Version) (Loaded: v$($easypimModule.Version))" -ForegroundColor Green
    Write-Host "   ✅ EasyPIM.Orchestrator: v$($orchestratorInstalled.Version) (Loaded: v$($orchestratorModule.Version))" -ForegroundColor Green

    # Critical function validation
    Write-Host "🔍 Verifying key functions..." -ForegroundColor Gray

    $orchestratorFunction = Get-Command "Invoke-EasyPIMOrchestrator" -ErrorAction SilentlyContinue
    if (-not $orchestratorFunction) {
        throw "❌ CRITICAL: Invoke-EasyPIMOrchestrator function not found after module import"
    }
    Write-Host "   ✅ Invoke-EasyPIMOrchestrator function available" -ForegroundColor Green

    Write-Host "`n✅ EasyPIM modules installed and imported successfully!" -ForegroundColor Green
    return $true
}
catch {
    Write-Host "❌ Failed to install EasyPIM modules: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error details:" -ForegroundColor Red
    $_ | Format-List * -Force
    return $false
}
