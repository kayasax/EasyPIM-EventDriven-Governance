# EasyPIM Policy Drift Detection Execution Script
# This script handles the execution of Test-PIMPolicyDrift with authentication and error handling

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$DriftParams,

    [Parameter(Mandatory = $false)]
    [object]$GraphContext = $null
)

Write-Host "🎯 Executing: Test-PIMPolicyDrift" -ForegroundColor Cyan

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
    Write-Host "🔧 Final Parameters to Test-PIMPolicyDrift:" -ForegroundColor Blue
    $DriftParams.GetEnumerator() | ForEach-Object { Write-Host "   $($_.Key): $($_.Value)" }

    # Verify Azure PowerShell connection as well
    Write-Host "🔄 Verifying Azure PowerShell authentication..." -ForegroundColor Blue
    try {
        $azContext = Get-AzContext
        if ($azContext) {
            Write-Host "✅ Azure PowerShell context active"
            Write-Host "   Account: $($azContext.Account)"
            Write-Host "   Subscription: $($azContext.Subscription.Name)"
        } else {
            Write-Host "⚠️  Azure PowerShell context not found, attempting connection..." -ForegroundColor Yellow
            # Azure PowerShell should be connected via enable-AzPSSession, but try to reconnect if needed
            Connect-AzAccount -Identity -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "⚠️  Azure PowerShell verification warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Execute Test-PIMPolicyDrift with proper error handling and capture structured results
    Write-Host "🚀 Executing Test-PIMPolicyDrift (capturing results)..." -ForegroundColor Green

    $results = $null
    $executionSucceeded = $false

    # Decide parameter approach (ConfigPath vs KeyVault)
    if ($DriftParams.ContainsKey('ConfigPath') -and (Test-Path $DriftParams['ConfigPath'])) {
        Write-Host "📁 Using ConfigPath approach: $($DriftParams['ConfigPath'])" -ForegroundColor Blue
        $cleanParams = $DriftParams.Clone()
        $cleanParams.Remove('KeyVaultName')
        $cleanParams.Remove('SecretName')
        $results = Test-PIMPolicyDrift @cleanParams
        $executionSucceeded = $true
    }
    elseif ($DriftParams.ContainsKey('KeyVaultName') -and $DriftParams.ContainsKey('SecretName')) {
        Write-Host "🔐 Using native KeyVault approach: $($DriftParams['KeyVaultName'])/$($DriftParams['SecretName'])" -ForegroundColor Blue
        $cleanParams = $DriftParams.Clone()
        $cleanParams.Remove('ConfigPath')
        $results = Test-PIMPolicyDrift @cleanParams
        $executionSucceeded = $true
    }
    else {
        Write-Error "❌ No valid configuration source found - need either ConfigPath or KeyVaultName+SecretName"
        exit 1
    }

    if ($executionSucceeded -and $null -ne $results) {
        Write-Host "✅ Test-PIMPolicyDrift completed (objects captured: $($results.Count))" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Test-PIMPolicyDrift returned no objects" -ForegroundColor Yellow
    }

    # Persist raw object output for auditing
    try { $results | Format-List * | Out-File -FilePath "./drift-raw-output.log" -Encoding UTF8 } catch { }

    # Analyze drift and errors separately
    $driftItems = @()
    $errorItems = @()
    if ($results) {
        $driftItems = $results | Where-Object { $_.Status -eq 'Drift' }
        $errorItems = $results | Where-Object { $_.Status -eq 'Error' }
    }
    $driftCount = $driftItems.Count
    $errorCount = $errorItems.Count
    $totalCount = if ($results) { $results.Count } else { 0 }
    $hasDrift = $driftCount -gt 0

    # Report results clearly
    if ($hasDrift) {
        Write-Host "⚠️ DRIFT DETECTED: $driftCount item(s) out of $totalCount" -ForegroundColor Yellow
        $driftItems | ForEach-Object {
            Write-Host (" - [DRIFT] [{0}] {1} :: {2}" -f $_.Type, $_.Name, ($_.Differences -replace "\r?\n"," ")) -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ No drift detected ($totalCount items evaluated)" -ForegroundColor Green
    }

    if ($errorCount -gt 0) {
        Write-Host "⚠️ Configuration errors found: $errorCount item(s)" -ForegroundColor Magenta
        $errorItems | ForEach-Object {
            Write-Host (" - [ERROR] [{0}] {1} :: {2}" -f $_.Type, $_.Name, ($_.Differences -replace "\r?\n"," ")) -ForegroundColor Magenta
        }
        Write-Host "💡 Note: Errors indicate configuration issues, not policy drift" -ForegroundColor Cyan
    }

    # Build JSON summary
    $summary = [pscustomobject]@{
        generated    = (Get-Date).ToString('o')
        total        = $totalCount
        driftCount   = $driftCount
        errorCount   = $errorCount
        driftDetected= $hasDrift
        drift        = $driftItems | Select-Object Type, Name, Target, Status, Differences
        errors       = $errorItems | Select-Object Type, Name, Target, Status, Differences
    }
    $summaryPath = "./drift-summary.json"
    $summary | ConvertTo-Json -Depth 8 | Out-File -FilePath $summaryPath -Encoding UTF8
    Write-Host "📝 Drift summary written to $summaryPath" -ForegroundColor Cyan

    # Provide lightweight text summary for downstream parsing
    $lightSummary = if ($hasDrift) { "DRIFT_FOUND=$driftCount" } else { "DRIFT_FOUND=0" }
    $lightSummary | Out-File -FilePath "./drift-summary.out" -Encoding UTF8

    # Return results to pipeline
    $results

} catch {
    Write-Error "❌ Test-PIMPolicyDrift execution failed: $($_.Exception.Message)"
    Write-Host "📋 Error Details:" -ForegroundColor Red
    Write-Host "   Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "   Stack Trace: $($_.ScriptStackTrace)"

    # Additional error context for troubleshooting
    Write-Host "🔍 Current Authentication State:" -ForegroundColor Yellow

    $mgContext = Get-MgContext
    if ($mgContext) {
        Write-Host "   Graph Context: ✅ Connected (ClientId: $($mgContext.ClientId))"
    } else {
        Write-Host "   Graph Context: ❌ Not connected"
    }

    $azContext = Get-AzContext
    if ($azContext) {
        Write-Host "   Azure Context: ✅ Connected (Account: $($azContext.Account))"
    } else {
        Write-Host "   Azure Context: ❌ Not connected"
    }

    throw
}
