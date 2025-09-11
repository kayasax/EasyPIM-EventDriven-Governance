# Upload Fixed Pipeline Templates - No Parallelism Issues
Write-Host "🔧 Uploading fixed pipeline templates..." -ForegroundColor Cyan

# Get Azure DevOps token
$token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query "accessToken" -o tsv
if (-not $token) {
    Write-Host "❌ Failed to get Azure DevOps token" -ForegroundColor Red
    exit 1
}

$Organization = "loic0161"
$Project = "EasyPIM-CICD"
$repoUrl = "https://oauth2:$token@dev.azure.com/$Organization/$Project/_git/$Project"

# Clone or update repository
if (Test-Path "temp-upload-repo") {
    Remove-Item "temp-upload-repo" -Recurse -Force
}

Write-Host "📥 Cloning repository..." -ForegroundColor Gray
git clone $repoUrl "temp-upload-repo" 2>$null
cd temp-upload-repo

# Create templates directory if it doesn't exist
if (-not (Test-Path "templates")) {
    New-Item -ItemType Directory -Path "templates" -Force
}

# Copy all fixed templates
Write-Host "📋 Copying updated templates..." -ForegroundColor Gray
Copy-Item "..\templates\azure-pipelines-auth-test.yml" "templates\" -Force
Copy-Item "..\templates\azure-pipelines-orchestrator.yml" "templates\" -Force
Copy-Item "..\templates\azure-pipelines-drift-detection.yml" "templates\" -Force

# Commit and push changes
Write-Host "📤 Uploading templates..." -ForegroundColor Gray
git add templates/
git commit -m "Fix: Update all pipeline templates to avoid parallelism requirements

- Modified auth test pipeline to use Windows agents and proper job structure
- Updated variable group names from EasyPIM-EventDriven-Governance to EasyPIM-Variables
- Changed from ubuntu-latest to windows-latest for better free tier compatibility
- Restructured pipelines to use single job approach avoiding parallelism limits"

git push

cd ..
Remove-Item "temp-upload-repo" -Recurse -Force

Write-Host "✅ Pipeline templates updated successfully!" -ForegroundColor Green
Write-Host "🔗 View at: https://dev.azure.com/$Organization/$Project/_git/$Project?path=%2Ftemplates" -ForegroundColor Gray
