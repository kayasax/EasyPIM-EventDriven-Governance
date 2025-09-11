# Comprehensive EasyPIM Permission Validator
# Validates ALL required Microsoft Graph permissions for EasyPIM Azure DevOps integration
# Provides detailed analysis and actionable recommendations

param(
    [string]$ServicePrincipalAppId = "0b8f3449-b493-457a-806b-5c76a1870f27",
    [switch]$Detailed = $false
)

Write-Host "🔍 EasyPIM Complete Permission Validation" -ForegroundColor Green
Write-Host "📋 Service Principal App ID: $ServicePrincipalAppId" -ForegroundColor Cyan

# Complete list of ALL required permissions for EasyPIM
$requiredPermissions = @(
    @{ 
        Name = "Directory.Read.All"; 
        Description = "Read directory data"; 
        Critical = $true;
        Category = "Core"
    },
    @{ 
        Name = "Directory.ReadWrite.All"; 
        Description = "Read and write directory data"; 
        Critical = $false;
        Category = "Enhanced"
    },
    @{ 
        Name = "PrivilegedAccess.ReadWrite.AzureADGroup"; 
        Description = "Read and write privileged access for Azure AD groups"; 
        Critical = $true;
        Category = "PIM"
    },
    @{ 
        Name = "PrivilegedAccess.ReadWrite.AzureResources"; 
        Description = "Read and write privileged access for Azure resources"; 
        Critical = $true;
        Category = "PIM"
    },
    @{ 
        Name = "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup"; 
        Description = "Read and write privileged assignment schedules for Azure AD groups"; 
        Critical = $true;
        Category = "PIM"
    },
    @{ 
        Name = "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup"; 
        Description = "Read and write privileged eligibility schedules for Azure AD groups"; 
        Critical = $true;
        Category = "PIM"
    },
    @{ 
        Name = "RoleManagement.ReadWrite.Directory"; 
        Description = "Read and write role management data in directory"; 
        Critical = $true;
        Category = "Core"
    },
    @{ 
        Name = "RoleManagementPolicy.ReadWrite.AzureADGroup"; 
        Description = "Read and write role management policies for Azure AD groups"; 
        Critical = $true;
        Category = "PIM"
    },
    @{ 
        Name = "RoleManagementPolicy.ReadWrite.Directory"; 
        Description = "Read and write role management policies in directory"; 
        Critical = $true;
        Category = "PIM"
    },
    @{ 
        Name = "User.Read.All"; 
        Description = "Read all users' basic profiles"; 
        Critical = $true;
        Category = "Core"
    },
    @{ 
        Name = "Application.Read.All"; 
        Description = "Read applications and service principals"; 
        Critical = $false;
        Category = "Enhanced"
    },
    @{ 
        Name = "Group.Read.All"; 
        Description = "Read all groups"; 
        Critical = $false;
        Category = "Enhanced"
    }
)

try {
    # Authenticate to Microsoft Graph if needed
    Write-Host "`n🔐 Checking Microsoft Graph authentication..." -ForegroundColor Cyan
    
    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $context) {
            throw "Not authenticated"
        }
        Write-Host "   ✅ Already authenticated" -ForegroundColor Green
    } catch {
        Write-Host "   🔑 Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Import-Module Microsoft.Graph.Authentication -Force
        Import-Module Microsoft.Graph.Applications -Force
        Connect-MgGraph -Scopes "Application.Read.All", "Directory.Read.All" -NoWelcome
    }

    # Get Microsoft Graph service principal
    Write-Host "`n🔍 Finding Microsoft Graph service principal..." -ForegroundColor Cyan
    $graphSP = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
    
    if (-not $graphSP) {
        throw "Microsoft Graph service principal not found"
    }
    
    Write-Host "   ✅ Microsoft Graph service principal found" -ForegroundColor Green

    # Get target service principal
    Write-Host "`n🔍 Finding target service principal..." -ForegroundColor Cyan
    $targetSP = Get-MgServicePrincipal -Filter "appId eq '$ServicePrincipalAppId'"
    
    if (-not $targetSP) {
        throw "Target service principal not found: $ServicePrincipalAppId"
    }
    
    Write-Host "   ✅ Target service principal found: $($targetSP.DisplayName)" -ForegroundColor Green

    # Get current permissions
    Write-Host "`n📊 Analyzing current permissions..." -ForegroundColor Cyan
    $currentPermissions = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetSP.Id | Where-Object { $_.ResourceId -eq $graphSP.Id }
    
    # Analyze each permission
    $results = @{
        Core = @{ Granted = @(); Missing = @(); Total = 0 }
        PIM = @{ Granted = @(); Missing = @(); Total = 0 }
        Enhanced = @{ Granted = @(); Missing = @(); Total = 0 }
        Critical = @{ Granted = @(); Missing = @(); Total = 0 }
        All = @{ Granted = @(); Missing = @(); Total = $requiredPermissions.Count }
    }
    
    Write-Host "`n🔍 DETAILED PERMISSION ANALYSIS:" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    
    foreach ($category in @("Core", "PIM", "Enhanced")) {
        $categoryPerms = $requiredPermissions | Where-Object { $_.Category -eq $category }
        $results[$category].Total = $categoryPerms.Count
        
        Write-Host "`n📂 $category Permissions ($($categoryPerms.Count)):" -ForegroundColor Yellow
        
        foreach ($permission in $categoryPerms) {
            $permissionName = $permission.Name
            
            # Find the permission in Microsoft Graph app roles
            $appRole = $graphSP.AppRoles | Where-Object { $_.Value -eq $permissionName }
            
            if ($appRole) {
                # Check if granted
                $isGranted = $currentPermissions | Where-Object { $_.AppRoleId -eq $appRole.Id }
                
                if ($isGranted) {
                    Write-Host "   ✅ $permissionName" -ForegroundColor Green
                    $results[$category].Granted += $permission
                    $results.All.Granted += $permission
                    
                    if ($permission.Critical) {
                        $results.Critical.Granted += $permission
                    }
                } else {
                    $status = if ($permission.Critical) { "❌" } else { "⚠️" }
                    $color = if ($permission.Critical) { "Red" } else { "Yellow" }
                    Write-Host "   $status $permissionName" -ForegroundColor $color
                    $results[$category].Missing += $permission
                    $results.All.Missing += $permission
                    
                    if ($permission.Critical) {
                        $results.Critical.Missing += $permission
                    }
                }
                
                if ($Detailed) {
                    Write-Host "      Description: $($permission.Description)" -ForegroundColor Gray
                    Write-Host "      App Role ID: $($appRole.Id)" -ForegroundColor Gray
                    if ($permission.Critical) {
                        Write-Host "      ⚠️ CRITICAL for EasyPIM functionality" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "   ❓ $permissionName (NOT FOUND IN GRAPH)" -ForegroundColor Magenta
                $results[$category].Missing += $permission
                $results.All.Missing += $permission
            }
        }
    }
    
    # Calculate critical permission status
    $criticalPerms = $requiredPermissions | Where-Object { $_.Critical -eq $true }
    $results.Critical.Total = $criticalPerms.Count
    
    # Summary statistics
    Write-Host "`n📊 COMPREHENSIVE SUMMARY:" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    
    foreach ($category in @("All", "Critical", "Core", "PIM", "Enhanced")) {
        $granted = $results[$category].Granted.Count
        $total = $results[$category].Total
        $percentage = if ($total -gt 0) { [math]::Round(($granted / $total) * 100, 1) } else { 0 }
        
        $statusColor = if ($percentage -eq 100) { "Green" } elseif ($percentage -ge 80) { "Yellow" } else { "Red" }
        $statusIcon = if ($percentage -eq 100) { "✅" } elseif ($percentage -ge 80) { "⚠️" } else { "❌" }
        
        Write-Host "$statusIcon $category`: $granted/$total granted ($percentage%)" -ForegroundColor $statusColor
        
        if ($category -eq "All") {
            Write-Host "   📋 Overall EasyPIM readiness: $percentage%" -ForegroundColor $statusColor
        } elseif ($category -eq "Critical") {
            Write-Host "   🚨 Critical functionality: $percentage%" -ForegroundColor $statusColor
        }
    }
    
    # Readiness assessment
    $criticalPercentage = if ($results.Critical.Total -gt 0) { 
        [math]::Round(($results.Critical.Granted.Count / $results.Critical.Total) * 100, 1) 
    } else { 0 }
    
    Write-Host "`n🎯 EASYPIM READINESS ASSESSMENT:" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    
    if ($criticalPercentage -eq 100) {
        Write-Host "🎉 FULLY READY! All critical permissions are granted." -ForegroundColor Green
        Write-Host "   ✅ EasyPIM will function correctly in your Azure DevOps pipeline" -ForegroundColor Green
    } elseif ($criticalPercentage -ge 80) {
        Write-Host "⚠️ MOSTLY READY! Most critical permissions are granted." -ForegroundColor Yellow
        Write-Host "   🔧 EasyPIM may have limited functionality" -ForegroundColor Yellow
    } else {
        Write-Host "❌ NOT READY! Critical permissions are missing." -ForegroundColor Red
        Write-Host "   🚨 EasyPIM will likely fail in your Azure DevOps pipeline" -ForegroundColor Red
    }
    
    # Missing permission details
    if ($results.All.Missing.Count -gt 0) {
        Write-Host "`n❌ MISSING PERMISSIONS ($($results.All.Missing.Count)):" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Red
        
        foreach ($category in @("Core", "PIM", "Enhanced")) {
            $missingInCategory = $results[$category].Missing
            if ($missingInCategory.Count -gt 0) {
                Write-Host "`n📂 Missing $category Permissions:" -ForegroundColor Yellow
                foreach ($permission in $missingInCategory) {
                    $criticality = if ($permission.Critical) { "[CRITICAL]" } else { "[Optional]" }
                    $color = if ($permission.Critical) { "Red" } else { "Yellow" }
                    Write-Host "   - $($permission.Name) $criticality" -ForegroundColor $color
                    Write-Host "     $($permission.Description)" -ForegroundColor Gray
                }
            }
        }
    }
    
    # Action recommendations
    Write-Host "`n🚀 RECOMMENDED ACTIONS:" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($results.All.Missing.Count -gt 0) {
        Write-Host "1. 🔧 Grant missing permissions:" -ForegroundColor White
        Write-Host "   Run: .\grant-all-easypim-permissions.ps1" -ForegroundColor Yellow
        
        Write-Host "`n2. 🔑 If permissions fail to grant automatically:" -ForegroundColor White
        Write-Host "   - Go to Azure Portal > Azure Active Directory > App registrations" -ForegroundColor Gray
        Write-Host "   - Find your app: $ServicePrincipalAppId" -ForegroundColor Gray
        Write-Host "   - Go to 'API permissions' > 'Grant admin consent'" -ForegroundColor Gray
        
        Write-Host "`n3. ✅ Validate after granting:" -ForegroundColor White
        Write-Host "   Run: .\validate-all-permissions.ps1 -Detailed" -ForegroundColor Yellow
    } else {
        Write-Host "🎉 All permissions are correctly configured!" -ForegroundColor Green
        Write-Host "   Ready to test: .\trigger-build.ps1" -ForegroundColor Yellow
    }
    
    Write-Host "`n4. 🔄 Test your pipeline:" -ForegroundColor White
    Write-Host "   .\trigger-build.ps1" -ForegroundColor Yellow

} catch {
    Write-Host "`n❌ VALIDATION ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Make sure you have read access to service principals and applications" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✨ Permission validation completed! ✨" -ForegroundColor Green
