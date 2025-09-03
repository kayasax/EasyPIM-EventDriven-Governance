# EasyPIM Authentication Setup Script
# This script handles all authentication setup for EasyPIM in CI/CD environments

param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId
)

Write-Host "🔗 Setting up Microsoft Graph authentication using Azure CLI token..." -ForegroundColor Cyan

# Get Microsoft Graph access token from Azure CLI (already authenticated via OIDC)
$graphToken = az account get-access-token --resource https://graph.microsoft.com --query accessToken --output tsv

if (-not $graphToken) {
    Write-Error "❌ Failed to obtain Microsoft Graph access token from Azure CLI"
    exit 1
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
    Write-Error "❌ Microsoft Graph context not found after connection"
    exit 1
}

# Connect to Azure PowerShell using OIDC
Write-Host "🔗 Setting up Azure PowerShell authentication..." -ForegroundColor Cyan
try {
    # Install required Azure PowerShell modules if not available
    $missingModules = @()
    if (-not (Get-Module -ListAvailable Az.Accounts)) {
        $missingModules += "Az.Accounts"
    }
    if (-not (Get-Module -ListAvailable Az.KeyVault)) {
        $missingModules += "Az.KeyVault"
    }

    if ($missingModules.Count -gt 0) {
        Write-Host "📦 Installing Azure modules: $($missingModules -join ', ')..."
        Install-Module -Name $missingModules -Force -Scope CurrentUser -AllowClobber
    }

    # Import required modules
    Import-Module Az.Accounts -Force
    Import-Module Az.KeyVault -Force

    # Check if Azure PowerShell session is already established by azure/login@v2
    Write-Host "🔗 Verifying Azure PowerShell session established by azure/login@v2..."
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext) {
        Write-Host "🔗 No existing session found, connecting to Azure PowerShell with OIDC..."
        Connect-AzAccount -TenantId $TenantId -Subscription $SubscriptionId -ErrorAction Stop
    } else {
        Write-Host "✅ Azure PowerShell session already established by azure/login@v2" -ForegroundColor Green
    }

    # Verify Azure PowerShell connection and set subscription context
    $azContext = Get-AzContext
    if ($azContext) {
        # Ensure we're using the correct subscription
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
        $azContext = Get-AzContext

        Write-Host "✅ Azure PowerShell authentication successful" -ForegroundColor Green
        Write-Host "   Account: $($azContext.Account)"
        Write-Host "   Tenant: $($azContext.Tenant)"
        Write-Host "   Subscription: $($azContext.Subscription)"
    } else {
        Write-Warning "⚠️  Azure PowerShell context not found - this may cause EasyPIM to fail"
    }
} catch {
    Write-Warning "⚠️  Primary Azure PowerShell authentication failed: $($_.Exception.Message)"
    Write-Host "🔄 Attempting fallback token-based authentication..." -ForegroundColor Yellow

    try {
        # Fallback: Get Azure management token from Azure CLI for Azure PowerShell
        $azToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv

        if (-not $azToken) {
            Write-Error "❌ Failed to obtain Azure management access token from Azure CLI"
            exit 1
        }

        Write-Host "✅ Successfully obtained Azure management token" -ForegroundColor Green

        # Also get a Key Vault specific token for PoP authentication
        $kvToken = az account get-access-token --resource https://vault.azure.net --query accessToken --output tsv

        if (-not $kvToken) {
            Write-Warning "⚠️  Failed to obtain Key Vault access token - Key Vault operations may fail"
        } else {
            Write-Host "✅ Successfully obtained Key Vault access token" -ForegroundColor Green
        }

        # Connect with both management and Key Vault tokens
        Connect-AzAccount -AccessToken $azToken -KeyVaultAccessToken $kvToken -TenantId $TenantId -AccountId $ClientId

        # Verify Azure PowerShell connection and set subscription context
        $azContext = Get-AzContext
        if ($azContext) {
            # Ensure we're using the correct subscription
            Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
            $azContext = Get-AzContext

            Write-Host "✅ Fallback Azure PowerShell authentication successful" -ForegroundColor Green
            Write-Host "   Account: $($azContext.Account)"
            Write-Host "   Tenant: $($azContext.Tenant)"
            Write-Host "   Subscription: $($azContext.Subscription)"
        } else {
            Write-Warning "⚠️  Azure PowerShell context still not found - EasyPIM may fail"
        }
    } catch {
        Write-Warning "⚠️  All Azure PowerShell authentication methods failed - EasyPIM may not work properly"
        Write-Host "🔧 Proceeding anyway - some EasyPIM operations might still work with Graph-only authentication" -ForegroundColor Yellow
    }
}

# Test Graph API access to ensure authentication works for EasyPIM
try {
    Write-Host "🧪 Testing Microsoft Graph API access for EasyPIM compatibility..." -ForegroundColor Blue
    $tenant = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
    Write-Host "✅ Microsoft Graph API test successful - Connected to tenant: $($tenant.DisplayName)" -ForegroundColor Green
} catch {
    Write-Error "❌ Microsoft Graph API test failed: $($_.Exception.Message)"
    Write-Host "🔧 This indicates the authentication bridge is not working properly" -ForegroundColor Red
    exit 1
}

# Refresh Graph session one more time for EasyPIM compatibility
Write-Host "🔄 Refreshing Microsoft Graph session for EasyPIM compatibility..." -ForegroundColor Cyan
try {
    # Disconnect and reconnect to ensure clean session state
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Connect-MgGraph -AccessToken $secureToken -NoWelcome

    # Verify the fresh connection
    $newContext = Get-MgContext
    if ($newContext) {
        Write-Host "✅ Microsoft Graph session refreshed successfully" -ForegroundColor Green
        Write-Host "   Session ID: $($newContext.ClientId)"
        Write-Host "   Authentication Type: $($newContext.AuthType)"
    } else {
        Write-Error "❌ Failed to refresh Microsoft Graph session"
        exit 1
    }
} catch {
    Write-Error "❌ Failed to refresh Graph session: $($_.Exception.Message)"
    exit 1
}

# Verify EasyPIM can detect the authentication
Write-Host "🧪 Testing EasyPIM authentication detection..." -ForegroundColor Blue
try {
    # Test if EasyPIM recognizes the Graph session
    $authTest = Get-MgContext
    $roleTest = Get-MgDirectoryRole -ErrorAction Stop | Select-Object -First 1

    if ($authTest -and $roleTest) {
        Write-Host "✅ EasyPIM authentication prerequisites verified" -ForegroundColor Green
        Write-Host "   Graph Context: Active"
        Write-Host "   Directory Role Access: Working"
        Write-Host "   Required scope check: $($authTest.Scopes -contains 'RoleManagement.ReadWrite.Directory')"
    } else {
        Write-Warning "⚠️  EasyPIM authentication detection uncertain"
    }
} catch {
    Write-Error "❌ EasyPIM authentication test failed: $($_.Exception.Message)"
    Write-Host "🔧 This may cause EasyPIM to fail authentication check" -ForegroundColor Red
    exit 1
}

# Set authentication context variables for EasyPIM compatibility
Write-Host "🔧 Setting authentication context for EasyPIM compatibility..." -ForegroundColor Cyan
$env:AZURE_CLIENT_ID = $context.ClientId
$env:AZURE_TENANT_ID = $context.TenantId

# Also try setting these global variables that some modules check
$global:AZURE_CLIENT_ID = $context.ClientId
$global:AZURE_TENANT_ID = $context.TenantId

# Try setting Microsoft Graph specific environment variables
$env:MG_CONTEXT_TENANT_ID = $context.TenantId
$env:MG_CONTEXT_CLIENT_ID = $context.ClientId

Write-Host "🎉 Authentication setup completed successfully!" -ForegroundColor Green

# Return the context for use by calling script
return $context
