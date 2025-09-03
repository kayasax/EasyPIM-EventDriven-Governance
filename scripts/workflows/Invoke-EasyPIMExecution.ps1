# EasyPIM Orchestrator Execution Script
# This script handles the execution of EasyPIM Orchestrator with logging and error handling

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$OrchestratorParams,

    [Parameter(Mandatory = $true)]
    [object]$GraphContext
)

Write-Host "🎯 Executing: Invoke-EasyPIMOrchestrator" -ForegroundColor Cyan

try {
    # Final Graph authentication verification
    Write-Host "🔄 Final Graph authentication verification for EasyPIM..." -ForegroundColor Blue

    # Verify the connection one more time
    $finalContext = Get-MgContext
    if (-not $finalContext) {
        Write-Error "❌ Failed to establish Graph context for EasyPIM"
        exit 1
    }

    Write-Host "✅ Final Graph context verified for EasyPIM execution" -ForegroundColor Green
    Write-Host "   Final Scopes: $($finalContext.Scopes -join ', ')"

    # Display final parameters for debugging
    Write-Host "🔧 Final Parameters to Invoke-EasyPIMOrchestrator:" -ForegroundColor Blue
    $OrchestratorParams.GetEnumerator() | ForEach-Object { Write-Host "   $($_.Key): $($_.Value)" }

    # Enable PowerShell transcript for complete logging
    $transcriptPath = "./easypim-transcript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Start-Transcript -Path $transcriptPath -Force

    Write-Host "📝 PowerShell transcript started: $transcriptPath" -ForegroundColor Green

    # Capture EasyPIM execution with detailed output
    $executionStartTime = Get-Date
    Write-Host "🚀 Starting EasyPIM Orchestrator execution at: $executionStartTime" -ForegroundColor Green

    # Execute EasyPIM Orchestrator
    Invoke-EasyPIMOrchestrator @OrchestratorParams

    $executionEndTime = Get-Date
    $executionDuration = $executionEndTime - $executionStartTime
    Write-Host "✅ EasyPIM Orchestrator completed successfully at: $executionEndTime" -ForegroundColor Green
    Write-Host "⏱️ Total execution time: $($executionDuration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor Green

    # Stop transcript
    Stop-Transcript

    # Create a summary log file
    $summaryPath = "./easypim-summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    "EasyPIM Orchestrator Execution Summary" | Out-File -FilePath $summaryPath -Encoding UTF8
    "=====================================" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "Start Time: $executionStartTime" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "End Time: $executionEndTime" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "Duration: $($executionDuration.TotalMinutes.ToString('F2')) minutes" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "Success: True" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "Parameters Used:" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    ($OrchestratorParams | ConvertTo-Json -Depth 3) | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "Graph Context:" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "ClientId: $($finalContext.ClientId)" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "TenantId: $($finalContext.TenantId)" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "Scopes: $($finalContext.Scopes -join ', ')" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append
    "AuthType: $($finalContext.AuthType)" | Out-File -FilePath $summaryPath -Encoding UTF8 -Append

    Write-Host "📋 Execution summary saved to: $summaryPath" -ForegroundColor Green
}
catch {
    $errorTime = Get-Date
    Write-Error "❌ EasyPIM Orchestrator failed at: $errorTime"
    Write-Error "❌ Error: $_"

    # Stop transcript if it was started
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch { }

    # Create error log
    $errorPath = "./easypim-error-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    "EasyPIM Orchestrator Execution Error" | Out-File -FilePath $errorPath -Encoding UTF8
    "===================================" | Out-File -FilePath $errorPath -Encoding UTF8 -Append
    "Error Time: $errorTime" | Out-File -FilePath $errorPath -Encoding UTF8 -Append
    "Error Message: $_" | Out-File -FilePath $errorPath -Encoding UTF8 -Append
    "Error Details: $($_.Exception | ConvertTo-Json -Depth 3)" | Out-File -FilePath $errorPath -Encoding UTF8 -Append
    "" | Out-File -FilePath $errorPath -Encoding UTF8 -Append
    "Parameters Attempted:" | Out-File -FilePath $errorPath -Encoding UTF8 -Append
    ($OrchestratorParams | ConvertTo-Json -Depth 3) | Out-File -FilePath $errorPath -Encoding UTF8 -Append

    Write-Host "📋 Error details saved to: $errorPath" -ForegroundColor Red
    throw
}
