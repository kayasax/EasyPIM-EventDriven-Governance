# Grant ALL EasyPIM Required Microsoft Graph Permissions
# This script ensures ALL necessary permissions are configured for EasyPIM to work with Azure DevOps service principal
# Handles module conflicts and provides comprehensive permission management

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",  # Your Azure DevOps service principal
    [switch]$WhatIf = $false,
    [switch]$Force = $false  # Force reinstall modules if needed
)

Write-Host "🔐 EasyPIM Complete Permission Configuration Script" -ForegroundColor Green
Write-Host "📋 Service Principal App ID: $ServicePrincipalAppId" -ForegroundColor Cyan

# ALL required Microsoft Graph permissions for EasyPIM (comprehensive list)
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

Write-Host "`n📋 ALL Required permissions for EasyPIM:" -ForegroundColor Yellow
foreach ($permission in $requiredPermissions) {
    Write-Host "   - $($permission.Name)" -ForegroundColor White
    Write-Host "     $($permission.Description)" -ForegroundColor Gray
}

if ($WhatIf) {
    Write-Host "`n⚠️ WHAT-IF MODE: No changes will be made" -ForegroundColor Yellow
} else {
    Write-Host "`n🚀 Configuring ALL permissions..." -ForegroundColor Green
}

try {
    # Clean module loading to avoid conflicts
    Write-Host "`n🔧 Preparing Microsoft Graph PowerShell environment..." -ForegroundColor Cyan
    
    # Remove any existing Microsoft Graph modules from memory to avoid conflicts
    $graphModules = Get-Module | Where-Object { $_.Name -like "Microsoft.Graph*" }
    if ($graphModules) {
        Write-Host "🔄 Cleaning existing Microsoft Graph modules from memory..." -ForegroundColor Yellow
        foreach ($module in $graphModules) {
            Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
        }
    }

    # Disconnect any existing Graph sessions
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    } catch {
        # Ignore if not connected
    }

    # Install required modules with proper dependencies
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Applications", 
        "Microsoft.Graph.Identity.DirectoryManagement"
    )

    foreach ($moduleName in $requiredModules) {
        Write-Host "📦 Checking module: $moduleName..." -ForegroundColor Cyan
        
        $module = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
        
        if (-not $module -or $Force) {
            Write-Host "   Installing $moduleName..." -ForegroundColor Yellow
            Install-Module -Name $moduleName -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck
        } else {
            Write-Host "   ✅ $moduleName available (v$($module.Version))" -ForegroundColor Green
        }
        
        # Import with force to avoid conflicts
        Write-Host "   Loading $moduleName..." -ForegroundColor Cyan
        Import-Module $moduleName -Force -Global
    }

    # Authenticate to Microsoft Graph PowerShell with comprehensive scopes
    Write-Host "`n🔐 Authenticating to Microsoft Graph PowerShell..." -ForegroundColor Cyan
    Write-Host "   Required scopes: Application.ReadWrite.All, Directory.ReadWrite.All" -ForegroundColor Gray
    
    try {
        # Check if already connected
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $context) {
            throw "Not authenticated"
        }
        
        # Verify we have the required scopes
        $requiredScopes = @("Application.ReadWrite.All", "Directory.ReadWrite.All")
        $missingScopes = $requiredScopes | Where-Object { $_ -notin $context.Scopes }
        
        if ($missingScopes) {
            Write-Host "   ⚠️ Missing required scopes: $($missingScopes -join ', ')" -ForegroundColor Yellow
            throw "Insufficient scopes"
        }
        
        Write-Host "   ✅ Already authenticated with sufficient permissions" -ForegroundColor Green
        Write-Host "     Account: $($context.Account)" -ForegroundColor Gray
        Write-Host "     Scopes: $($context.Scopes -join ', ')" -ForegroundColor Gray
    } catch {
        Write-Host "   🔑 Connecting to Microsoft Graph (admin consent required)..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome
        
        $context = Get-MgContext
        Write-Host "   ✅ Successfully authenticated" -ForegroundColor Green
        Write-Host "     Account: $($context.Account)" -ForegroundColor Gray
        Write-Host "     Scopes: $($context.Scopes -join ', ')" -ForegroundColor Gray
    }

    # Get Microsoft Graph service principal
    Write-Host "`n🔍 Finding Microsoft Graph service principal..." -ForegroundColor Cyan
    $graphSP = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -ErrorAction Stop
    
    if (-not $graphSP) {
        throw "Microsoft Graph service principal not found"
    }
    
    Write-Host "   ✅ Microsoft Graph service principal found: $($graphSP.Id)" -ForegroundColor Green
    Write-Host "     Display Name: $($graphSP.DisplayName)" -ForegroundColor Gray

    # Get target service principal (Azure DevOps)
    Write-Host "`n🔍 Finding target service principal..." -ForegroundColor Cyan
    $targetSP = Get-MgServicePrincipal -Filter "appId eq '$ServicePrincipalAppId'" -ErrorAction Stop
    
    if (-not $targetSP) {
        throw "Target service principal not found: $ServicePrincipalAppId"
    }
    
    Write-Host "   ✅ Target service principal found: $($targetSP.DisplayName)" -ForegroundColor Green
    Write-Host "     Service Principal ID: $($targetSP.Id)" -ForegroundColor Gray
    Write-Host "     App ID: $($targetSP.AppId)" -ForegroundColor Gray

    # Get current permissions
    Write-Host "`n🔍 Analyzing current permissions..." -ForegroundColor Cyan
    $currentPermissions = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetSP.Id | Where-Object { $_.ResourceId -eq $graphSP.Id }
    
    Write-Host "   📋 Current permission count: $($currentPermissions.Count)" -ForegroundColor White
    
    if ($currentPermissions.Count -gt 0) {
        Write-Host "   📝 Currently granted permissions:" -ForegroundColor Gray
        foreach ($perm in $currentPermissions) {
            $appRole = $graphSP.AppRoles | Where-Object { $_.Id -eq $perm.AppRoleId }
            if ($appRole) {
                Write-Host "      - $($appRole.Value)" -ForegroundColor Gray
            }
        }
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
        $appRole = $graphSP.AppRoles | Where-Object { $_.Value -eq $permissionName }
        
        if (-not $appRole) {
            Write-Host "   ❌ Permission not found in Microsoft Graph app roles: $permissionName" -ForegroundColor Red
            $results.NotFound += $permissionName
            continue
        }
        
        Write-Host "   📋 App Role ID: $($appRole.Id)" -ForegroundColor Gray
        
        # Check if already granted
        $existingAssignment = $currentPermissions | Where-Object { $_.AppRoleId -eq $appRole.Id }
        
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
                # Grant the permission
                Write-Host "   🔑 Granting permission..." -ForegroundColor Yellow
                
                $params = @{
                    PrincipalId = $targetSP.Id
                    ResourceId = $graphSP.Id
                    AppRoleId = $appRole.Id
                }
                
                $assignment = New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetSP.Id -BodyParameter $params
                Write-Host "   ✅ Successfully granted: $permissionName" -ForegroundColor Green
                Write-Host "      Assignment ID: $($assignment.Id)" -ForegroundColor Gray
                $results.Granted += $permissionName
                
                # Small delay to avoid rate limiting
                Start-Sleep -Milliseconds 500
                
            } catch {
                Write-Host "   ❌ Failed to grant: $permissionName" -ForegroundColor Red
                Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed += $permissionName
                
                # Check if it's a 400 Bad Request (often means manual consent needed)
                if ($_.Exception.Message -like "*400*" -or $_.Exception.Message -like "*Bad Request*") {
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
    
    if ($results.Failed.Count -gt 0) {
        Write-Host "`n❌ Permissions that failed (may need manual admin consent):" -ForegroundColor Red
        foreach ($failedPerm in $results.Failed) {
            Write-Host "   - $failedPerm" -ForegroundColor Red
        }
    }
    
    if ($results.NotFound.Count -gt 0) {
        Write-Host "`n❓ Permissions not found in Microsoft Graph:" -ForegroundColor Magenta
        foreach ($notFoundPerm in $results.NotFound) {
            Write-Host "   - $notFoundPerm" -ForegroundColor Magenta
        }
    }
    
    if ($WhatIf) {
        Write-Host "`n🎯 To apply these changes, run without -WhatIf parameter" -ForegroundColor Yellow
    } elseif ($totalSuccess -eq $requiredPermissions.Count) {
        Write-Host "`n🎉 SUCCESS! All required permissions are now configured!" -ForegroundColor Green
        Write-Host "🔄 Your Azure DevOps pipeline should now work perfectly!" -ForegroundColor Green
    } elseif ($results.Failed.Count -gt 0) {
        Write-Host "`n⚠️ Some permissions require manual admin consent:" -ForegroundColor Yellow
        Write-Host "   1. Go to Azure Portal > Azure Active Directory > App registrations" -ForegroundColor White
        Write-Host "   2. Find your app: $ServicePrincipalAppId" -ForegroundColor White
        Write-Host "   3. Go to 'API permissions'" -ForegroundColor White
        Write-Host "   4. Click 'Grant admin consent' for failed permissions" -ForegroundColor White
    }
    
} catch {
    Write-Host "`n❌ SCRIPT ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "`n💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   - Make sure you're running as a Global Administrator" -ForegroundColor White
    Write-Host "   - Ensure you have Application.ReadWrite.All permissions" -ForegroundColor White
    Write-Host "   - Try running with -Force to reinstall modules" -ForegroundColor White
    Write-Host "   - Check if the service principal exists: $ServicePrincipalAppId" -ForegroundColor White
    exit 1
}

Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "1. Review the permission summary above" -ForegroundColor White
Write-Host "2. Grant admin consent for any failed permissions (if needed)" -ForegroundColor White
Write-Host "3. Run your Azure DevOps pipeline: .\trigger-build.ps1" -ForegroundColor White
Write-Host "4. EasyPIM should now have ALL required permissions!" -ForegroundColor White
Write-Host "`n✨ Your EasyPIM CICD is ready for production! ✨" -ForegroundColor Green
