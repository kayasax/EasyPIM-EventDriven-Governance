# Grant EasyPIM Graph Permissions using Azure CLI
# Alternative method using az cli commands

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",
    [switch]$WhatIf = $false
)

Write-Host "🔐 Granting EasyPIM Microsoft Graph Permissions via Azure CLI" -ForegroundColor Green

# Check Azure CLI authentication
try {
    $account = az account show --query "{subscriptionId:id, tenantId:tenantId, user:user.name}" | ConvertFrom-Json
    Write-Host "✅ Authenticated as: $($account.user)" -ForegroundColor Green
} catch {
    Write-Host "❌ Please login to Azure CLI first: az login" -ForegroundColor Red
    exit 1
}

# Required permissions for EasyPIM
$permissions = @(
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

Write-Host "`n📋 Service Principal: $ServicePrincipalAppId" -ForegroundColor Cyan
Write-Host "📋 Required permissions: $($permissions.Count)" -ForegroundColor Cyan

# Get Microsoft Graph App ID
$graphAppId = "00000003-0000-0000-c000-000000000000"

Write-Host "`n🔍 Getting Microsoft Graph service principal..." -ForegroundColor Yellow
$graphSP = az ad sp show --id $graphAppId --query "{objectId:id, appId:appId, displayName:displayName}" | ConvertFrom-Json

if (-not $graphSP) {
    Write-Host "❌ Microsoft Graph service principal not found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Microsoft Graph SP: $($graphSP.displayName)" -ForegroundColor Green

Write-Host "`n🔍 Getting target service principal..." -ForegroundColor Yellow
$targetSP = az ad sp show --id $ServicePrincipalAppId --query "{objectId:id, appId:appId, displayName:displayName}" | ConvertFrom-Json

if (-not $targetSP) {
    Write-Host "❌ Target service principal not found: $ServicePrincipalAppId" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Target SP: $($targetSP.displayName)" -ForegroundColor Green

# Get Microsoft Graph app roles via REST API
Write-Host "`n🔍 Getting Microsoft Graph app roles..." -ForegroundColor Yellow
try {
    $graphAppResponse = az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications?`$filter=appId eq '$graphAppId'&`$select=appRoles" --query "value[0]"
    if (-not $graphAppResponse) {
        # Fallback: get from service principal instead
        $graphAppResponse = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($graphSP.objectId)?`$select=appRoles"
    }
    $graphApp = $graphAppResponse | ConvertFrom-Json
} catch {
    Write-Host "❌ Failed to get Microsoft Graph app roles: $_" -ForegroundColor Red
    exit 1
}

$grantedCount = 0
$alreadyGrantedCount = 0

foreach ($permission in $permissions) {
    Write-Host "`n📋 Processing: $permission" -ForegroundColor Cyan
    
    # Find the app role
    $appRole = $graphApp.appRoles | Where-Object { $_.value -eq $permission }
    
    if (-not $appRole) {
        Write-Host "   ❌ App role not found: $permission" -ForegroundColor Red
        continue
    }
    
    Write-Host "   🔍 App Role ID: $($appRole.id)" -ForegroundColor White
    
    if ($WhatIf) {
        Write-Host "   🎯 Would grant: $permission" -ForegroundColor Yellow
        $grantedCount++
    } else {
        # Grant the permission using az rest
        Write-Host "   🚀 Granting permission..." -ForegroundColor Yellow
        
        $body = @{
            principalId = $targetSP.objectId
            resourceId = $graphSP.objectId  
            appRoleId = $appRole.id
        } | ConvertTo-Json -Compress
        
        try {
            $result = az rest --method POST --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($targetSP.objectId)/appRoleAssignments" --headers "Content-Type=application/json" --body $body 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Granted: $permission" -ForegroundColor Green
                $grantedCount++
            } else {
                if ($result -match "Permission being assigned already exists") {
                    Write-Host "   ✅ Already granted: $permission" -ForegroundColor Cyan
                    $alreadyGrantedCount++
                } else {
                    Write-Host "   ❌ Failed: $result" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Green
if ($WhatIf) {
    Write-Host "   🎯 Would grant: $grantedCount permissions" -ForegroundColor Yellow
    Write-Host "   📋 Run without -WhatIf to apply changes" -ForegroundColor Cyan
} else {
    Write-Host "   ✅ Newly granted: $grantedCount" -ForegroundColor Green
    Write-Host "   ✅ Already had: $alreadyGrantedCount" -ForegroundColor Cyan
    Write-Host "   📋 Total required: $($permissions.Count)" -ForegroundColor White
    
    if ($grantedCount -gt 0) {
        Write-Host "`n🎉 Permissions granted successfully!" -ForegroundColor Green
        Write-Host "🔄 Your Azure DevOps pipeline should now work!" -ForegroundColor Green
    }
}

Write-Host "`nNext: Test your Azure DevOps pipeline - Microsoft Graph authentication should succeed!" -ForegroundColor Cyan
