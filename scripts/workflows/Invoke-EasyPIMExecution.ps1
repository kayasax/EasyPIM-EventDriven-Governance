# EasyPIM Orchestrator Execution Script
# This script handles the execution of EasyPIM Orchestrator with logging and error handling

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$OrchestratorParams,

    [Parameter(Mandatory = $false)]
    [object]$GraphContext = $null
)

Write-Host "🎯 Executing: Invoke-EasyPIMOrchestrator" -ForegroundColor Cyan

try {
    # Re-establish Graph authentication if needed (GitHub Actions doesn't preserve sessions between steps)
    Write-Host "🔄 Verifying Graph authentication for EasyPIM..." -ForegroundColor Blue

    $finalContext = Get-MgContext
    if (-not $finalContext) {
        Write-Host "⚠️  No existing Graph context found, re-establishing connection..." -ForegroundColor Yellow

        # Get fresh Graph token from Azure CLI
        $graphToken = az account get-access-token --resource https://graph.microsoft.com --query accessToken --output tsv
        if (-not $graphToken) {
            Write-Error "❌ Failed to obtain Microsoft Graph access token from Azure CLI"
            exit 1
        }

        # Connect to Microsoft Graph
        $secureToken = ConvertTo-SecureString $graphToken -AsPlainText -Force
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Connect-MgGraph -AccessToken $secureToken -NoWelcome

        $finalContext = Get-MgContext
        if (-not $finalContext) {
            Write-Error "❌ Failed to establish Graph context for EasyPIM"
            exit 1
        }
    }

    Write-Host "✅ Graph context verified for EasyPIM execution" -ForegroundColor Green
    Write-Host "   Client ID: $($finalContext.ClientId)"
    Write-Host "   Tenant ID: $($finalContext.TenantId)"
    Write-Host "   Scopes: $($finalContext.Scopes -join ', ')"

    # Display final parameters for debugging
    Write-Host "🔧 Final Parameters to Invoke-EasyPIMOrchestrator:" -ForegroundColor Blue
    $OrchestratorParams.GetEnumerator() | ForEach-Object { Write-Host "   $($_.Key): $($_.Value)" }

    # Pre-flight check for Key Vault connectivity (if using Key Vault)
    if ($OrchestratorParams.ContainsKey('KeyVaultName')) {
        Write-Host "🔍 Testing Key Vault connectivity..." -ForegroundColor Blue
        try {
            $kvName = $OrchestratorParams.KeyVaultName
            $secretName = $OrchestratorParams.SecretName
            
            # Test Key Vault access
            $testResult = Get-AzKeyVaultSecret -VaultName $kvName -Name $secretName -AsPlainText -ErrorAction Stop
            if ($testResult) {
                Write-Host "✅ Key Vault connectivity test successful" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Key Vault accessible but secret is empty" -ForegroundColor Yellow
            }
        } catch {
            $kvError = $_.Exception.Message
            Write-Host "⚠️  Key Vault connectivity test failed: $kvError" -ForegroundColor Yellow
            
            # Provide specific guidance based on error type
            if ($kvError -match "network access" -or $kvError -match "Forbidden" -or $kvError -match "403") {
                Write-Host "💡 TIP: Key Vault may be blocking public network access" -ForegroundColor Cyan
                Write-Host "   Consider enabling public access or adding GitHub Actions IPs to firewall" -ForegroundColor Cyan
            } elseif ($kvError -match "unauthorized" -or $kvError -match "401") {
                Write-Host "💡 TIP: Service principal may lack Key Vault permissions" -ForegroundColor Cyan
                Write-Host "   Ensure 'Key Vault Secrets User' role is assigned" -ForegroundColor Cyan
            } elseif ($kvError -match "not found" -or $kvError -match "404") {
                Write-Host "💡 TIP: Key Vault or secret may not exist" -ForegroundColor Cyan
                Write-Host "   Verify Key Vault name and secret name are correct" -ForegroundColor Cyan
            }
            
            Write-Host "🚀 Proceeding with execution - EasyPIM will provide detailed error if this fails..." -ForegroundColor Yellow
        }
    }

    # Enable PowerShell transcript for complete logging
    $transcriptPath = "./easypim-transcript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Start-Transcript -Path $transcriptPath -Force

    Write-Host "📝 PowerShell transcript started: $transcriptPath" -ForegroundColor Green

    # Capture EasyPIM execution with detailed output
    $executionStartTime = Get-Date
    Write-Host "🚀 Starting EasyPIM Orchestrator execution at: $executionStartTime" -ForegroundColor Green

    # Enhanced error handling with specific Key Vault diagnostics
    try {
        # Apply EasyPIM Telemetry Hotpatch for KeyVault configurations
        & "./scripts/workflows/Apply-EasyPIMTelemetryHotpatch.ps1"

        # Execute EasyPIM Orchestrator
        Invoke-EasyPIMOrchestrator @OrchestratorParams
    } catch {
        # Check for common Key Vault access issues
        $errorMessage = $_.Exception.Message
        $innerException = $_.Exception.InnerException?.Message
        
        if ($errorMessage -match "network access" -or 
            $errorMessage -match "public network" -or 
            $errorMessage -match "Forbidden" -or 
            $errorMessage -match "403" -or
            $innerException -match "network access" -or 
            $innerException -match "public network") {
            
            Write-Host "🚨 KEY VAULT NETWORK ACCESS ISSUE DETECTED" -ForegroundColor Red
            Write-Host "❌ Error: Key Vault is likely blocking public network access" -ForegroundColor Red
            Write-Host "" -ForegroundColor White
            Write-Host "🔧 SOLUTION OPTIONS:" -ForegroundColor Yellow
            Write-Host "   1. Enable public network access in Key Vault settings" -ForegroundColor Cyan
            Write-Host "   2. Add GitHub Actions IP ranges to Key Vault firewall" -ForegroundColor Cyan
            Write-Host "   3. Use a self-hosted runner within your network" -ForegroundColor Cyan
            Write-Host "   4. Use local configuration file instead of Key Vault" -ForegroundColor Cyan
            Write-Host "" -ForegroundColor White
            Write-Host "📋 To enable public access temporarily:" -ForegroundColor Blue
            Write-Host "   az keyvault update --name `"$($OrchestratorParams.KeyVaultName)`" --default-action Allow" -ForegroundColor Gray
            Write-Host "" -ForegroundColor White
            
        } elseif ($errorMessage -match "authentication" -or 
                  $errorMessage -match "unauthorized" -or 
                  $errorMessage -match "401") {
            
            Write-Host "🚨 KEY VAULT AUTHENTICATION ISSUE DETECTED" -ForegroundColor Red
            Write-Host "❌ Error: Service principal lacks Key Vault permissions" -ForegroundColor Red
            Write-Host "" -ForegroundColor White
            Write-Host "🔧 SOLUTION:" -ForegroundColor Yellow
            Write-Host "   Grant 'Key Vault Secrets User' role to the service principal" -ForegroundColor Cyan
            Write-Host "" -ForegroundColor White
            
        } elseif ($errorMessage -match "secret.*not found" -or 
                  $errorMessage -match "404") {
            
            Write-Host "🚨 KEY VAULT SECRET NOT FOUND" -ForegroundColor Red
            Write-Host "❌ Error: Secret '$($OrchestratorParams.SecretName)' not found in Key Vault" -ForegroundColor Red
            Write-Host "" -ForegroundColor White
            Write-Host "🔧 SOLUTION:" -ForegroundColor Yellow
            Write-Host "   Verify the secret name and ensure it exists in the Key Vault" -ForegroundColor Cyan
            Write-Host "" -ForegroundColor White
            
        } else {
            Write-Host "🚨 EASYPIM EXECUTION ERROR" -ForegroundColor Red
            Write-Host "❌ Error: $errorMessage" -ForegroundColor Red
            if ($innerException) {
                Write-Host "❌ Inner Exception: $innerException" -ForegroundColor Red
            }
        }
        
        # Re-throw the error to maintain proper exit codes
        throw
    }

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
