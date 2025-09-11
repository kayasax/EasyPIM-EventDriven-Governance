# Grant EasyPIM Graph Permissions - Fixed Version
# Uses Microsoft Graph REST API directly for reliability

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",
    [switch]$WhatIf = $false
)

Write-Host "🔐 Granting EasyPIM Microsoft Graph Permissions (Fixed Version)" -ForegroundColor Green

# Check Azure CLI authentication
try {
    $account = az account show --query "{subscriptionId:id, tenantId:tenantId, user:user.name}" | ConvertFrom-Json
    Write-Host "✅ Authenticated as: $($account.user)" -ForegroundColor Green
    Write-Host "📋 Tenant: $($account.tenantId)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Please login to Azure CLI first: az login" -ForegroundColor Red
    exit 1
}

# Required permissions with their IDs (these are standard Microsoft Graph permission IDs)
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

Write-Host "`n📋 Service Principal: $ServicePrincipalAppId" -ForegroundColor Cyan
Write-Host "📋 Required permissions: $($permissions.Count)" -ForegroundColor Cyan

# Get Microsoft Graph and target service principals
$graphAppId = "00000003-0000-0000-c000-000000000000"

Write-Host "`n🔍 Getting service principals..." -ForegroundColor Yellow

try {
    # Get Microsoft Graph service principal
    $graphSPResponse = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$graphAppId'&`$select=id,displayName" --query "value[0]"
    $graphSP = $graphSPResponse | ConvertFrom-Json
    
    if (-not $graphSP) {
        throw "Microsoft Graph service principal not found"
    }
    
    Write-Host "✅ Microsoft Graph SP: $($graphSP.displayName) ($($graphSP.id))" -ForegroundColor Green
    
    # Get target service principal
    $targetSPResponse = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$ServicePrincipalAppId'&`$select=id,displayName" --query "value[0]"
    $targetSP = $targetSPResponse | ConvertFrom-Json
    
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
    $currentAssignments = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments?`$filter=resourceId eq $($graphSP.id)" --query "value" | ConvertFrom-Json
    Write-Host "📋 Current Graph permissions: $($currentAssignments.Count)" -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ Could not check current permissions" -ForegroundColor Yellow
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
        } | ConvertTo-Json -Compress
        
        try {
            $result = az rest --method POST --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.id)/appRoleAssignments" --headers "Content-Type=application/json" --body $body 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Granted: $permissionName" -ForegroundColor Green
                $grantedCount++
            } else {
                if ($result -match "Permission being assigned already exists") {
                    Write-Host "   ✅ Already granted: $permissionName" -ForegroundColor Cyan
                    $alreadyGrantedCount++
                } else {
                    Write-Host "   ❌ Failed: $result" -ForegroundColor Red
                    $failedCount++
                }
            }
        } catch {
            Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            $failedCount++
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
    
    if ($grantedCount -gt 0) {
        Write-Host "`n🎉 NEW PERMISSIONS GRANTED!" -ForegroundColor Green
        Write-Host "✅ Your Azure DevOps pipeline should now work!" -ForegroundColor Green
        Write-Host "`n📋 Next steps:" -ForegroundColor Cyan
        Write-Host "   1. Wait 2-3 minutes for permissions to propagate" -ForegroundColor White
        Write-Host "   2. Run: .\trigger-build.ps1 -PAT 'your_token'" -ForegroundColor White
        Write-Host "   3. The Microsoft Graph authentication should succeed!" -ForegroundColor White
    } elseif ($alreadyGrantedCount -eq $permissions.Count) {
        Write-Host "`n✅ All permissions already granted!" -ForegroundColor Green
        Write-Host "🔄 Try your pipeline again - it should work now!" -ForegroundColor Green
    }
}
