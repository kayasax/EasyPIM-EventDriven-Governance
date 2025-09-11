# Simple Build Status Checker
# Run this manually to check build status without crashing shells

param(
    [string]$PAT = $env:AZURE_DEVOPS_PAT
)

Write-Host "🔍 Build Status Checker" -ForegroundColor Green

if (-not $PAT) {
    Write-Host "❌ PAT token required. Usage:" -ForegroundColor Red
    Write-Host "   .\check-build.ps1 -PAT 'your_pat_token'" -ForegroundColor Yellow
    Write-Host "   OR set: `$env:AZURE_DEVOPS_PAT = 'your_token'" -ForegroundColor Yellow
    exit 1
}

$org = "kayasax"
$project = "EasyPIM-EventDriven-Governance"

$headers = @{
    'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("`:$PAT")))"
    'Content-Type' = 'application/json'
}

try {
    $builds = Invoke-RestMethod -Uri "https://dev.azure.com/$org/$project/_apis/build/builds?definitions=8&`$top=1&api-version=7.1" -Headers $headers -Method GET
    
    if ($builds.value -and $builds.value.Count -gt 0) {
        $build = $builds.value[0]
        
        Write-Host "`n📊 Latest EasyPIM Build:" -ForegroundColor Cyan
        Write-Host "   Build ID: $($build.id)" -ForegroundColor White
        Write-Host "   Status: $($build.status)" -ForegroundColor White
        Write-Host "   Result: $($build.result)" -ForegroundColor White
        
        $timeAgo = (Get-Date) - [DateTime]$build.queueTime
        Write-Host "   Time: $($timeAgo.TotalMinutes.ToString('F0')) minutes ago" -ForegroundColor White
        Write-Host "   URL: https://dev.azure.com/$org/$project/_build/results?buildId=$($build.id)" -ForegroundColor Blue
        
        if ($build.status -eq "completed") {
            if ($build.result -eq "succeeded") {
                Write-Host "`n🎉 SUCCESS! Authentication fix worked!" -ForegroundColor Green
            } else {
                Write-Host "`n❌ Build failed - check logs for authentication errors" -ForegroundColor Red
            }
        } else {
            Write-Host "`n⏳ Build is $($build.status)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ No builds found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nRun this script again to check status: .\check-build.ps1" -ForegroundColor Cyan
