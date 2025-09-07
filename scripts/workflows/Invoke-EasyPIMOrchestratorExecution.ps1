# EasyPIM Orchestrator Execution Script
# This script handles the main orchestrator execution with comprehensive parameter handling

param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$SecretName,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [string]$Mode = "delta",

    [Parameter(Mandatory = $false)]
    [bool]$WhatIf = $true,

    [Parameter(Mandatory = $false)]
    [bool]$SkipPolicies = $false,

    [Parameter(Mandatory = $false)]
    [bool]$SkipAssignments = $false,

    [Parameter(Mandatory = $false)]
    [bool]$AllowProtectedRoles = $false,

    [Parameter(Mandatory = $false)]
    [bool]$VerboseOutput = $false,

    [Parameter(Mandatory = $false)]
    [bool]$ExportWouldRemove = $false,

    [Parameter(Mandatory = $false)]
    [string]$ConfigSecretName = "",

    [Parameter(Mandatory = $false)]
    [string]$RunDescription = ""
)

Write-Host "⚙️ Starting EasyPIM Orchestrator execution..." -ForegroundColor Cyan

# Simple verification that modules are loaded (they should be from previous workflow step)
if (-not (Get-Module -Name EasyPIM) -or -not (Get-Module -Name EasyPIM.Orchestrator)) {
    Write-Host "📦 Re-importing EasyPIM modules..." -ForegroundColor Yellow
    Import-Module EasyPIM -Force
    Import-Module EasyPIM.Orchestrator -Force
}

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Key Vault: $KeyVaultName" -ForegroundColor White
Write-Host "  Secret Name: $SecretName" -ForegroundColor White
if ($ConfigSecretName) {
    Write-Host "  ⚡ Dynamic config from Event Grid trigger" -ForegroundColor Green
} else {
    Write-Host "  📋 Default config from manual trigger" -ForegroundColor Yellow
}

Write-Host "Parameters:" -ForegroundColor Yellow
Write-Host "  WhatIf: $WhatIf" -ForegroundColor White
Write-Host "  Mode: $Mode" -ForegroundColor White
Write-Host "  SkipPolicies: $SkipPolicies" -ForegroundColor White
Write-Host "  SkipAssignments: $SkipAssignments" -ForegroundColor White
Write-Host "  AllowProtectedRoles: $AllowProtectedRoles" -ForegroundColor White
Write-Host "  Verbose: $VerboseOutput" -ForegroundColor White
Write-Host "  ExportWouldRemove: $ExportWouldRemove" -ForegroundColor White

# Build parameters for Invoke-EasyPIMOrchestrator
$params = @{
    KeyVaultName = $KeyVaultName
    SecretName = $SecretName
    TenantId = $TenantId
    SubscriptionId = $SubscriptionId
    Mode = $Mode
}

# Add conditional parameters
if ($WhatIf) {
    $params.WhatIf = $true
    Write-Host "🔍 Running in WhatIf mode (preview only)" -ForegroundColor Yellow
}

if ($SkipPolicies) {
    $params.SkipPolicies = $true
    Write-Host "⏭️ Skipping policy operations" -ForegroundColor Yellow
}

if ($SkipAssignments) {
    $params.SkipAssignments = $true
    Write-Host "⏭️ Skipping assignment operations" -ForegroundColor Yellow
}

if ($AllowProtectedRoles) {
    $params.AllowProtectedRoles = $true
    Write-Host "⚠️ Protected roles operations enabled" -ForegroundColor Yellow
}

if ($VerboseOutput) {
    $params.Verbose = $true
    Write-Host "📝 Verbose output enabled" -ForegroundColor Yellow
}

if ($ExportWouldRemove) {
    $params.WouldRemoveExportPath = "./would-remove-export.json"
    Write-Host "📤 Export would-remove list enabled (path: ./would-remove-export.json)" -ForegroundColor Yellow
}

try {
    # Execute EasyPIM Orchestrator
    Write-Host "`n🔄 Executing EasyPIM Orchestrator..." -ForegroundColor Cyan

    # Verify function is available
    $orchestratorFunction = Get-Command "Invoke-EasyPIMOrchestrator" -ErrorAction SilentlyContinue
    if (-not $orchestratorFunction) {
        Write-Error "❌ CRITICAL: Invoke-EasyPIMOrchestrator function not available"
        return $false
    }

    Write-Host "✅ Module verification passed, proceeding with orchestrator..." -ForegroundColor Green

    # Debug: Show module paths before calling orchestrator
    Write-Host "🔍 DEBUG: Current module information:" -ForegroundColor Magenta
    $currentEasyPIM = Get-Module -Name EasyPIM
    $currentOrchestrator = Get-Module -Name EasyPIM.Orchestrator
    Write-Host "   EasyPIM Path: $($currentEasyPIM.ModuleBase)" -ForegroundColor White
    Write-Host "   Orchestrator Path: $($currentOrchestrator.ModuleBase)" -ForegroundColor White
    Write-Host "   PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor White
    Write-Host "   PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White

    # Capture start time
    $startTime = Get-Date

    # Try calling with explicit error handling and verbose output
    Write-Host "🚀 Calling Invoke-EasyPIMOrchestrator with enhanced debugging..." -ForegroundColor Cyan
    try {
        Invoke-EasyPIMOrchestrator @params -Verbose
    }
    catch {
        Write-Host "❌ DETAILED ERROR from Invoke-EasyPIMOrchestrator:" -ForegroundColor Red
        Write-Host "   Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "   Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "   Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        Write-Host "   Stack Trace:" -ForegroundColor Red
        Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red

        # Try to get more module info at time of failure
        Write-Host "🔍 Module state at time of failure:" -ForegroundColor Yellow
        Get-Module -Name EasyPIM* | Select-Object Name, Version, ModuleBase | Format-Table -AutoSize

        throw $_
    }

    # Capture end time and create summary
    $endTime = Get-Date
    $executionTime = ($endTime - $startTime).ToString("mm\:ss")

    Write-Host "✅ EasyPIM Orchestrator completed successfully" -ForegroundColor Green
    Write-Host "⏱️ Execution time: $executionTime" -ForegroundColor Cyan

    # Try to create a summary JSON for the dashboard
    try {
        $summaryData = @{
            "Status" = "Success"
            "ExecutionTime" = $executionTime
            "StartTime" = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            "EndTime" = $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            "Parameters" = $params
            "Mode" = if ($params.WhatIf) { "Preview" } else { "Applied" }
            "ConfigurationSource" = if ($ConfigSecretName) { "Event-Driven" } else { "Manual" }
            "RunDescription" = $RunDescription
        }

        $summaryData | ConvertTo-Json -Depth 3 | Out-File -FilePath "./easypim-summary.json" -Encoding utf8
        Write-Host "📊 Summary data saved for dashboard" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not create summary data: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    return $true
}
catch {
    Write-Host "❌ EasyPIM Orchestrator failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error details:" -ForegroundColor Red
    $_ | Format-List * -Force

    # Create error summary for dashboard
    try {
        $errorSummary = @{
            "Status" = "Failed"
            "Error" = $_.Exception.Message
            "Timestamp" = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            "Parameters" = $params
        }
        $errorSummary | ConvertTo-Json -Depth 3 | Out-File -FilePath "./easypim-error.json" -Encoding utf8
    } catch {
        # Ignore if we can't write error summary
    }

    return $false
}
