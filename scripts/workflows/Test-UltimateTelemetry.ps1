# EasyPIM Ultimate Telemetry Test Script
# This script demonstrates the new wrapper function that guarantees telemetry events

[CmdletBinding()]
param()

Write-Host "🎯 EasyPIM Ultimate Telemetry Test - Using Wrapper Function" -ForegroundColor Cyan

try {
    # Apply ultimate telemetry hotpatch (includes wrapper function)
    Write-Host "📊 Loading ultimate telemetry hotpatch with wrapper..." -ForegroundColor Cyan
    . "$PSScriptRoot\Apply-EasyPIMTelemetryHotpatch.ps1"

    # Use the wrapper function - this WILL send telemetry
    Write-Host "🚀 Starting EasyPIM Orchestrator with Telemetry Wrapper..." -ForegroundColor Green
    
    $result = Invoke-EasyPIMOrchestratorWithTelemetry `
        -KeyVaultName "kv-easypim-8368" `
        -SecretName "easypim-config-json" `
        -TenantId "9b08d26c-2c4e-45c8-9313-b700c2ee6e3d" `
        -WhatIf

    Write-Host "✅ Ultimate telemetry test completed successfully!" -ForegroundColor Green
    return $result

} catch {
    Write-Host "❌ Ultimate telemetry test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💭 Full error: $($_.Exception.ToString())" -ForegroundColor Red
    throw
}
