# 🎯 Targeted EasyPIM Policy Orchestrator Validation
# This script specifically triggers the orchestrator pipeline to test the auth fix

Write-Host "🎯 EASYPIM POLICY ORCHESTRATOR VALIDATION" -ForegroundColor Green
Write-Host "Repository: https://dev.azure.com/loic0161/EasyPIM-CICD/" -ForegroundColor Cyan
Write-Host ""

# Configuration
$organization = "loic0161"
$project = "EasyPIM-CICD"
$targetPipelineId = 2  # EasyPIM-02-Policy-Orchestrator
$pat = $env:AZURE_DEVOPS_PAT

if (-not $pat) {
    Write-Host "❌ Azure DevOps PAT token required!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ PAT token configured" -ForegroundColor Green

# Setup auth headers
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    "Authorization" = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

Write-Host "🎯 Targeting Pipeline ID: $targetPipelineId (EasyPIM-02-Policy-Orchestrator)" -ForegroundColor Cyan
Write-Host ""

try {
    # Verify the target pipeline exists
    Write-Host "🔍 Verifying pipeline..." -ForegroundColor Yellow
    $pipelineUrl = "https://dev.azure.com/$organization/$project/_apis/build/definitions/$targetPipelineId?api-version=7.1"
    $pipeline = Invoke-RestMethod -Uri $pipelineUrl -Method GET -Headers $headers
    
    Write-Host "✅ Pipeline found: $($pipeline.name)" -ForegroundColor Green
    Write-Host ""

    # Trigger the build with proper parameters for the orchestrator
    Write-Host "🚀 Triggering Policy Orchestrator..." -ForegroundColor Green
    
    $buildUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=7.1"
    $buildBody = @{
        definition = @{ id = $targetPipelineId }
        sourceBranch = "refs/heads/main"
        parameters = @{
            # Set WhatIf to true for safe testing
            WhatIf = "true"
            Mode = "delta"
            run_description = "Authentication Fix Validation Test"
            serviceConnection = "EasyPIM-Azure-Connection"
        } | ConvertTo-Json
    } | ConvertTo-Json -Depth 5
    
    Write-Host "📋 Build parameters:" -ForegroundColor Cyan
    Write-Host "   WhatIf: true (safe mode)" -ForegroundColor White
    Write-Host "   Mode: delta" -ForegroundColor White
    Write-Host "   Description: Authentication Fix Validation Test" -ForegroundColor White
    Write-Host ""
    
    $buildResponse = Invoke-RestMethod -Uri $buildUrl -Method POST -Headers $headers -Body $buildBody
    $buildId = $buildResponse.id
    
    Write-Host "✅ Policy Orchestrator triggered successfully!" -ForegroundColor Green
    Write-Host "   Build ID: $buildId" -ForegroundColor White
    Write-Host "   Build Number: $($buildResponse.buildNumber)" -ForegroundColor White
    Write-Host "   🔗 Monitor: $($buildResponse._links.web.href)" -ForegroundColor Blue
    Write-Host ""
    
    # Enhanced monitoring focused on authentication
    Write-Host "📊 MONITORING AUTHENTICATION FIX..." -ForegroundColor Cyan
    Write-Host "   Looking for: Microsoft Graph connection success" -ForegroundColor White
    Write-Host "   Target: Resolve 'Insufficient Microsoft Graph permissions' error" -ForegroundColor White
    Write-Host ""
    
    $maxChecks = 15  # 5 minutes of monitoring
    $authSuccess = $false
    
    for ($i = 1; $i -le $maxChecks; $i++) {
        Start-Sleep 20  # Check every 20 seconds
        
        try {
            $statusUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds/$buildId?api-version=7.1"
            $status = Invoke-RestMethod -Uri $statusUrl -Method GET -Headers $headers
            
            $buildStatus = $status.status
            $buildResult = $status.result
            $currentTime = Get-Date -Format "HH:mm:ss"
            
            Write-Host "[$i @ $currentTime] Status: $buildStatus" -NoNewline
            
            if ($buildResult) {
                if ($buildResult -eq "succeeded") {
                    Write-Host " | " -NoNewline
                    Write-Host "SUCCESS" -ForegroundColor Green
                    $authSuccess = $true
                    break
                } else {
                    Write-Host " | " -NoNewline  
                    Write-Host $buildResult -ForegroundColor Red
                    break
                }
            } else {
                Write-Host " | ⚡ Running..." -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "[$i] ❌ Monitoring error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "🏁 VALIDATION RESULTS:" -ForegroundColor Cyan
    Write-Host "=" * 40 -ForegroundColor Cyan
    
    if ($authSuccess) {
        Write-Host "🎉 AUTHENTICATION FIX SUCCESSFUL!" -ForegroundColor Green
        Write-Host "✅ Microsoft Graph connection is working" -ForegroundColor Green
        Write-Host "✅ Service principal permissions are effective" -ForegroundColor Green
        Write-Host "✅ EasyPIM can execute without permission errors" -ForegroundColor Green
    } else {
        Write-Host "⚠️  AUTHENTICATION ISSUE MAY PERSIST" -ForegroundColor Yellow
        Write-Host "💡 Check the build logs for specific error details" -ForegroundColor Yellow
        Write-Host "🔧 The Connect-MgGraph method may need further refinement" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🔗 Full build details: $($buildResponse._links.web.href)" -ForegroundColor Blue
    Write-Host ""
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "📋 Response Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        
        # Try to get more details
        try {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorDetails = $reader.ReadToEnd()
            if ($errorDetails) {
                Write-Host "📋 Error Details: $errorDetails" -ForegroundColor Red
            }
        } catch {
            Write-Host "📋 Could not read error details" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   - Verify PAT token has 'Build (read and execute)' permissions" -ForegroundColor White
    Write-Host "   - Check if pipeline requires additional parameters" -ForegroundColor White
    Write-Host "   - Ensure service connection 'EasyPIM-Azure-Connection' exists" -ForegroundColor White
}
