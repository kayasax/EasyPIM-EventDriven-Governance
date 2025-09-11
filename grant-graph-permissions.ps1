# Grant EasyPIM Required Microsoft Graph Permissions
# This script grants all the necessary permissions for EasyPIM to work with Azure DevOps service principal

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",  # Your Azure DevOps service principal
    [switch]$WhatIf = $false
)

Write-Host "🔐 Granting EasyPIM Required Microsoft Graph Permissions" -ForegroundColor Green
Write-Host "📋 Service Principal App ID: $ServicePrincipalAppId" -ForegroundColor Cyan

# Required Microsoft Graph permissions for EasyPIM (from your GitHub app)
$requiredPermissions = @(
    "Directory.Read.All",
    "PrivilegedAccess.ReadWrite.AzureADGroup", 
    "PrivilegedAccess.ReadWrite.AzureResources",
    "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
    "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
    "RoleManagement.ReadWrite.Directory",
    "RoleManagementPolicy.ReadWrite.AzureADGroup",
    "RoleManagementPolicy.ReadWrite.Directory",
    "User.Read.All"
)

Write-Host "`n📋 Required permissions for EasyPIM:" -ForegroundColor Yellow
foreach ($permission in $requiredPermissions) {
    Write-Host "   - $permission" -ForegroundColor White
}

if ($WhatIf) {
    Write-Host "`n⚠️ WHAT-IF MODE: No changes will be made" -ForegroundColor Yellow
} else {
    Write-Host "`n🚀 Applying permissions..." -ForegroundColor Green
}

try {
    # Check if already authenticated to Microsoft Graph PowerShell
    try {
        $context = Get-MgContext
        if (-not $context) {
            throw "Not authenticated"
        }
        Write-Host "✅ Already authenticated to Microsoft Graph" -ForegroundColor Green
    } catch {
        Write-Host "🔐 Authenticating to Microsoft Graph PowerShell (admin consent required)..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome
    }

    # Get Microsoft Graph service principal
    Write-Host "🔍 Finding Microsoft Graph service principal..." -ForegroundColor Cyan
    $graphSP = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
    
    if (-not $graphSP) {
        throw "Microsoft Graph service principal not found"
    }
    
    Write-Host "✅ Microsoft Graph service principal found: $($graphSP.Id)" -ForegroundColor Green

    # Get target service principal (Azure DevOps)
    Write-Host "🔍 Finding target service principal..." -ForegroundColor Cyan
    $targetSP = Get-MgServicePrincipal -Filter "appId eq '$ServicePrincipalAppId'"
    
    if (-not $targetSP) {
        throw "Target service principal not found: $ServicePrincipalAppId"
    }
    
    Write-Host "✅ Target service principal found: $($targetSP.DisplayName) ($($targetSP.Id))" -ForegroundColor Green

    # Get current permissions
    Write-Host "🔍 Checking current permissions..." -ForegroundColor Cyan
    $currentPermissions = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetSP.Id | Where-Object { $_.ResourceId -eq $graphSP.Id }
    
    Write-Host "📋 Current permissions: $($currentPermissions.Count)" -ForegroundColor White
    
    # Grant each required permission
    $successCount = 0
    $skipCount = 0
    
    foreach ($permissionName in $requiredPermissions) {
        Write-Host "`n🔍 Processing permission: $permissionName" -ForegroundColor Cyan
        
        # Find the permission in Microsoft Graph app roles
        $appRole = $graphSP.AppRoles | Where-Object { $_.Value -eq $permissionName }
        
        if (-not $appRole) {
            Write-Host "   ❌ Permission not found in Microsoft Graph app roles: $permissionName" -ForegroundColor Red
            continue
        }
        
        # Check if already granted
        $existingAssignment = $currentPermissions | Where-Object { $_.AppRoleId -eq $appRole.Id }
        
        if ($existingAssignment) {
            Write-Host "   ✅ Already granted: $permissionName" -ForegroundColor Green
            $skipCount++
            continue
        }
        
        if ($WhatIf) {
            Write-Host "   🎯 Would grant: $permissionName" -ForegroundColor Yellow
            $successCount++
        } else {
            try {
                # Grant the permission
                $params = @{
                    PrincipalId = $targetSP.Id
                    ResourceId = $graphSP.Id
                    AppRoleId = $appRole.Id
                }
                
                New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetSP.Id -BodyParameter $params
                Write-Host "   ✅ Granted: $permissionName" -ForegroundColor Green
                $successCount++
            } catch {
                Write-Host "   ❌ Failed to grant: $permissionName - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`n📊 Summary:" -ForegroundColor Green
    Write-Host "   ✅ Granted: $successCount" -ForegroundColor Green
    Write-Host "   ⏭️ Already had: $skipCount" -ForegroundColor Cyan
    Write-Host "   📋 Total required: $($requiredPermissions.Count)" -ForegroundColor White
    
    if ($WhatIf) {
        Write-Host "`n🎯 To apply these changes, run without -WhatIf parameter" -ForegroundColor Yellow
    } elseif ($successCount -gt 0) {
        Write-Host "`n✅ Permissions granted! Your Azure DevOps service principal now has EasyPIM permissions." -ForegroundColor Green
        Write-Host "🔄 Test the pipeline again - authentication should now work!" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n💡 Make sure you're running as a Global Administrator or have Application.ReadWrite.All permissions" -ForegroundColor Yellow
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run your Azure DevOps pipeline again" -ForegroundColor White
Write-Host "2. The Microsoft Graph authentication should now succeed" -ForegroundColor White
Write-Host "3. EasyPIM should have all required permissions to manage privileged access" -ForegroundColor White
