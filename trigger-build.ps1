# Manual Build Trigger - Stable Version
# Use this to trigger builds without shell crashes

param(
    [string]$PAT = $env:AZURE_DEVOPS_PAT
)

if (-not $PAT) {
    Write-Host "❌ PAT token required. Usage:" -ForegroundColor Red
    Write-Host "   .\trigger-build.ps1 -PAT 'your_pat_token'" -ForegroundColor Yellow
    Write-Host "   OR set: `$env:AZURE_DEVOPS_PAT = 'your_token'" -ForegroundColor Yellow
    exit 1
}

Write-Host "🚀 Manual Build Trigger with Authentication Fix" -ForegroundColor Green

$org = "kayasax"
$project = "EasyPIM-EventDriven-Governance"
$buildDefinitionId = 8

$headers = @{
    'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("`:$PAT")))"
    'Content-Type' = 'application/json'
}

# First check current status
Write-Host "🔍 Checking current builds..." -ForegroundColor Cyan
try {
    $builds = Invoke-RestMethod -Uri "https://dev.azure.com/$org/$project/_apis/build/builds?definitions=$buildDefinitionId&`$top=1&api-version=7.1" -Headers $headers -Method GET
    
    if ($builds.value -and $builds.value.Count -gt 0) {
        $latest = $builds.value[0]
        Write-Host "📊 Latest build: $($latest.id) - $($latest.status)/$($latest.result)" -ForegroundColor White
        
        if ($latest.status -eq "inProgress") {
            Write-Host "✅ Build $($latest.id) is already running!" -ForegroundColor Green
            Write-Host "🔗 Monitor: https://dev.azure.com/$org/$project/_build/results?buildId=$($latest.id)" -ForegroundColor Blue
            exit 0
        }
    }
} catch {
    Write-Host "⚠️ Could not check existing builds: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Trigger new build
Write-Host "🚀 Triggering new build with authentication fix..." -ForegroundColor Green

$body = @{
    definition = @{ id = $buildDefinitionId }
    parameters = @{
        serviceConnection = "EasyPIM-Azure-Connection"
        keyVaultName = "default"
        configSecretName = "default"
        WhatIf = $true
        Mode = "delta"
        run_description = "AUTH FIX: Connect-MgGraph explicit scopes - $(Get-Date -Format 'HH:mm:ss')"
    } | ConvertTo-Json
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "https://dev.azure.com/$org/$project/_apis/build/builds?api-version=7.1" -Method POST -Headers $headers -Body $body
    
    $buildId = $response.id
    Write-Host "✅ BUILD TRIGGERED!" -ForegroundColor Green
    Write-Host "📊 Build ID: $buildId" -ForegroundColor Cyan
    Write-Host "🔗 URL: https://dev.azure.com/$org/$project/_build/results?buildId=$buildId" -ForegroundColor Blue
    
    Write-Host "`n🔧 Authentication fix applied:" -ForegroundColor Yellow
    Write-Host "   Connect-MgGraph -Identity -Scopes @('RoleManagement.ReadWrite.Directory')" -ForegroundColor White
    
    Write-Host "`n📋 To check status later:" -ForegroundColor Cyan
    Write-Host "   .\check-build.ps1" -ForegroundColor White
    
} catch {
    Write-Host "❌ Failed to trigger: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode) {
        Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}
