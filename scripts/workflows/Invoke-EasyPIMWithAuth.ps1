# EasyPIM Orchestrator with Integrated Authentication
# This script handles authentication and orchestrator execution in a single session to avoid context loss

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

Write-Host "🚀 Starting EasyPIM Orchestrator with integrated authentication..." -ForegroundColor Cyan

try {
    # Step 1: Microsoft Graph Authentication
    Write-Host "🔗 Setting up Microsoft Graph authentication..." -ForegroundColor Yellow
    
    # Get Microsoft Graph access token from Azure CLI (already authenticated via OIDC)
    $graphToken = az account get-access-token --resource https://graph.microsoft.com --query accessToken --output tsv
    
    if (-not $graphToken) {
        throw "❌ Failed to obtain Microsoft Graph access token from Azure CLI"
    }
    
    Write-Host "✅ Successfully obtained Graph token, connecting to Microsoft Graph..." -ForegroundColor Green
    
    # Convert token to SecureString and connect to Microsoft Graph
    $secureToken = ConvertTo-SecureString $graphToken -AsPlainText -Force
    
    # Ensure clean Graph session for EasyPIM compatibility
    Write-Host "🔗 Connecting to Microsoft Graph with clean session..."
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Connect-MgGraph -AccessToken $secureToken -NoWelcome
    
    Write-Host "✅ Connected to Microsoft Graph successfully" -ForegroundColor Green
    
    # Verify the connection
    $context = Get-MgContext
    if ($context) {
        Write-Host "🔍 Microsoft Graph Context:" -ForegroundColor Blue
        Write-Host "   ClientId: $($context.ClientId)"
        Write-Host "   TenantId: $($context.TenantId)"
        Write-Host "   Scopes: $($context.Scopes -join ', ')"
    } else {
        throw "❌ Microsoft Graph context not found after connection"
    }

    # Step 2: Azure PowerShell Authentication
    Write-Host "🔗 Setting up Azure PowerShell authentication..." -ForegroundColor Yellow
    
    # Verify Azure PowerShell session established by azure/login@v2
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext) {
        throw "❌ No Azure PowerShell session found - azure/login@v2 may have failed"
    }
    
    # Ensure we're using the correct subscription
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
    $azContext = Get-AzContext
    
    Write-Host "✅ Azure PowerShell authentication verified" -ForegroundColor Green
    Write-Host "   Account: $($azContext.Account)"
    Write-Host "   Tenant: $($azContext.Tenant)"
    Write-Host "   Subscription: $($azContext.Subscription)"

    # Step 3: Verify Module Availability
    Write-Host "🔍 Verifying EasyPIM.Orchestrator module..." -ForegroundColor Yellow
    
    $orchestratorModule = Get-Module -Name EasyPIM.Orchestrator -ErrorAction SilentlyContinue
    if (-not $orchestratorModule) {
        # Try to import it
        Import-Module EasyPIM.Orchestrator -Force -ErrorAction SilentlyContinue
        $orchestratorModule = Get-Module -Name EasyPIM.Orchestrator -ErrorAction SilentlyContinue
    }
    
    if (-not $orchestratorModule) {
        throw "❌ EasyPIM.Orchestrator module not available"
    }
    
    $orchestratorFunction = Get-Command "Invoke-EasyPIMOrchestrator" -ErrorAction SilentlyContinue
    if (-not $orchestratorFunction) {
        throw "❌ Invoke-EasyPIMOrchestrator function not found"
    }
    
    Write-Host "✅ EasyPIM.Orchestrator module verified (v$($orchestratorModule.Version))" -ForegroundColor Green

    # Step 4: Execute EasyPIM Orchestrator
    Write-Host "🚀 Executing EasyPIM Orchestrator..." -ForegroundColor Cyan
    Write-Host "   Mode: $Mode"
    Write-Host "   WhatIf: $WhatIf"
    Write-Host "   Key Vault: $KeyVaultName"
    Write-Host "   Secret: $SecretName"
    
    # Build orchestrator parameters
    $orchestratorParams = @{
        'KeyVaultName' = $KeyVaultName
        'SecretName' = $SecretName
        'Mode' = $Mode
        'WhatIf' = $WhatIf
        'SkipPolicies' = $SkipPolicies
        'SkipAssignments' = $SkipAssignments
        'AllowProtectedRoles' = $AllowProtectedRoles
    }
    
    # Add optional parameters
    if ($TenantId) {
        $orchestratorParams['TenantId'] = $TenantId
    }
    
    if ($SubscriptionId) {
        $orchestratorParams['SubscriptionId'] = $SubscriptionId
    }
    
    # Add export path for would-remove items if requested
    if ($ExportWouldRemove) {
        $exportPath = "./workflow-artifacts/would-remove-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $orchestratorParams['WouldRemoveExportPath'] = $exportPath
        Write-Host "   Export Would Remove: $exportPath"
    }
    
    Write-Host "🚀 Calling Invoke-EasyPIMOrchestrator with enhanced debugging..." -ForegroundColor Cyan
    
    try {
        # Execute the orchestrator
        Invoke-EasyPIMOrchestrator @orchestratorParams
        
        Write-Host "✅ EasyPIM Orchestrator completed successfully!" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "❌ DETAILED ERROR from Invoke-EasyPIMOrchestrator:" -ForegroundColor Red
        Write-Host "   Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "   Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.InnerException) {
            Write-Host "   Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        
        Write-Host "   Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        
        # Check authentication state at time of failure
        Write-Host "🔍 Module state at time of failure:" -ForegroundColor Yellow
        
        $mgContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($mgContext) {
            Write-Host "   ✅ Microsoft Graph: Connected (TenantId: $($mgContext.TenantId))" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Microsoft Graph: Not connected" -ForegroundColor Red
        }
        
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if ($azContext) {
            Write-Host "   ✅ Azure PowerShell: Connected (Subscription: $($azContext.Subscription))" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Azure PowerShell: Not connected" -ForegroundColor Red
        }
        
        $orchestratorLoaded = Get-Module -Name EasyPIM.Orchestrator -ErrorAction SilentlyContinue
        if ($orchestratorLoaded) {
            Write-Host "   ✅ EasyPIM.Orchestrator: Loaded (v$($orchestratorLoaded.Version))" -ForegroundColor Green
        } else {
            Write-Host "   ❌ EasyPIM.Orchestrator: Not loaded" -ForegroundColor Red
        }
        
        throw "❌ EasyPIM Orchestrator failed: $($_.Exception.Message)"
    }

} catch {
    Write-Host "❌ Critical failure in EasyPIM execution:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error details:" -ForegroundColor Red
    $_ | Format-List * -Force
    return $false
}
