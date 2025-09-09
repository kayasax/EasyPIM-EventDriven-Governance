# Quick Azure Function Update Script
# This script updates the existing function with the latest fixes

param(
    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName = "func-easypim-test", # Default name, change if needed

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-easypim" # Default name, change if needed
)

Write-Host "🚀 Updating Azure Function with latest fixes..." -ForegroundColor Cyan

# Get the function URL first to test with
try {
    Write-Host "🔗 Getting current function URL..." -ForegroundColor Blue
    $functionKey = az functionapp keys list --resource-group $ResourceGroupName --name $FunctionAppName --query "functionKeys.default" -o tsv 2>$null
    if ($functionKey) {
        $functionUrl = "https://$FunctionAppName.azurewebsites.net/api/EasyPIM-secret-change-detected?code=$functionKey"
        Write-Host "✅ Function URL: $functionUrl" -ForegroundColor Green
    } else {
        Write-Warning "Could not retrieve function URL - will get it after deployment"
    }
} catch {
    Write-Warning "Could not retrieve function URL - will get it after deployment"
}

# Create deployment package
$tempDir = Join-Path $env:TEMP "easypim-function-update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$zipPath = "$tempDir.zip"

Write-Host "📦 Creating deployment package..." -ForegroundColor Blue

# Copy function files to temp directory
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy the main function files
$functionDir = Join-Path $tempDir "EasyPIM-secret-change-detected"
New-Item -ItemType Directory -Path $functionDir -Force | Out-Null

Copy-Item -Path ".\EasyPIM-secret-change-detected\run.ps1" -Destination $functionDir -Force
Copy-Item -Path ".\EasyPIM-secret-change-detected\function.json" -Destination $functionDir -Force

# Copy the updated profile.ps1 and requirements.psd1
Copy-Item -Path ".\profile.ps1" -Destination $tempDir -Force
Copy-Item -Path ".\requirements.psd1" -Destination $tempDir -Force

# Create host.json if it doesn't exist
$hostJsonPath = Join-Path $tempDir "host.json"
if (-not (Test-Path $hostJsonPath)) {
    @{
        version = "2.0"
        extensionBundle = @{
            id = "Microsoft.Azure.Functions.ExtensionBundle"
            version = "[4.*, 5.0.0)"
        }
        functionTimeout = "00:05:00"
    } | ConvertTo-Json | Set-Content -Path $hostJsonPath
}

# Create the zip package
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)

Write-Host "✅ Package created: $zipPath" -ForegroundColor Green

# Deploy the function
Write-Host "🔄 Deploying to Azure..." -ForegroundColor Blue
try {
    az functionapp deployment source config-zip `
        --resource-group $ResourceGroupName `
        --name $FunctionAppName `
        --src $zipPath

    Write-Host "✅ Function deployed successfully!" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to deploy function: $_"
    Write-Host "Please check if the function app name and resource group are correct." -ForegroundColor Yellow
    exit 1
}

# Get the updated function URL
Write-Host "🔗 Getting updated function URL..." -ForegroundColor Blue
try {
    $functionKey = az functionapp keys list --resource-group $ResourceGroupName --name $FunctionAppName --query "functionKeys.default" -o tsv
    $functionUrl = "https://$FunctionAppName.azurewebsites.net/api/EasyPIM-secret-change-detected?code=$functionKey"

    Write-Host "✅ Updated Function URL: $functionUrl" -ForegroundColor Green

    # Copy to clipboard if possible
    try {
        $functionUrl | Set-Clipboard
        Write-Host "📋 URL copied to clipboard!" -ForegroundColor Green
    } catch {
        # Clipboard not available
    }

} catch {
    Write-Warning "Could not retrieve function URL automatically. Get it from Azure Portal."
}

# Clean up
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "🎉 Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 What's Fixed:" -ForegroundColor Cyan
Write-Host "   ✅ Event Grid validation response format corrected"
Write-Host "   ✅ Workflow parameters now included in GitHub API calls"
Write-Host "   ✅ Profile.ps1 errors eliminated"
Write-Host "   ✅ Proper HTTP response binding used"
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Create/update Event Grid subscription with the function URL above"
Write-Host "   2. Test by modifying a Key Vault secret"
Write-Host "   3. Check GitHub Actions for workflow runs with parameters"
Write-Host ""
Write-Host "📊 Test Command:" -ForegroundColor Yellow
Write-Host "   .\scripts\test-function-parameters.ps1 -FunctionUrl '$functionUrl' -TestType test"
