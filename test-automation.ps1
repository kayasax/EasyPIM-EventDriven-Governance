# Test Automated Azure DevOps Upload
# Simple test of the git automation approach

param(
    [string]$Organization = "loic0161",
    [string]$Project = "EasyPIM-CICD"
)

Write-Host "🚀 Testing Automated Azure DevOps Template Upload" -ForegroundColor Cyan

try {
    $tempDir = Join-Path $env:TEMP "test-ado-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Push-Location $tempDir

    Write-Host "📁 Working in: $tempDir" -ForegroundColor Gray

    # Get Azure DevOps access token
    Write-Host "🔑 Getting Azure DevOps access token..." -ForegroundColor Gray
    $accessToken = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv

    if (-not $accessToken -or $accessToken.Length -lt 100) {
        Write-Host "❌ Failed to get access token" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Token obtained ($($accessToken.Length) chars)" -ForegroundColor Green

    # Configure git
    git config user.name "EasyPIM-Test"
    git config user.email "test@easypim.local"

    # Test clone with token
    $tokenUrl = "https://oauth2:$accessToken@dev.azure.com/$Organization/$Project/_git/EasyPIM-CICD"
    Write-Host "📥 Testing repository access..." -ForegroundColor Gray

    git clone $tokenUrl . --quiet 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Repository cloned successfully!" -ForegroundColor Green
        Write-Host "📋 Repository contents:" -ForegroundColor Gray
        Get-ChildItem | ForEach-Object { Write-Host "  • $($_.Name)" -ForegroundColor White }

        # Test creating a file
        "Test file from automation $(Get-Date)" | Out-File -FilePath "automation-test.txt" -Encoding UTF8
        git add automation-test.txt --quiet
        git commit -m "Automated test - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" --quiet
        git push origin main --quiet 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "🎉 AUTOMATION SUCCESS! No authentication prompts!" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Push failed, but clone worked" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Repository clone failed" -ForegroundColor Red
    }
}
finally {
    Pop-Location
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "🔚 Test complete!" -ForegroundColor Cyan
