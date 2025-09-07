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

# Determine execution status - check for failures in orchestrator results first
$actualStatus = $JobStatus
$statusIcon = if ($JobStatus -eq 'success') { '✅' } else { '❌' }
$statusColor = if ($JobStatus -eq 'success') { '🟢' } else { '🔴' }
$statusText = if ($JobStatus -eq 'success') { 'SUCCESS' } else { 'FAILED' }

# Determine execution mode badge
$whatIfBool = $WhatIfMode -eq 'true'
$modeBadge = if ($whatIfBool) { '🔍 **PREVIEW MODE**' } else { '⚡ **LIVE EXECUTION**' }

# Configuration source detection
$configSource = if ($ConfigSecretName) {
    '🚀 **Event-Driven** (Auto-triggered)'
} else {
    '👤 **Manual Trigger**'
}

# Try to capture EasyPIM results from the orchestrator summary
$easypimResults = ""
$orchestratorSummary = ""

# Try multiple possible paths for the orchestrator summary
$summaryPaths = @(
    "./workflow-artifacts/orchestrator-summary.json",
    "./orchestrator-summary.json",
    "orchestrator-summary.json"
)

$summaryFile = $null
foreach ($path in $summaryPaths) {
    if (Test-Path $path) {
        $summaryFile = $path
        Write-Host "Found orchestrator summary at: $path" -ForegroundColor Green
        break
    }
}

if ($summaryFile) {
    try {
        $results = Get-Content $summaryFile | ConvertFrom-Json

        # Extract metrics with defaults
        $assignmentsCreated = $results.AssignmentsCreated ?? 0
        $assignmentsPlanned = $results.AssignmentsPlanned ?? 0
        $policiesApplied = $results.PoliciesApplied ?? 0
        $policiesSkipped = $results.PoliciesSkipped ?? 0
        $assignmentsAnalyzed = $results.AssignmentsAnalyzed ?? 0
        $assignmentsRemoved = $results.AssignmentsRemoved ?? 0
        $assignmentsFailed = $results.AssignmentsFailed ?? 0
        $policiesFailed = $results.PoliciesFailed ?? 0

        # Check for failures and update status if needed
        $hasFailures = ($assignmentsFailed -gt 0) -or ($policiesFailed -gt 0)
        
        # If we don't have failure counts from the summary object, try to extract from formatted summary
        if (-not $hasFailures -and $results.FormattedSummary) {
            if ($results.FormattedSummary -match '\[FAIL\] Failed\s*:\s*(\d+)') {
                $totalFailures = [int]$Matches[1]
                if ($totalFailures -gt 0) {
                    $hasFailures = $true
                }
            }
        }
        
        if ($hasFailures -and $JobStatus -eq 'success') {
            $actualStatus = 'completed-with-errors'
            $statusIcon = '⚠️'
            $statusColor = '🟡'
            $statusText = 'COMPLETED WITH ERRORS'
        }

        # Build results with formatted summary only (execution logs remain in step output)
        if ($results.FormattedSummary) {
            $easypimResults = @"

### 📊 **EasyPIM Orchestrator Results**

``````
$($results.FormattedSummary)
``````
"@
        } else {
            # Create a summary table from extracted metrics
            $easypimResults = @"

### 📊 **EasyPIM Orchestrator Results**

#### 📋 **Assignment Operations**
- ✅ **Created:** $assignmentsCreated
- 📝 **Planned:** $assignmentsPlanned
- 🔍 **Analyzed:** $assignmentsAnalyzed
- 🗑️ **Removed:** $assignmentsRemoved

#### 🔐 **Policy Operations**
- ✅ **Applied:** $policiesApplied
- ⏭️ **Skipped:** $policiesSkipped

#### ⏱️ **Execution Details**
- **Mode:** $($results.ExecutionMode)
- **WhatIf:** $($results.WhatIfMode)
- **Status:** $($results.Status)
- **Timestamp:** $($results.Timestamp)
"@
        }

    } catch {
        $easypimResults = @"

### 📊 **EasyPIM Results**
*Error parsing orchestrator summary: $($_.Exception.Message)*
*Check execution logs above for detailed operation results*
"@
    }
} else {
    # Check for error files
    $errorPaths = @(
        "./workflow-artifacts/orchestrator-error.json",
        "./orchestrator-error.json",
        "orchestrator-error.json"
    )

    $errorFile = $null
    foreach ($path in $errorPaths) {
        if (Test-Path $path) {
            $errorFile = $path
            Write-Host "Found orchestrator error at: $path" -ForegroundColor Red
            break
        }
    }

    if ($errorFile) {
        try {
            $errorInfo = Get-Content $errorFile | ConvertFrom-Json
            $easypimResults = @"

### ❌ **EasyPIM Execution Error**

**Error:** $($errorInfo.Error)

**Mode:** $($errorInfo.ExecutionMode)

**Timestamp:** $($errorInfo.Timestamp)

*Check execution logs above for detailed error information*
"@
        } catch {
            $easypimResults = "`n### ❌ **EasyPIM Execution Error**`n*Check execution logs above for detailed error information*"
        }
    } else {
        $easypimResults = "`n### 📊 **EasyPIM Results**`n*Check execution logs above for detailed operation results*"
    }
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
| $statusColor **$statusText** | $modeBadge | $configSource | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC') |

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
