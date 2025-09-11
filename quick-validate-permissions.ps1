# Quick Permission Validation using Azure CLI
# Validates that all EasyPIM permissions are correctly configured

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27"
)

Write-Host "🔍 EasyPIM Permission Validation (Azure CLI)" -ForegroundColor Green
Write-Host "📋 Service Principal App ID: $ServicePrincipalAppId" -ForegroundColor Cyan

# All required permissions
$requiredPermissions = @(
    "Directory.Read.All",
    "Directory.ReadWrite.All", 
    "PrivilegedAccess.ReadWrite.AzureADGroup",
    "PrivilegedAccess.ReadWrite.AzureResources",
    "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
    "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
    "RoleManagement.ReadWrite.Directory",
    "RoleManagementPolicy.ReadWrite.AzureADGroup",
    "RoleManagementPolicy.ReadWrite.Directory",
    "User.Read.All",
    "Application.Read.All",
    "Group.Read.All"
)

try {
    # Get access token
    $graphToken = az account get-access-token --resource https://graph.microsoft.com --query "accessToken" -o tsv
    $headers = @{
        'Authorization' = "Bearer $graphToken"
        'Content-Type' = 'application/json'
    }

    # Get service principals
    $graphSpResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'" -Headers $headers
    $graphSP = $graphSpResponse.value[0]
    
    $targetSpResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$ServicePrincipalAppId'" -Headers $headers
    $targetSP = $targetSpResponse.value[0]

    # Get current permissions
    $currentPermsResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments?`$filter=resourceId eq $($graphSP.id)" -Headers $headers
    $currentPermissions = $currentPermsResponse.value

    Write-Host "`n✅ Service Principal Found: $($targetSP.displayName)" -ForegroundColor Green
    Write-Host "📊 Current Permissions: $($currentPermissions.Count)" -ForegroundColor Cyan

    $grantedPermissionNames = @()
    foreach ($perm in $currentPermissions) {
        $appRole = $graphSP.appRoles | Where-Object { $_.id -eq $perm.appRoleId }
        if ($appRole) {
            $grantedPermissionNames += $appRole.value
        }
    }

    Write-Host "`n🔍 Permission Analysis:" -ForegroundColor Yellow
    $foundCount = 0
    $missingCount = 0

    foreach ($requiredPerm in $requiredPermissions) {
        if ($grantedPermissionNames -contains $requiredPerm) {
            Write-Host "   ✅ $requiredPerm" -ForegroundColor Green
            $foundCount++
        } else {
            Write-Host "   ❌ $requiredPerm" -ForegroundColor Red
            $missingCount++
        }
    }

    $completionPercentage = [math]::Round(($foundCount / $requiredPermissions.Count) * 100, 1)

    Write-Host "`n📊 VALIDATION SUMMARY:" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   ✅ Granted: $foundCount/$($requiredPermissions.Count)" -ForegroundColor Green
    Write-Host "   ❌ Missing: $missingCount" -ForegroundColor $(if ($missingCount -eq 0) { "Green" } else { "Red" })
    Write-Host "   🎯 Completion: $completionPercentage%" -ForegroundColor $(if ($completionPercentage -eq 100) { "Green" } elseif ($completionPercentage -ge 80) { "Yellow" } else { "Red" })

    if ($completionPercentage -eq 100) {
        Write-Host "`n🎉 SUCCESS! All EasyPIM permissions are correctly configured!" -ForegroundColor Green
        Write-Host "✅ Your Azure DevOps pipeline is ready to run EasyPIM!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ Missing permissions detected!" -ForegroundColor Yellow
        Write-Host "Run: .\grant-easypim-permissions-cli.ps1" -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ Validation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🚀 Ready to test pipeline: .\trigger-build.ps1" -ForegroundColor Cyan
