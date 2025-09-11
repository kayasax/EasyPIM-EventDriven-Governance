# EasyPIM Complete Permission Setup using Azure CLI REST API
# This script uses Azure CLI REST API to avoid PowerShell module conflicts
# Ensures ALL required Microsoft Graph permissions are configured

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",
    [switch]$WhatIf = $false
)

Write-Host "🔐 EasyPIM Complete Permission Setup (Azure CLI Method)" -ForegroundColor Green
Write-Host "📋 Service Principal App ID: $ServicePrincipalAppId" -ForegroundColor Cyan

# ALL required Microsoft Graph permissions for EasyPIM
$requiredPermissions = @(
    @{ Name = "Directory.Read.All"; Description = "Read directory data" },
    @{ Name = "Directory.ReadWrite.All"; Description = "Read and write directory data" },
    @{ Name = "PrivilegedAccess.ReadWrite.AzureADGroup"; Description = "Read and write privileged access for Azure AD groups" },
    @{ Name = "PrivilegedAccess.ReadWrite.AzureResources"; Description = "Read and write privileged access for Azure resources" },
    @{ Name = "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup"; Description = "Read and write privileged assignment schedules for Azure AD groups" },
    @{ Name = "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup"; Description = "Read and write privileged eligibility schedules for Azure AD groups" },
    @{ Name = "RoleManagement.ReadWrite.Directory"; Description = "Read and write role management data in directory" },
    @{ Name = "RoleManagementPolicy.ReadWrite.AzureADGroup"; Description = "Read and write role management policies for Azure AD groups" },
    @{ Name = "RoleManagementPolicy.ReadWrite.Directory"; Description = "Read and write role management policies in directory" },
    @{ Name = "User.Read.All"; Description = "Read all users' basic profiles" },
    @{ Name = "Application.Read.All"; Description = "Read applications and service principals" },
    @{ Name = "Group.Read.All"; Description = "Read all groups" }
)

Write-Host "`n📋 ALL Required permissions for EasyPIM ($($requiredPermissions.Count)):" -ForegroundColor Yellow
foreach ($permission in $requiredPermissions) {
    Write-Host "   - $($permission.Name)" -ForegroundColor White
    Write-Host "     $($permission.Description)" -ForegroundColor Gray
}

if ($WhatIf) {
    Write-Host "`n⚠️ WHAT-IF MODE: No changes will be made" -ForegroundColor Yellow
}

try {
    # Test Azure CLI authentication
    Write-Host "`n🔐 Testing Azure CLI authentication..." -ForegroundColor Cyan
    $account = az account show --query "{subscriptionId:id, tenantId:tenantId, user:user.name}" 2>$null | ConvertFrom-Json
    
    if (-not $account) {
        throw "Azure CLI not authenticated. Run 'az login' first."
    }
    
    Write-Host "   ✅ Azure CLI authenticated as: $($account.user)" -ForegroundColor Green
    Write-Host "     Tenant: $($account.tenantId)" -ForegroundColor Gray

    # Get Microsoft Graph access token
    Write-Host "`n🔑 Getting Microsoft Graph access token..." -ForegroundColor Cyan
    $graphToken = az account get-access-token --resource https://graph.microsoft.com --query "accessToken" -o tsv
    
    if (-not $graphToken) {
        throw "Failed to get Microsoft Graph access token"
    }
    
    Write-Host "   ✅ Microsoft Graph token acquired" -ForegroundColor Green

    # Set up headers for Graph API calls
    $headers = @{
        'Authorization' = "Bearer $graphToken"
        'Content-Type' = 'application/json'
    }

    # Get Microsoft Graph service principal
    Write-Host "`n🔍 Finding Microsoft Graph service principal..." -ForegroundColor Cyan
    $graphSpUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'"
    
    try {
        $graphSpResponse = Invoke-RestMethod -Uri $graphSpUrl -Headers $headers -Method Get
        $graphSP = $graphSpResponse.value[0]
        
        if (-not $graphSP) {
            throw "Microsoft Graph service principal not found"
        }
        
        Write-Host "   ✅ Microsoft Graph service principal found: $($graphSP.id)" -ForegroundColor Green
    } catch {
        throw "Failed to get Microsoft Graph service principal: $($_.Exception.Message)"
    }

    # Get target service principal (Azure DevOps)
    Write-Host "`n🔍 Finding target service principal..." -ForegroundColor Cyan
    $targetSpUrl = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$ServicePrincipalAppId'"
    
    try {
        $targetSpResponse = Invoke-RestMethod -Uri $targetSpUrl -Headers $headers -Method Get
        $targetSP = $targetSpResponse.value[0]
        
        if (-not $targetSP) {
            throw "Target service principal not found: $ServicePrincipalAppId"
        }
        
        Write-Host "   ✅ Target service principal found: $($targetSP.displayName)" -ForegroundColor Green
        Write-Host "     Service Principal ID: $($targetSP.id)" -ForegroundColor Gray
    } catch {
        throw "Failed to get target service principal: $($_.Exception.Message)"
    }

    # Get current permissions
    Write-Host "`n📊 Analyzing current permissions..." -ForegroundColor Cyan
    $currentPermsUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments?`$filter=resourceId eq $($graphSP.id)"
    
    try {
        $currentPermsResponse = Invoke-RestMethod -Uri $currentPermsUrl -Headers $headers -Method Get
        $currentPermissions = $currentPermsResponse.value
        
        Write-Host "   📋 Current permission count: $($currentPermissions.Count)" -ForegroundColor White
        
        if ($currentPermissions.Count -gt 0) {
            Write-Host "   📝 Currently granted permissions:" -ForegroundColor Gray
            foreach ($perm in $currentPermissions) {
                $appRole = $graphSP.appRoles | Where-Object { $_.id -eq $perm.appRoleId }
                if ($appRole) {
                    Write-Host "      - $($appRole.value)" -ForegroundColor Gray
                }
            }
        }
    } catch {
        throw "Failed to get current permissions: $($_.Exception.Message)"
    }

    # Process each required permission
    $results = @{
        Granted = @()
        AlreadyHad = @()
        Failed = @()
        NotFound = @()
    }
    
    Write-Host "`n🚀 Processing ALL required permissions..." -ForegroundColor Green
    
    foreach ($permission in $requiredPermissions) {
        $permissionName = $permission.Name
        Write-Host "`n🔍 Processing: $permissionName" -ForegroundColor Cyan
        Write-Host "   Description: $($permission.Description)" -ForegroundColor Gray
        
        # Find the permission in Microsoft Graph app roles
        $appRole = $graphSP.appRoles | Where-Object { $_.value -eq $permissionName }
        
        if (-not $appRole) {
            Write-Host "   ❌ Permission not found in Microsoft Graph app roles: $permissionName" -ForegroundColor Red
            $results.NotFound += $permissionName
            continue
        }
        
        Write-Host "   📋 App Role ID: $($appRole.id)" -ForegroundColor Gray
        
        # Check if already granted
        $existingAssignment = $currentPermissions | Where-Object { $_.appRoleId -eq $appRole.id }
        
        if ($existingAssignment) {
            Write-Host "   ✅ Already granted: $permissionName" -ForegroundColor Green
            $results.AlreadyHad += $permissionName
            continue
        }
        
        if ($WhatIf) {
            Write-Host "   🎯 Would grant: $permissionName" -ForegroundColor Yellow
            $results.Granted += $permissionName
        } else {
            try {
                # Grant the permission using Graph API
                Write-Host "   🔑 Granting permission..." -ForegroundColor Yellow
                
                $grantUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments"
                $body = @{
                    principalId = $targetSP.id
                    resourceId = $graphSP.id
                    appRoleId = $appRole.id
                } | ConvertTo-Json -Depth 10
                
                $assignment = Invoke-RestMethod -Uri $grantUrl -Headers $headers -Method Post -Body $body
                
                Write-Host "   ✅ Successfully granted: $permissionName" -ForegroundColor Green
                Write-Host "      Assignment ID: $($assignment.id)" -ForegroundColor Gray
                $results.Granted += $permissionName
                
                # Small delay to avoid rate limiting
                Start-Sleep -Milliseconds 500
                
            } catch {
                Write-Host "   ❌ Failed to grant: $permissionName" -ForegroundColor Red
                $errorMessage = $_.Exception.Message
                Write-Host "      Error: $errorMessage" -ForegroundColor Red
                $results.Failed += $permissionName
                
                # Check if it's a 400 Bad Request (often means manual consent needed)
                if ($errorMessage -like "*400*" -or $errorMessage -like "*Bad Request*" -or $errorMessage -like "*Forbidden*") {
                    Write-Host "      💡 This permission may require manual admin consent in Azure Portal" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # Final summary
    Write-Host "`n📊 FINAL SUMMARY:" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   ✅ Successfully granted: $($results.Granted.Count)" -ForegroundColor Green
    Write-Host "   ⏭️ Already had: $($results.AlreadyHad.Count)" -ForegroundColor Cyan
    Write-Host "   ❌ Failed to grant: $($results.Failed.Count)" -ForegroundColor Red
    Write-Host "   ❓ Not found: $($results.NotFound.Count)" -ForegroundColor Magenta
    Write-Host "   📋 Total required: $($requiredPermissions.Count)" -ForegroundColor White
    
    $totalSuccess = $results.Granted.Count + $results.AlreadyHad.Count
    $completionPercentage = [math]::Round(($totalSuccess / $requiredPermissions.Count) * 100, 1)
    
    Write-Host "`n🎯 Permission Coverage: $completionPercentage% ($totalSuccess/$($requiredPermissions.Count))" -ForegroundColor $(if ($completionPercentage -eq 100) { "Green" } elseif ($completionPercentage -ge 80) { "Yellow" } else { "Red" })
    
    if ($results.Granted.Count -gt 0 -and -not $WhatIf) {
        Write-Host "`n✅ Newly granted permissions:" -ForegroundColor Green
        foreach ($granted in $results.Granted) {
            Write-Host "   - $granted" -ForegroundColor Green
        }
    }
    
    if ($results.Failed.Count -gt 0) {
        Write-Host "`n❌ Permissions that failed (require manual admin consent):" -ForegroundColor Red
        foreach ($failed in $results.Failed) {
            Write-Host "   - $failed" -ForegroundColor Red
        }
        
        Write-Host "`n💡 To grant failed permissions manually:" -ForegroundColor Yellow
        Write-Host "   1. Go to Azure Portal > Azure Active Directory > App registrations" -ForegroundColor White
        Write-Host "   2. Find your app: $ServicePrincipalAppId" -ForegroundColor White
        Write-Host "   3. Go to 'API permissions'" -ForegroundColor White
        Write-Host "   4. Add the missing permissions manually" -ForegroundColor White
        Write-Host "   5. Click 'Grant admin consent' button" -ForegroundColor White
    }
    
    if ($WhatIf) {
        Write-Host "`n🎯 To apply these changes, run without -WhatIf parameter" -ForegroundColor Yellow
    } elseif ($totalSuccess -eq $requiredPermissions.Count) {
        Write-Host "`n🎉 SUCCESS! All required permissions are now configured!" -ForegroundColor Green
        Write-Host "🔄 Your Azure DevOps pipeline should now work perfectly!" -ForegroundColor Green
    } elseif ($results.Failed.Count -gt 0) {
        Write-Host "`n⚠️ Partial success - some permissions need manual granting" -ForegroundColor Yellow
        Write-Host "📋 Current permissions may be sufficient for basic EasyPIM functionality" -ForegroundColor Cyan
        Write-Host "🧪 Test your pipeline to see if it works with current permissions" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "`n❌ SCRIPT ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host "`n💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   - Ensure you're logged into Azure CLI: az login" -ForegroundColor White
    Write-Host "   - Make sure you have Global Administrator or Application Administrator role" -ForegroundColor White
    Write-Host "   - Verify the service principal exists: $ServicePrincipalAppId" -ForegroundColor White
    Write-Host "   - Check network connectivity to Microsoft Graph API" -ForegroundColor White
    exit 1
}

Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "1. Validate permissions: .\validate-all-permissions.ps1" -ForegroundColor White
Write-Host "2. Test Azure DevOps pipeline: .\trigger-build.ps1" -ForegroundColor White
Write-Host "3. Monitor EasyPIM execution in Azure DevOps logs" -ForegroundColor White
Write-Host "`n✨ Your EasyPIM Azure DevOps integration is ready! ✨" -ForegroundColor Green
