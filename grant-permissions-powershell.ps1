# Grant EasyPIM Permissions - PowerShell Graph API Method
# Uses direct PowerShell with Microsoft Graph API

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",
    [switch]$WhatIf = $false
)

Write-Host "🔐 Granting EasyPIM Permissions via PowerShell Microsoft Graph" -ForegroundColor Green

# Get access token from Azure CLI
Write-Host "🔍 Getting access token..." -ForegroundColor Cyan
try {
    $accessToken = az account get-access-token --resource https://graph.microsoft.com --query "accessToken" -o tsv
    if (-not $accessToken) {
        throw "Failed to get access token"
    }
    Write-Host "✅ Access token obtained" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to get access token. Please run: az login" -ForegroundColor Red
    exit 1
}

# Set up headers
$headers = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

# Required permissions with their IDs
$permissions = @{
    "Directory.Read.All" = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
    "RoleManagement.ReadWrite.Directory" = "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8"
    "User.Read.All" = "df021288-bdef-4463-88db-98f22de89214"
    "PrivilegedAccess.ReadWrite.AzureADGroup" = "32531c59-1f32-461f-b8a6-5e0b27ecc8e4"
    "PrivilegedAccess.ReadWrite.AzureResources" = "6f9d5abc-2db6-400b-a267-7de22a40fb87"
    "RoleManagementPolicy.ReadWrite.Directory" = "f6403079-c605-4dd1-b2c6-7054ac2e55ec"
    "RoleManagementPolicy.ReadWrite.AzureADGroup" = "dbaae8cf-10b5-4f43-81ac-6bb7e323b3ed"
    "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup" = "ca7d8fcb-5c5e-4c9d-b15f-9b2b78c7444d"
    "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup" = "b38bfd45-7d71-4fea-9840-3d06853ba384"
}

Write-Host "📋 Service Principal: $ServicePrincipalAppId" -ForegroundColor Cyan
Write-Host "📋 Permissions to grant: $($permissions.Count)" -ForegroundColor Cyan

# Get service principals
Write-Host "`n🔍 Getting service principals..." -ForegroundColor Yellow

try {
    # Get Microsoft Graph service principal
    $graphSPUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id,displayName"
    $graphSPResponse = Invoke-RestMethod -Uri $graphSPUri -Headers $headers -Method GET
    $graphSP = $graphSPResponse.value[0]
    
    if (-not $graphSP) {
        throw "Microsoft Graph service principal not found"
    }
    
    Write-Host "✅ Microsoft Graph SP: $($graphSP.displayName) ($($graphSP.id))" -ForegroundColor Green
    
    # Get target service principal
    $targetSPUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$ServicePrincipalAppId'&`$select=id,displayName"
    $targetSPResponse = Invoke-RestMethod -Uri $targetSPUri -Headers $headers -Method GET
    $targetSP = $targetSPResponse.value[0]
    
    if (-not $targetSP) {
        throw "Target service principal not found: $ServicePrincipalAppId"
    }
    
    Write-Host "✅ Target SP: $($targetSP.displayName) ($($targetSP.id))" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error getting service principals: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check current permissions
Write-Host "`n🔍 Checking current permissions..." -ForegroundColor Yellow
try {
    $currentUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments?`$filter=resourceId eq $($graphSP.id)"
    $currentResponse = Invoke-RestMethod -Uri $currentUri -Headers $headers -Method GET
    $currentAssignments = $currentResponse.value
    Write-Host "📋 Current Graph permissions: $($currentAssignments.Count)" -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ Could not check current permissions: $($_.Exception.Message)" -ForegroundColor Yellow
    $currentAssignments = @()
}

$grantedCount = 0
$alreadyGrantedCount = 0
$failedCount = 0

foreach ($permissionName in $permissions.Keys) {
    $appRoleId = $permissions[$permissionName]
    
    Write-Host "`n📋 Processing: $permissionName" -ForegroundColor Cyan
    Write-Host "   🔍 App Role ID: $appRoleId" -ForegroundColor White
    
    # Check if already granted
    $existingAssignment = $currentAssignments | Where-Object { $_.appRoleId -eq $appRoleId }
    
    if ($existingAssignment) {
        Write-Host "   ✅ Already granted: $permissionName" -ForegroundColor Green
        $alreadyGrantedCount++
        continue
    }
    
    if ($WhatIf) {
        Write-Host "   🎯 Would grant: $permissionName" -ForegroundColor Yellow
        $grantedCount++
    } else {
        # Grant the permission
        Write-Host "   🚀 Granting permission..." -ForegroundColor Yellow
        
        $body = @{
            principalId = $targetSP.id
            resourceId = $graphSP.id
            appRoleId = $appRoleId
        } | ConvertTo-Json
        
        try {
            $grantUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments"
            $result = Invoke-RestMethod -Uri $grantUri -Headers $headers -Method POST -Body $body
            
            Write-Host "   ✅ Granted: $permissionName" -ForegroundColor Green
            $grantedCount++
        } catch {
            if ($_.Exception.Response.StatusCode -eq 409 -or $_.Exception.Message -match "already exists") {
                Write-Host "   ✅ Already granted: $permissionName" -ForegroundColor Cyan
                $alreadyGrantedCount++
            } else {
                Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failedCount++
            }
        }
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Green
if ($WhatIf) {
    Write-Host "   🎯 Would grant: $grantedCount permissions" -ForegroundColor Yellow
    Write-Host "   ✅ Already have: $alreadyGrantedCount permissions" -ForegroundColor Cyan
    Write-Host "   📋 Run without -WhatIf to apply changes" -ForegroundColor Cyan
} else {
    Write-Host "   ✅ Newly granted: $grantedCount" -ForegroundColor Green
    Write-Host "   ✅ Already had: $alreadyGrantedCount" -ForegroundColor Cyan
    Write-Host "   ❌ Failed: $failedCount" -ForegroundColor Red
    Write-Host "   📋 Total required: $($permissions.Count)" -ForegroundColor White
    
    $totalSuccessful = $grantedCount + $alreadyGrantedCount
    
    if ($totalSuccessful -eq $permissions.Count) {
        Write-Host "`n🎉 ALL PERMISSIONS GRANTED!" -ForegroundColor Green
        Write-Host "✅ Your Azure DevOps pipeline should now work with EasyPIM!" -ForegroundColor Green
        
        Write-Host "`n📋 Next steps:" -ForegroundColor Cyan
        Write-Host "   1. Wait 2-3 minutes for permissions to propagate" -ForegroundColor White
        Write-Host "   2. Run your Azure DevOps pipeline" -ForegroundColor White
        Write-Host "   3. Microsoft Graph authentication should succeed!" -ForegroundColor White
        Write-Host "   4. EasyPIM should execute without permission errors!" -ForegroundColor White
        
    } elseif ($grantedCount -gt 0) {
        Write-Host "`n🎉 PROGRESS! $grantedCount new permissions granted!" -ForegroundColor Green
        Write-Host "⚠️ Some permissions failed - may need manual consent in Azure portal" -ForegroundColor Yellow
        
    } else {
        Write-Host "`n⚠️ No new permissions granted" -ForegroundColor Yellow
        if ($failedCount -gt 0) {
            Write-Host "💡 Consider granting permissions manually in Azure portal" -ForegroundColor Cyan
            Write-Host "   1. Go to Azure AD > App registrations > Your app > API permissions" -ForegroundColor White
            Write-Host "   2. Add Microsoft Graph permissions listed above" -ForegroundColor White
            Write-Host "   3. Grant admin consent" -ForegroundColor White
        }
    }
}
