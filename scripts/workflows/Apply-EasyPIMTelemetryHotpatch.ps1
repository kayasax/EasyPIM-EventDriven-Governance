# EasyPIM Telemetry Hotpatch Script
# This script patches the current PowerShell session to support telemetry with KeyVault configurations
# Run this before using Invoke-EasyPIMOrchestrator with KeyVault configurations

[CmdletBinding()]
param()

Write-Host "🔧 Applying EasyPIM Telemetry Hotpatch..." -ForegroundColor Cyan

# Override the Send-TelemetryEventFromConfig function with fixed logic
function global:Send-TelemetryEventFromConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties,

        [Parameter(Mandatory = $true)]
        [object]$Config
    )

    try {
        Write-Host "🔍 [DEBUG] Send-TelemetryEventFromConfig called for event: $EventName" -ForegroundColor Yellow

        if (-not $Config) {
            Write-Host "❌ [DEBUG] No config object provided" -ForegroundColor Red
            return
        }

        Write-Host "🔍 [DEBUG] Config.TelemetrySettings exists: $($null -ne $Config.TelemetrySettings)" -ForegroundColor Yellow
        
        if ($Config.TelemetrySettings) {
            Write-Host "🔍 [DEBUG] ALLOW_TELEMETRY value: $($Config.TelemetrySettings.ALLOW_TELEMETRY)" -ForegroundColor Yellow
        }

        # Check if telemetry is enabled
        $TelemetryEnabled = $false
        if ($Config.TelemetrySettings -and $Config.TelemetrySettings.ALLOW_TELEMETRY) {
            $TelemetryEnabled = $Config.TelemetrySettings.ALLOW_TELEMETRY
        }

        if (-not $TelemetryEnabled) {
            Write-Host "❌ [DEBUG] Telemetry disabled - skipping event: $EventName" -ForegroundColor Red
            return
        }

        Write-Host "✅ [DEBUG] Telemetry enabled - proceeding with event: $EventName" -ForegroundColor Green

        # Get Microsoft Graph context
        $Context = $null
        try {
            $Context = Get-MgContext -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "No Microsoft Graph context available"
        }

        if (-not $Context -or -not $Context.TenantId) {
            Write-Host "❌ [DEBUG] No Graph context available - skipping telemetry" -ForegroundColor Red
            return
        }

        Write-Host "✅ [DEBUG] Graph context available, tenant: $($Context.TenantId)" -ForegroundColor Green

        # Try to get telemetry identifier
        $TenantIdentifier = $null
        try {
            # Try EasyPIM's Get-TelemetryIdentifier first
            if (Get-Command Get-TelemetryIdentifier -ErrorAction SilentlyContinue) {
                $TenantIdentifier = Get-TelemetryIdentifier -TenantId $Context.TenantId
            } else {
                # Create a simple hash-based identifier as fallback
                $hasher = [System.Security.Cryptography.SHA256]::Create()
                $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Context.TenantId))
                $TenantIdentifier = [System.BitConverter]::ToString($hash).Replace('-', '').Substring(0, 16).ToLower()
                Write-Host "🔧 [DEBUG] Created fallback tenant identifier" -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "❌ [DEBUG] Failed to create telemetry identifier: $($_.Exception.Message)" -ForegroundColor Red
            return
        }

        if (-not $TenantIdentifier) {
            Write-Host "❌ [DEBUG] Telemetry identifier is null" -ForegroundColor Red
            return
        }

        Write-Host "✅ [DEBUG] Telemetry identifier created successfully" -ForegroundColor Green

        # Enhance properties
        $EnhancedProperties = $Properties.Clone()
        $EnhancedProperties.module_version = "1.1.8-hotpatch"
        $EnhancedProperties.powershell_version = $PSVersionTable.PSVersion.ToString()
        $EnhancedProperties.timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $EnhancedProperties.tenant_id = $TenantIdentifier

        # Send to PostHog
        try {
            $PostHogProjectKey = "phc_witsM6gj8k6GOor3RUBiN7vUPId11R2LMShF8lTUcBD"
            $PostHogApiUrl = "https://eu.posthog.com/capture/"

            $EventData = @{
                api_key = $PostHogProjectKey
                event = $EventName
                properties = $EnhancedProperties
                distinct_id = $TenantIdentifier
                timestamp = $EnhancedProperties.timestamp
            }

            $Body = $EventData | ConvertTo-Json -Depth 10 -Compress
            $Response = Invoke-RestMethod -Uri $PostHogApiUrl -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
            
            Write-Host "✅ [DEBUG] Telemetry event sent successfully: $EventName" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ [DEBUG] PostHog API call failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    }
    catch {
        Write-Host "❌ [DEBUG] Telemetry function failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verify orchestrator function is available
$originalFunction = Get-Command Invoke-EasyPIMOrchestrator -ErrorAction SilentlyContinue
if ($originalFunction) {
    Write-Host "✅ Found Invoke-EasyPIMOrchestrator - telemetry will be properly routed" -ForegroundColor Green
} else {
    Write-Host "⚠️  Invoke-EasyPIMOrchestrator not found - please import EasyPIM.Orchestrator module" -ForegroundColor Yellow
}

Write-Host "✅ Telemetry hotpatch applied successfully!" -ForegroundColor Green
Write-Host "📊 Debug messages will show telemetry flow when you run the orchestrator" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Now run your orchestrator with KeyVault config:" -ForegroundColor Cyan
Write-Host "   Invoke-EasyPIMOrchestrator -KeyVaultName 'YourVault' -SecretName 'easypim-config-json'" -ForegroundColor White
