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

    # Execute Test-PIMPolicyDrift with proper error handling
    Write-Host "🚀 Executing Test-PIMPolicyDrift..." -ForegroundColor Green

    Test-PIMPolicyDrift @DriftParams

    Write-Host "✅ Test-PIMPolicyDrift completed successfully" -ForegroundColor Green

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
