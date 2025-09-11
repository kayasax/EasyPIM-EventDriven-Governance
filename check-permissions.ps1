# Test Current Microsoft Graph Permissions
# Check what permissions the service principal currently has

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27"
)

Write-Host "🔍 Checking Current Microsoft Graph Permissions" -ForegroundColor Green
Write-Host "📋 Service Principal: $ServicePrincipalAppId" -ForegroundColor Cyan

# Required permissions for EasyPIM
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

try {
    # Check Azure CLI authentication
    $account = az account show --query "{user:user.name}" | ConvertFrom-Json
    Write-Host "✅ Authenticated as: $($account.user)" -ForegroundColor Green
    
    # Get service principal
    Write-Host "`n🔍 Getting service principal info..." -ForegroundColor Yellow
    $sp = az ad sp show --id $ServicePrincipalAppId --query "{objectId:id, displayName:displayName}" | ConvertFrom-Json
    Write-Host "✅ Found: $($sp.displayName)" -ForegroundColor Green
    
    # Get Microsoft Graph service principal
    $graphSP = az ad sp show --id "00000003-0000-0000-c000-000000000000" --query "{objectId:id}" | ConvertFrom-Json
    
    # Get current app role assignments
    Write-Host "`n🔍 Getting current Microsoft Graph permissions..." -ForegroundColor Yellow
    $assignments = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.objectId)/appRoleAssignments" --query "value[?resourceId=='$($graphSP.objectId)']" | ConvertFrom-Json
    
    Write-Host "📋 Current permissions: $($assignments.Count)" -ForegroundColor Cyan
    
    if ($assignments.Count -gt 0) {
        Write-Host "`n✅ Currently granted permissions:" -ForegroundColor Green
        
        # Get Microsoft Graph app to map role IDs to names
        $graphApp = az ad app show --id "00000003-0000-0000-c000-000000000000" --query "appRoles" | ConvertFrom-Json
        
        foreach ($assignment in $assignments) {
            $appRole = $graphApp | Where-Object { $_.id -eq $assignment.appRoleId }
            if ($appRole) {
                $isRequired = $requiredPermissions -contains $appRole.value
                $status = if ($isRequired) { "✅ REQUIRED" } else { "📋 Extra" }
                Write-Host "   $status $($appRole.value)" -ForegroundColor $(if ($isRequired) { "Green" } else { "White" })
            }
        }
    }
    
    # Check missing permissions
    $currentPermissionNames = @()
    foreach ($assignment in $assignments) {
        $appRole = $graphApp | Where-Object { $_.id -eq $assignment.appRoleId }
        if ($appRole) {
            $currentPermissionNames += $appRole.value
        }
    }
    
    $missingPermissions = $requiredPermissions | Where-Object { $_ -notin $currentPermissionNames }
    
    if ($missingPermissions.Count -gt 0) {
        Write-Host "`n❌ Missing required permissions:" -ForegroundColor Red
        foreach ($missing in $missingPermissions) {
            Write-Host "   - $missing" -ForegroundColor Red
        }
        
        Write-Host "`n🔧 To grant missing permissions, run:" -ForegroundColor Yellow
        Write-Host "   .\grant-permissions-cli.ps1" -ForegroundColor White
        Write-Host "   OR" -ForegroundColor Yellow
        Write-Host "   .\grant-graph-permissions.ps1" -ForegroundColor White
    } else {
        Write-Host "`n🎉 All required permissions are granted!" -ForegroundColor Green
        Write-Host "✅ Your Azure DevOps pipeline should work with EasyPIM!" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Make sure you're authenticated with Azure CLI: az login" -ForegroundColor Yellow
}
