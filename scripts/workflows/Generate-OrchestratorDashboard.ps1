# Generate Modern Dashboard Summary for EasyPIM Orchestrator
# This script creates a comprehensive dashboard summary for GitHub Actions

param(
    [Parameter(Mandatory = $true)]
    [string]$JobStatus,

    [Parameter(Mandatory = $true)]
    [string]$WhatIfMode,

    [Parameter(Mandatory = $false)]
    [string]$ConfigSecretName = "",

    [Parameter(Mandatory = $false)]
    [string]$RunDescription = "",

    [Parameter(Mandatory = $true)]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$SecretName,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$SkipPolicies,

    [Parameter(Mandatory = $true)]
    [string]$SkipAssignments,

    [Parameter(Mandatory = $true)]
    [string]$AllowProtectedRoles,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRunId,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRunNumber
)

Write-Host "📊 Generating modern dashboard summary..." -ForegroundColor Cyan

# Determine execution status
$statusIcon = if ($JobStatus -eq 'success') { '✅' } else { '❌' }
$statusColor = if ($JobStatus -eq 'success') { '🟢' } else { '🔴' }

# Determine execution mode badge
$whatIfBool = $WhatIfMode -eq 'true'
$modeBadge = if ($whatIfBool) { '🔍 **PREVIEW MODE**' } else { '⚡ **LIVE EXECUTION**' }

# Configuration source detection
$configSource = if ($ConfigSecretName) {
    '🚀 **Event-Driven** (Auto-triggered)'
} else {
    '👤 **Manual Trigger**'
}

# Try to capture EasyPIM results if available
$easypimResults = ""
if (Test-Path "./easypim-summary.json") {
    try {
        $results = Get-Content "./easypim-summary.json" | ConvertFrom-Json
        $easypimResults = @"

### 📈 **EasyPIM Execution Results**

| Component | Processed | Created | Updated | Removed | Errors |
|-----------|-----------|---------|---------|---------|---------|
| 🔐 **Policies** | $($results.Policies.Processed ?? 'N/A') | $($results.Policies.Created ?? 'N/A') | $($results.Policies.Updated ?? 'N/A') | $($results.Policies.Removed ?? 'N/A') | $($results.Policies.Errors ?? 'N/A') |
| 👥 **Assignments** | $($results.Assignments.Processed ?? 'N/A') | $($results.Assignments.Created ?? 'N/A') | $($results.Assignments.Updated ?? 'N/A') | $($results.Assignments.Removed ?? 'N/A') | $($results.Assignments.Errors ?? 'N/A') |
| 🏷️ **Groups** | $($results.Groups.Processed ?? 'N/A') | $($results.Groups.Created ?? 'N/A') | $($results.Groups.Updated ?? 'N/A') | $($results.Groups.Removed ?? 'N/A') | $($results.Groups.Errors ?? 'N/A') |

**⏱️ Total Execution Time:** $($results.ExecutionTime) | **🔄 Objects Processed:** $($results.TotalProcessed ?? 'N/A')
"@
    } catch {
        $easypimResults = "`n### 📊 **EasyPIM Results**`n*Detailed results will be available when EasyPIM generates summary output*"
    }
} elseif (Test-Path "./easypim-error.json") {
    try {
        $errorInfo = Get-Content "./easypim-error.json" | ConvertFrom-Json
        $easypimResults = @"

### ❌ **EasyPIM Execution Error**

**Error:** $($errorInfo.Error)

**Timestamp:** $($errorInfo.Timestamp)

*Check execution logs above for detailed error information*
"@
    } catch {
        $easypimResults = "`n### ❌ **EasyPIM Execution Error**`n*Check execution logs above for detailed error information*"
    }
} else {
    $easypimResults = "`n### 📊 **EasyPIM Results**`n*Check execution logs above for detailed operation results*"
}

# Check for module versions
$moduleVersions = ""
if (Test-Path "./easypim-module-versions.json") {
    try {
        $versions = Get-Content "./easypim-module-versions.json" | ConvertFrom-Json
        $moduleVersions = @"

### 📦 **Module Versions**
- **EasyPIM:** ``v$($versions.EasyPIM.Version)``
- **EasyPIM.Orchestrator:** ``v$($versions.EasyPIMOrchestrator.Version)``
- **PowerShell:** ``v$($versions.PowerShellVersion)``
"@
    } catch {
        $moduleVersions = ""
    }
}

$summary = @"
# $statusIcon **EasyPIM Event-Driven Governance Dashboard**

## 🎯 **Execution Overview**

| 🚦 **Status** | 🎮 **Mode** | 📡 **Trigger** | ⏰ **Timestamp** |
|---------------|-------------|-----------------|------------------|
| $statusColor **$($JobStatus.ToUpper())** | $modeBadge | $configSource | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC') |

$easypimResults

## ⚙️ **Configuration Matrix**

<table>
<tr>
<td>

**🎛️ Execution Parameters**
- $modeBadge
- **Mode:** ``$Mode``
- **Skip Policies:** ``$SkipPolicies``
- **Skip Assignments:** ``$SkipAssignments``
- **Protected Roles:** ``$AllowProtectedRoles``

</td>
<td>

**🔧 Environment Context**
- **Vault:** ``$KeyVaultName``
- **Config:** ``$SecretName``
- **Tenant:** ``$TenantId``
- **Subscription:** ``$SubscriptionId``

</td>
</tr>
</table>

$moduleVersions

## 🔍 **Event-Driven Intelligence**

$($ConfigSecretName ? '> **🎯 Smart Detection:** Configuration automatically selected based on event trigger' : '> **📋 Manual Configuration:** Using repository default configuration settings')

$($RunDescription ? "> **📝 Event Context:** $RunDescription" : '')

## 🚀 **Quick Actions**

| Action | Description | Link |
|--------|-------------|------|
| 🔍 **View Logs** | Detailed execution logs | [📋 Workflow Run](https://github.com/$GitHubRepository/actions/runs/$GitHubRunId) |
| 🔄 **Re-run** | Execute workflow again | [⚡ Actions](https://github.com/$GitHubRepository/actions/workflows/02-orchestrator-test.yml) |
| 🎯 **Drift Check** | Verify compliance | [🎯 Phase 3](https://github.com/$GitHubRepository/actions/workflows/03-policy-drift-check.yml) |
| 📖 **Documentation** | Setup guide | [📚 Docs](https://github.com/$GitHubRepository/blob/main/docs/Step-by-Step-Guide.md) |

---

<details>
<summary>🔧 <strong>Technical Details</strong></summary>

- **Run ID:** ``$GitHubRunId``
- **Run Number:** ``#$GitHubRunNumber``
- **Repository:** ``$GitHubRepository``
- **Workflow:** ``Phase 2 - EasyPIM Orchestrator``
- **Version:** ``v1.1 (Event-Driven Multi-Environment)``

</details>

> 💡 **Next Steps:** $($WhatIfMode -eq 'true' ? 'This was a preview run. Re-run with WhatIf=false to apply changes.' : 'Changes have been applied. Consider running drift detection to verify compliance.')
"@

# Output to step summary
$summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8
Write-Host "✅ Modern dashboard summary generated" -ForegroundColor Green

return $true
