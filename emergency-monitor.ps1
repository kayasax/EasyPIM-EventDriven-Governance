# Emergency Build Monitoring Script
# Use this if terminals keep crashing during monitoring

param(
    [int]$BuildId = $null,
    [int]$MaxMinutes = 15
)

Write-Host "🚀 Emergency Build Monitor - Crash-Resistant Version" -ForegroundColor Green

# Azure DevOps settings
$org = "kayasax"
$project = "EasyPIM-EventDriven-Governance"
$buildDefinitionId = 8
$pat = $env:AZURE_DEVOPS_PAT

if (-not $pat) {
    Write-Host "❌ Set PAT: `$env:AZURE_DEVOPS_PAT = 'your_token'" -ForegroundColor Red
    exit 1
}

$headers = @{
    'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("`:$pat")))"
    'Content-Type' = 'application/json'
}

# Get build to monitor
if (-not $BuildId) {
    Write-Host "🔍 Finding latest build..." -ForegroundColor Cyan
    $builds = Invoke-RestMethod -Uri "https://dev.azure.com/$org/$project/_apis/build/builds?definitions=$buildDefinitionId&`$top=1&api-version=7.1" -Headers $headers -Method GET
    
    if ($builds.value -and $builds.value.Count -gt 0) {
        $BuildId = $builds.value[0].id
        Write-Host "📊 Monitoring Build ID: $BuildId" -ForegroundColor Green
    } else {
        Write-Host "❌ No builds found to monitor" -ForegroundColor Red
        exit 1
    }
}

# Monitor loop with crash protection
$startTime = Get-Date
$iteration = 0

Write-Host "⏱️ Starting monitoring (max $MaxMinutes minutes)..." -ForegroundColor Yellow

do {
    $iteration++
    Start-Sleep -Seconds 15
    $elapsed = ((Get-Date) - $startTime).TotalMinutes
    
    try {
        $build = Invoke-RestMethod -Uri "https://dev.azure.com/$org/$project/_apis/build/builds/$BuildId?api-version=7.1" -Headers $headers -Method GET
        
        Write-Host "[$iteration] $($elapsed.ToString('F1'))m | Build $BuildId: $($build.status) / $($build.result)" -ForegroundColor Cyan
        
        if ($build.status -eq "completed") {
            Write-Host "`n🎯 BUILD COMPLETED!" -ForegroundColor Green
            
            if ($build.result -eq "succeeded") {
                Write-Host "🎉 SUCCESS! Authentication fix worked!" -ForegroundColor Green
                Write-Host "✅ EasyPIM can now authenticate to Microsoft Graph!" -ForegroundColor Green
                Write-Host "✅ Connect-MgGraph with explicit scopes resolved the issue!" -ForegroundColor Green
            } else {
                Write-Host "❌ Build failed: $($build.result)" -ForegroundColor Red
                Write-Host "🔍 Authentication may still need adjustment" -ForegroundColor Yellow
            }
            
            Write-Host "🔗 Build URL: https://dev.azure.com/$org/$project/_build/results?buildId=$BuildId" -ForegroundColor Blue
            break
        }
        
    } catch {
        Write-Host "⚠️ API Error (attempt $iteration): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
} while ($elapsed -lt $MaxMinutes)

if ($elapsed -ge $MaxMinutes) {
    Write-Host "`n⏰ Timeout after $MaxMinutes minutes" -ForegroundColor Yellow
}

Write-Host "`n📋 To run manually: .\emergency-monitor.ps1 -BuildId $BuildId" -ForegroundColor Cyan
