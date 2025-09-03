# EasyPIM Ultimate Telemetry Hotpatch Script
# This script provides an enhanced telemetry function and wrapper for guaranteed telemetry capture
# Run this before using the EasyPIM orchestrator to ensure telemetry events are properly sent

[CmdletBinding()]
param()

# 🎯 Ultimate EasyPIM Telemetry Hotpatch - Direct Orchestrator Interception
# This script creates a wrapper around the orchestrator to ensure telemetry is called

Write-Host "🚀 Applying Ultimate Telemetry Hotpatch..." -ForegroundColor Cyan

# First, apply our Send-TelemetryEventFromConfig fix
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
                # Create a fallback identifier if the function doesn't exist
                Write-Host "🔧 [DEBUG] Creating fallback tenant identifier" -ForegroundColor Yellow
                $hasher = [System.Security.Cryptography.SHA256]::Create()
                $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Context.TenantId))
                $TenantIdentifier = [System.BitConverter]::ToString($hash).Replace('-', '').Substring(0, 16).ToLower()
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
        $EnhancedProperties.module_version = "1.1.8-ultimate-hotpatch"
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
            $null = Invoke-RestMethod -Uri $PostHogApiUrl -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
            
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

# Now create a wrapper orchestrator function that calls telemetry explicitly
function global:Invoke-EasyPIMOrchestratorWithTelemetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("initial", "delta")]
        [string]$Mode = "delta",
        
        [switch]$WhatIf,
        [switch]$SkipPolicies,
        [switch]$SkipAssignments,
        [switch]$SkipCleanup
    )
    
    Write-Host "🎯 [WRAPPER] Starting Orchestrator with Telemetry Wrapper" -ForegroundColor Cyan
    
    try {
        # Load configuration first to get telemetry settings
        $loadedConfig = $null
        if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            Write-Host "📥 [WRAPPER] Loading KeyVault configuration..." -ForegroundColor Yellow
            
            # Load config manually since Get-EasyPIMConfiguration might not be available
            try {
                $configJson = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText
                $loadedConfig = $configJson | ConvertFrom-Json
            }
            catch {
                Write-Host "⚠️ [WRAPPER] Failed to load KeyVault config, trying Get-EasyPIMConfiguration..." -ForegroundColor Yellow
                $loadedConfig = Get-EasyPIMConfiguration -KeyVaultName $KeyVaultName -SecretName $SecretName
            }
        } else {
            Write-Host "📥 [WRAPPER] Loading file configuration..." -ForegroundColor Yellow
            $loadedConfig = Get-EasyPIMConfiguration -ConfigFilePath $ConfigFilePath
        }
        
        if (-not $loadedConfig) {
            throw "Failed to load configuration"
        }
        
        Write-Host "✅ [WRAPPER] Configuration loaded successfully" -ForegroundColor Green
        
        # Send startup telemetry
        $sessionId = [System.Guid]::NewGuid().ToString()
        $startupProperties = @{
            execution_mode = if ($WhatIf) { "WhatIf" } else { $Mode }
            config_source = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') { "KeyVault" } else { "File" }
            skip_assignments = $SkipAssignments.IsPresent
            skip_cleanup = $SkipCleanup.IsPresent
            skip_policies = $SkipPolicies.IsPresent
            session_id = $sessionId
            wrapper_version = "ultimate-hotpatch"
        }
        
        Write-Host "📊 [WRAPPER] Sending startup telemetry..." -ForegroundColor Cyan
        Send-TelemetryEventFromConfig -EventName "orchestrator_startup" -Properties $startupProperties -Config $loadedConfig
        
        # Build parameters for the real orchestrator
        $orchestratorParams = @{}
        
        if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
            $orchestratorParams.KeyVaultName = $KeyVaultName
            $orchestratorParams.SecretName = $SecretName
        } else {
            $orchestratorParams.ConfigFilePath = $ConfigFilePath
        }
        
        if ($TenantId) { $orchestratorParams.TenantId = $TenantId }
        if ($SubscriptionId) { $orchestratorParams.SubscriptionId = $SubscriptionId }
        if ($Mode) { $orchestratorParams.Mode = $Mode }
        if ($WhatIf) { $orchestratorParams.WhatIf = $true }
        if ($SkipPolicies) { $orchestratorParams.SkipPolicies = $true }
        if ($SkipAssignments) { $orchestratorParams.SkipAssignments = $true }
        if ($SkipCleanup) { $orchestratorParams.SkipCleanup = $true }
        
        Write-Host "🚀 [WRAPPER] Calling original Invoke-EasyPIMOrchestrator..." -ForegroundColor Green
        
        # Call the original orchestrator
        $startTime = Get-Date
        $result = Invoke-EasyPIMOrchestrator @orchestratorParams
        $endTime = Get-Date
        
        # Send completion telemetry
        $completionProperties = @{
            execution_mode = if ($WhatIf) { "WhatIf" } else { $Mode }
            config_source = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') { "KeyVault" } else { "File" }
            success = $true
            execution_duration_seconds = [math]::Round(($endTime - $startTime).TotalSeconds, 2)
            session_id = $sessionId
            wrapper_version = "ultimate-hotpatch"
        }
        
        Write-Host "✅ [WRAPPER] Sending completion telemetry..." -ForegroundColor Green
        Send-TelemetryEventFromConfig -EventName "orchestrator_completion" -Properties $completionProperties -Config $loadedConfig
        
        return $result
        
    } catch {
        Write-Host "❌ [WRAPPER] Orchestrator failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Send error telemetry
        if ($loadedConfig -and $sessionId) {
            $errorProperties = @{
                execution_mode = if ($WhatIf) { "WhatIf" } else { $Mode }
                config_source = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') { "KeyVault" } else { "File" }
                success = $false
                error_type = $_.Exception.GetType().Name
                session_id = $sessionId
                wrapper_version = "ultimate-hotpatch"
            }
            
            Write-Host "❌ [WRAPPER] Sending error telemetry..." -ForegroundColor Red
            try {
                Send-TelemetryEventFromConfig -EventName "orchestrator_error" -Properties $errorProperties -Config $loadedConfig
            } catch {
                Write-Host "❌ [WRAPPER] Error telemetry also failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        throw
    }
}

Write-Host "✅ Ultimate Telemetry Hotpatch applied successfully!" -ForegroundColor Green
Write-Host "📋 New functions available:" -ForegroundColor Cyan
Write-Host "   - Send-TelemetryEventFromConfig (patched)" -ForegroundColor White
Write-Host "   - Invoke-EasyPIMOrchestratorWithTelemetry (wrapper)" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Use the wrapper function to ensure telemetry:" -ForegroundColor Cyan
Write-Host "   Invoke-EasyPIMOrchestratorWithTelemetry -KeyVaultName 'kv-easypim-8368' -SecretName 'easypim-config-json' -TenantId 'your-tenant' -WhatIf" -ForegroundColor White
