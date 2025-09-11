# EasyPIM-Compatible Microsoft Graph Authentication Fix

# This is the corrected authentication logic for the Azure DevOps pipeline
# It ensures proper Microsoft Graph PowerShell SDK session establishment with required scopes

Write-Host "🔐 Authenticating to Microsoft Graph..."
try {
  # Get service principal details from Azure CLI
  $spInfo = az account show --query "{tenantId:tenantId, user:user.name}" | ConvertFrom-Json
  Write-Host "   📋 Service Principal: $($spInfo.user)"
  Write-Host "   🏢 Tenant ID: $($spInfo.tenantId)"
  
  # EasyPIM expects Connect-MgGraph with specific scopes
  Write-Host "   🎯 Connecting with EasyPIM-required scopes..."
  try {
    # Disconnect any existing session first
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}
    
    # Method 1: Try managed identity with explicit scopes
    Write-Host "   ⚡ Attempting managed identity authentication with required scopes..."
    Connect-MgGraph -Identity -Scopes @('RoleManagement.ReadWrite.Directory') -NoWelcome -ErrorAction Stop
    
    $context = Get-MgContext
    Write-Host "   ✅ Managed Identity authentication successful"
    Write-Host "   👤 Account: $($context.Account)"
    Write-Host "   🆔 Client ID: $($context.ClientId)"
    Write-Host "   🔑 Scopes: $($context.Scopes -join ', ')"
    
  } catch {
    Write-Host "   ⚠️ Managed Identity with scopes failed: $($_.Exception.Message)"
    Write-Host "   🔄 Trying alternative method with service principal credentials..."
    
    try {
      # Method 2: Service principal with certificate or client secret
      # The OIDC connection should provide these automatically
      Write-Host "   🔐 Attempting service principal authentication..."
      Connect-MgGraph -ClientId $spInfo.user -TenantId $spInfo.tenantId -Scopes @('RoleManagement.ReadWrite.Directory') -NoWelcome -ErrorAction Stop
      
      $context = Get-MgContext
      Write-Host "   ✅ Service Principal authentication successful"
      Write-Host "   👤 Account: $($context.Account)"
      Write-Host "   🆔 Client ID: $($context.ClientId)" 
      Write-Host "   🔑 Scopes: $($context.Scopes -join ', ')"
      
    } catch {
      Write-Host "   ⚠️ Service principal authentication failed: $($_.Exception.Message)"
      Write-Host "   🔄 Trying token-based method as final fallback..."
      
      # Method 3: Token-based authentication with scope specification
      $graphToken = az account get-access-token --resource https://graph.microsoft.com --query "accessToken" -o tsv
      
      if ($graphToken -and $graphToken -ne "null" -and $graphToken.Length -gt 100) {
        Write-Host "   ✅ Graph token obtained (length: $($graphToken.Length))"
        
        # Disconnect any existing session
        try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}
        
        # Connect using token and immediately test the connection
        $secureToken = ConvertTo-SecureString $graphToken -AsPlainText -Force
        Connect-MgGraph -AccessToken $secureToken -NoWelcome
        
        # Force scope validation by making a test call
        Write-Host "   🧪 Validating token has required permissions..."
        $testCall = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions?`$top=1" -Method GET
        
        $context = Get-MgContext
        Write-Host "   ✅ Token-based authentication successful and validated"
        Write-Host "   👤 Account: $($context.Account)"
        Write-Host "   🔑 Token validated with RoleManagement permissions"
      } else {
        throw "Failed to obtain valid Graph token"
      }
    }
  }
