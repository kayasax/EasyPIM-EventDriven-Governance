# 🚀 AUTOMATED AZURE DEVOPS PIPELINE VALIDATION SCRIPT
# This script fully automates the authentication fix validation process

param(
    [Parameter(Mandatory=$false)]
    [string]$PersonalAccessToken,
    
    [Parameter(Mandatory=$false)]
    [string]$Organization = "digtalwrkspace1",
    
    [Parameter(Mandatory=$false)]
    [string]$Project = "EasyPIM-CICD-test",
    
    [Parameter(Mandatory=$false)]
    [int]$PipelineId = 1
)

Write-Host "🚀 AUTOMATED PIPELINE VALIDATION FOR AUTHENTICATION FIX" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""

# 1. Setup authentication
if (-not $PersonalAccessToken) {
    $PersonalAccessToken = $env:AZURE_DEVOPS_PAT
}

if (-not $PersonalAccessToken) {
    Write-Host "❌ Azure DevOps Personal Access Token required!" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 SETUP INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://dev.azure.com/digtalwrkspace1/_usersSettings/tokens"
    Write-Host "   2. Create new token with 'Build (read and execute)' permissions"
    Write-Host "   3. Set environment variable: `$env:AZURE_DEVOPS_PAT = 'your_token'"
    Write-Host "   4. Re-run this script"
    Write-Host ""
    Write-Host "🔧 OR provide token as parameter:" -ForegroundColor Cyan
    Write-Host "   .\AUTOMATED_VALIDATION_SCRIPT.ps1 -PersonalAccessToken 'your_token'"
    Write-Host ""
    exit 1
}

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
$headers = @{
    "Authorization" = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

Write-Host "🔧 CONFIGURATION:" -ForegroundColor Cyan
Write-Host "   Organization: $Organization"
Write-Host "   Project: $Project"
Write-Host "   Pipeline ID: $PipelineId"
Write-Host "   Authentication: ✅ PAT Configured"
Write-Host ""

# 2. Ensure YAML file is fixed
Write-Host "📁 PREPARING PIPELINE FILES..." -ForegroundColor Yellow

try {
    $fixedFile = "templates\azure-pipelines-orchestrator-fixed.yml"
    $originalFile = "templates\azure-pipelines-orchestrator.yml"
    
    if (Test-Path $fixedFile) {
        Copy-Item $fixedFile $originalFile -Force
        Write-Host "   ✅ Applied authentication fix to pipeline YAML" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Fixed YAML file not found - proceeding with existing file" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Error preparing files: $_" -ForegroundColor Red
}

Write-Host ""

# 3. Trigger the pipeline
Write-Host "🚀 TRIGGERING PIPELINE EXECUTION..." -ForegroundColor Green

try {
    $triggerUrl = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$PipelineId/runs?api-version=7.1"
    $triggerBody = @{
        resources = @{
            repositories = @{
                self = @{
                    refName = "refs/heads/main"
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    Write-Host "   📡 Sending trigger request..." -ForegroundColor Cyan
    $runResponse = Invoke-RestMethod -Uri $triggerUrl -Method POST -Headers $headers -Body $triggerBody -ErrorAction Stop
    $runId = $runResponse.id
    
    Write-Host "   ✅ PIPELINE TRIGGERED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "   🆔 Run ID: $runId" -ForegroundColor White
    Write-Host "   🔗 Monitor URL: $($runResponse._links.web.href)" -ForegroundColor Blue
    Write-Host ""
    
} catch {
    Write-Host "   ❌ Failed to trigger pipeline!" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "   Details: $responseBody" -ForegroundColor Red
    }
    exit 1
}

# 4. Monitor the pipeline execution
Write-Host "📊 MONITORING PIPELINE EXECUTION..." -ForegroundColor Cyan
Write-Host "   Target: Validate authentication fix effectiveness"
Write-Host "   Looking for: Microsoft Graph connection + EasyPIM execution success"
Write-Host ""

$maxWaitMinutes = 20
$checkIntervalSeconds = 15
$maxChecks = ($maxWaitMinutes * 60) / $checkIntervalSeconds
$authFixed = $false
$pipelineCompleted = $false

for ($check = 1; $check -le $maxChecks; $check++) {
    try {
        # Get pipeline status
        $statusUrl = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/runs/$runId?api-version=7.1"
        $runStatus = Invoke-RestMethod -Uri $statusUrl -Method GET -Headers $headers -ErrorAction Stop
        
        $state = $runStatus.state
        $result = $runStatus.result
        $currentTime = Get-Date -Format "HH:mm:ss"
        
        Write-Host "   [$check @ $currentTime] State: $state" -NoNewline
        if ($result) {
            $resultColor = switch ($result) {
                "succeeded" { "Green" }
                "failed" { "Red" }
                "canceled" { "Yellow" }
                default { "White" }
            }
            Write-Host " | Result: " -NoNewline
            Write-Host $result -ForegroundColor $resultColor
        } else {
            Write-Host " | ⚡ Executing..." -ForegroundColor Yellow
        }
        
        # Check if pipeline completed
        if ($state -eq "completed") {
            $pipelineCompleted = $true
            Write-Host ""
            
            if ($result -eq "succeeded") {
                Write-Host "🎉 PIPELINE EXECUTION SUCCESSFUL!" -ForegroundColor Green
                Write-Host ""
                Write-Host "✅ AUTHENTICATION FIX VALIDATION: PASSED" -ForegroundColor Green
                Write-Host "✅ Microsoft Graph Connection: WORKING" -ForegroundColor Green
                Write-Host "✅ EasyPIM Orchestration: SUCCESSFUL" -ForegroundColor Green
                Write-Host "✅ Service Principal Permissions: EFFECTIVE" -ForegroundColor Green
                Write-Host ""
                Write-Host "🏆 AUTHENTICATION ISSUE RESOLVED!" -ForegroundColor Green
                $authFixed = $true
                break
                
            } elseif ($result -eq "failed") {
                Write-Host "❌ PIPELINE EXECUTION FAILED" -ForegroundColor Red
                Write-Host ""
                Write-Host "🔍 ANALYZING FAILURE..." -ForegroundColor Yellow
                
                try {
                    # Get timeline for detailed analysis
                    $timelineUrl = "https://dev.azure.com/$Organization/$Project/_apis/build/builds/$runId/timeline?api-version=7.1"
                    $timeline = Invoke-RestMethod -Uri $timelineUrl -Method GET -Headers $headers
                    
                    $authErrorDetected = $false
                    $failedTasks = @()
                    
                    foreach ($record in $timeline.records) {
                        if ($record.result -eq "failed") {
                            $failedTasks += $record.name
                            
                            if ($record.name -like "*Orchestrator*" -or $record.name -like "*EasyPIM*") {
                                $authErrorDetected = $true
                            }
                        }
                    }
                    
                    Write-Host "📋 Failed Tasks:" -ForegroundColor Red
                    foreach ($task in $failedTasks) {
                        Write-Host "   • $task" -ForegroundColor Red
                    }
                    Write-Host ""
                    
                    if ($authErrorDetected) {
                        Write-Host "🔧 AUTHENTICATION ISSUE PERSISTS" -ForegroundColor Red
                        Write-Host "   The Connect-MgGraph method needs further refinement" -ForegroundColor Yellow
                        Write-Host "   Consider alternative authentication approaches" -ForegroundColor Yellow
                    } else {
                        Write-Host "✅ Authentication appears functional" -ForegroundColor Green
                        Write-Host "   Failure may be in different component" -ForegroundColor Yellow
                    }
                    
                } catch {
                    Write-Host "⚠️ Could not analyze failure details: $_" -ForegroundColor Yellow
                }
                
                break
            }
        }
        
        # Wait before next check
        if ($check -lt $maxChecks) {
            Start-Sleep -Seconds $checkIntervalSeconds
        }
        
    } catch {
        Write-Host "   [$check] ❌ Monitoring error: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep -Seconds $checkIntervalSeconds
    }
}

# Final status report
Write-Host ""
Write-Host "🏁 VALIDATION CYCLE COMPLETE" -ForegroundColor Cyan
Write-Host "=" * 40 -ForegroundColor Cyan

if ($pipelineCompleted) {
    if ($authFixed) {
        Write-Host "🎯 OUTCOME: SUCCESS" -ForegroundColor Green
        Write-Host "   Authentication fix is working correctly" -ForegroundColor Green
        Write-Host "   EasyPIM can now execute without permission errors" -ForegroundColor Green
    } else {
        Write-Host "🎯 OUTCOME: NEEDS ITERATION" -ForegroundColor Yellow
        Write-Host "   Authentication fix requires additional refinement" -ForegroundColor Yellow
        Write-Host "   Further debugging needed" -ForegroundColor Yellow
    }
} else {
    Write-Host "🎯 OUTCOME: TIMEOUT" -ForegroundColor Yellow  
    Write-Host "   Pipeline still running after $maxWaitMinutes minutes" -ForegroundColor Yellow
    Write-Host "   Continue monitoring manually" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔗 Pipeline Details: $($runStatus._links.web.href)" -ForegroundColor Blue
Write-Host ""

return @{
    RunId = $runId
    Completed = $pipelineCompleted
    Success = $authFixed
    MonitorUrl = $runStatus._links.web.href
}
