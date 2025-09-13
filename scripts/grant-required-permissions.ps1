#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications

<#
.SYNOPSIS
    Grant required Microsoft Graph API permissions for EasyPIM

.DESCRIPTION
    This script grants the necessary Microsoft Graph API permissions for EasyPIM to function
    in CI/CD environments. It requires Global Administrator privileges.

.PARAMETER ServicePrincipalId
    The Object ID of the service principal (not the App ID)

.PARAMETER TenantId
    Azure AD Tenant ID (optional - uses current context if not specified)

.EXAMPLE
    .\grant-required-permissions.ps1 -ServicePrincipalId "12345678-1234-1234-1234-123456789012"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServicePrincipalId,
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Required Microsoft Graph permissions for EasyPIM
$requiredPermissions = @(
    'Directory.Read.All',
    'RoleManagement.ReadWrite.Directory',
    'Application.Read.All',
    'User.Read.All',
    'Group.Read.All'
)

Write-Host "🔐 EasyPIM Microsoft Graph Permissions Setup" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta

# Import Microsoft Graph modules
Write-Host "📦 Checking Microsoft Graph PowerShell modules..." -ForegroundColor Yellow

$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Applications')
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
    Import-Module -Name $module -Force
}

Write-Host "✅ Microsoft Graph modules ready!" -ForegroundColor Green

# Connect to Microsoft Graph
Write-Host "🔐 Connecting to Microsoft Graph..." -ForegroundColor Yellow

$connectParams = @{
    Scopes = @('Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All')
}

if ($TenantId) {
    $connectParams.TenantId = $TenantId
}

Connect-MgGraph @connectParams

$context = Get-MgContext
Write-Host "✅ Connected to Microsoft Graph" -ForegroundColor Green
Write-Host "🏢 Tenant: $($context.TenantId)" -ForegroundColor Cyan

# Get the Microsoft Graph service principal
Write-Host "🔍 Finding Microsoft Graph service principal..." -ForegroundColor Yellow
$graphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -ErrorAction Stop
Write-Host "✅ Microsoft Graph service principal found: $($graphServicePrincipal.Id)" -ForegroundColor Green

# Verify target service principal exists
Write-Host "🔍 Verifying target service principal: $ServicePrincipalId" -ForegroundColor Yellow
try {
    $targetServicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
    Write-Host "✅ Target service principal found: $($targetServicePrincipal.DisplayName)" -ForegroundColor Green
} catch {
    Write-Error "Service principal not found: $ServicePrincipalId"
    Write-Host "Make sure you're using the Object ID (not App ID) of the service principal." -ForegroundColor Red
    exit 1
}

# Grant each required permission
Write-Host "`n🔧 Granting Microsoft Graph API permissions..." -ForegroundColor Yellow

foreach ($permission in $requiredPermissions) {
    Write-Host "📋 Processing permission: $permission" -ForegroundColor Cyan
    
    # Find the app role for this permission
    $appRole = $graphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $permission }
    
    if (!$appRole) {
        Write-Warning "Permission not found: $permission"
        continue
    }
    
    # Check if permission is already granted
    $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId |
        Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceId -eq $graphServicePrincipal.Id }
    
    if ($existingAssignment) {
        Write-Host "   ✅ Already granted: $permission" -ForegroundColor Green
    } else {
        try {
            # Grant the permission
            $assignment = @{
                PrincipalId = $ServicePrincipalId
                ResourceId = $graphServicePrincipal.Id
                AppRoleId = $appRole.Id
            }
            
            New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId -BodyParameter $assignment | Out-Null
            Write-Host "   ✅ Granted: $permission" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to grant permission: $permission - $($_.Exception.Message)"
        }
    }
}

# Summary
Write-Host "`n📋 Permission Grant Summary:" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

$grantedPermissions = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId |
    Where-Object { $_.ResourceId -eq $graphServicePrincipal.Id }

Write-Host "Service Principal: $($targetServicePrincipal.DisplayName)" -ForegroundColor White
Write-Host "Total Permissions: $($grantedPermissions.Count)" -ForegroundColor White

$grantedPermissions | ForEach-Object {
    $roleName = ($graphServicePrincipal.AppRoles | Where-Object { $_.Id -eq $_.AppRoleId }).Value
    Write-Host "  ✅ $roleName" -ForegroundColor Green
}

Write-Host "`n🎉 Permission setup completed!" -ForegroundColor Green
Write-Host "`n📝 Important Notes:" -ForegroundColor Yellow
Write-Host "• These permissions require Global Administrator consent" -ForegroundColor White
Write-Host "• Permissions are application-level (not delegated)" -ForegroundColor White
Write-Host "• Test your CI/CD pipelines to ensure permissions work correctly" -ForegroundColor White

# Disconnect from Microsoft Graph
Disconnect-MgGraph | Out-Null
Write-Host "`n✅ Disconnected from Microsoft Graph" -ForegroundColor Green
