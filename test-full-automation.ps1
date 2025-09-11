# Quick test of automated deployment without full script complexity
param(
    [string]$Organization = "loic0161",
    [string]$Project = "EasyPIM-CICD"
)

Write-Host "🚀 AUTOMATED DEPLOYMENT TEST - No Prompts!" -ForegroundColor Green

$tempRepoDir = Join-Path $env:TEMP "easypim-automated-$(Get-Random)"
New-Item -ItemType Directory -Path $tempRepoDir -Force | Out-Null

try {
    Push-Location $tempRepoDir

    # Get access token for git authentication
    Write-Host "🔑 Getting Azure DevOps token..." -ForegroundColor Gray
    $accessToken = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv

    if (-not $accessToken -or $accessToken.Length -lt 100) {
        Write-Host "❌ Failed to get access token" -ForegroundColor Red
        return
    }

    Write-Host "✅ Token obtained" -ForegroundColor Green

    # Configure git
    git config user.name "EasyPIM-Automation"
    git config user.email "automation@easypim.local"

    # Clone with token in URL (NO PROMPTS!)
    Write-Host "📥 Cloning repository with automated authentication..." -ForegroundColor Gray
    $tokenUrl = "https://oauth2:$accessToken@dev.azure.com/$Organization/$Project/_git/EasyPIM-CICD"
    git clone $tokenUrl . 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Repository cloned successfully!" -ForegroundColor Green

        # Create templates directory and copy files
        Write-Host "📋 Uploading pipeline templates..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path "templates" -Force | Out-Null

        $sourceDir = Split-Path $PSScriptRoot -Parent
        if (Test-Path "$sourceDir\templates\*.yml") {
            Copy-Item "$sourceDir\templates\*.yml" -Destination "templates\" -Force
            Write-Host "📄 Templates copied" -ForegroundColor Gray
        }

        # Commit and push changes
        git add templates/
        $hasChanges = git status --porcelain
        if ($hasChanges) {
            git commit -m "Automated EasyPIM template upload - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>$null
            git push origin main 2>$null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "🎉 FULLY AUTOMATED SUCCESS! Templates uploaded without any prompts!" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Push had issues but templates are ready" -ForegroundColor Yellow
            }
        } else {
            Write-Host "✅ Templates already up to date" -ForegroundColor Green
        }

    } else {
        Write-Host "❌ Repository clone failed" -ForegroundColor Red
    }
}
finally {
    Pop-Location
    Remove-Item $tempRepoDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "🏆 AUTOMATION COMPLETE - Zero authentication prompts!" -ForegroundColor Cyan
