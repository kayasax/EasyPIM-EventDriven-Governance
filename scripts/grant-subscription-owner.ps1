#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Grant subscription Owner role to the EasyPIM CI/CD service principal

.DESCRIPTION
    This script grants the Owner role at subscription level to the service principal
    created for EasyPIM CI/CD operations. This is required for Azure role policy management.

.PARAMETER SubscriptionId
    The Azure subscription ID where EasyPIM will operate

.PARAMETER ServicePrincipalClientId
    The client ID of the service principal to grant permissions to

.EXAMPLE
    ./grant-subscription-owner.ps1 -SubscriptionId "your-subscription-id" -ServicePrincipalClientId "your-client-id"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ServicePrincipalClientId
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $colors = @{
        "Info"    = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
    }

    Write-Host $Message -ForegroundColor $colors[$Type]
}

# Main execution
try {
    Write-ColorOutput "🔐 Granting subscription Owner role for EasyPIM CI/CD..." -Type "Info"
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type "Info"

    # Check if we're logged in to Azure
    $context = Get-AzContext
    if (-not $context) {
        Write-ColorOutput "❌ Not logged in to Azure. Please run 'Connect-AzAccount' first." -Type "Error"
        exit 1
    }

    Write-ColorOutput "📋 Configuration:" -Type "Info"
    Write-Host "   Subscription: $SubscriptionId" -ForegroundColor White
    Write-Host "   Service Principal: $ServicePrincipalClientId" -ForegroundColor White
    Write-Host "   Current User: $($context.Account.Id)" -ForegroundColor White

    # Set the subscription context
    Write-ColorOutput "`n🎯 Setting subscription context..." -Type "Info"
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

    # Check if we have permissions to assign roles
    Write-ColorOutput "🔍 Checking current permissions..." -Type "Info"

    # Get the service principal object
    $servicePrincipal = Get-AzADServicePrincipal -ApplicationId $ServicePrincipalClientId
    if (-not $servicePrincipal) {
        Write-ColorOutput "❌ Service principal not found: $ServicePrincipalClientId" -Type "Error"
        exit 1
    }

    Write-Host "   Found service principal: $($servicePrincipal.DisplayName)" -ForegroundColor Green

    # Check existing role assignments
    Write-ColorOutput "`n📋 Checking existing role assignments..." -Type "Info"
    $existingAssignments = Get-AzRoleAssignment -ObjectId $servicePrincipal.Id -Scope "/subscriptions/$SubscriptionId"

    if ($existingAssignments) {
        Write-ColorOutput "   Current role assignments:" -Type "Info"
        foreach ($assignment in $existingAssignments) {
            Write-Host "   • $($assignment.RoleDefinitionName) at $($assignment.Scope)" -ForegroundColor Yellow
        }
    } else {
        Write-ColorOutput "   No existing role assignments found." -Type "Warning"
    }

    # Check if Owner role is already assigned
    $ownerAssignment = $existingAssignments | Where-Object {
        $_.RoleDefinitionName -eq "Owner" -and $_.Scope -eq "/subscriptions/$SubscriptionId"
    }

    if ($ownerAssignment) {
        Write-ColorOutput "`n✅ Owner role is already assigned to the service principal!" -Type "Success"
        Write-ColorOutput "   No action needed." -Type "Info"
    } else {
        # Assign Owner role
        Write-ColorOutput "`n🔑 Assigning Owner role at subscription level..." -Type "Info"

        $roleAssignment = New-AzRoleAssignment `
            -ObjectId $servicePrincipal.Id `
            -RoleDefinitionName "Owner" `
            -Scope "/subscriptions/$SubscriptionId" `
            -ErrorAction Stop

        Write-ColorOutput "✅ Successfully assigned Owner role!" -Type "Success"
        Write-Host "   Role: $($roleAssignment.RoleDefinitionName)" -ForegroundColor Green
        Write-Host "   Scope: $($roleAssignment.Scope)" -ForegroundColor Green
        Write-Host "   Principal: $($roleAssignment.DisplayName)" -ForegroundColor Green
    }

    Write-ColorOutput "`n🚀 EasyPIM CI/CD is now ready for Azure role policy management!" -Type "Success"
    Write-ColorOutput "`n📝 Next Steps:" -Type "Info"
    Write-Host "   1. Run your EasyPIM CI/CD workflow" -ForegroundColor Cyan
    Write-Host "   2. Azure role policies should now apply successfully" -ForegroundColor Cyan
    Write-Host "   3. Monitor the workflow logs for successful ARM API calls" -ForegroundColor Cyan

    Write-ColorOutput "`n⚠️ Security Note:" -Type "Warning"
    Write-Host "   The Owner role provides full access to the subscription." -ForegroundColor Yellow
    Write-Host "   Consider using a more restrictive custom role for production environments." -ForegroundColor Yellow
    Write-Host "   Review and monitor all role assignments regularly." -ForegroundColor Yellow

} catch {
    Write-ColorOutput "`n❌ Error occurred: $($_.Exception.Message)" -Type "Error"
    Write-ColorOutput "📝 Troubleshooting:" -Type "Info"
    Write-Host "   • Ensure you have Owner or User Access Administrator role" -ForegroundColor Yellow
    Write-Host "   • Verify the subscription ID and service principal client ID" -ForegroundColor Yellow
    Write-Host "   • Check that you're connected to the correct Azure tenant" -ForegroundColor Yellow
    exit 1
}
