# Deploy Updated Azure Function with Parameters Support
# This script updates the Azure Function with enhanced parameter handling

param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$GitHubToken
)

Write-Host "🚀 Deploying Enhanced Azure Function for EasyPIM Automation..." -ForegroundColor Cyan

# Check if Azure CLI is logged in
$azAccount = az account show --query "user.name" -o tsv 2>$null
if (-not $azAccount) {
    Write-Error "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "✅ Logged into Azure as: $azAccount" -ForegroundColor Green

# Set the subscription context (if needed)
$currentSub = az account show --query "name" -o tsv
Write-Host "📋 Using subscription: $currentSub" -ForegroundColor Blue

# Create a temporary zip file for deployment
$tempDir = Join-Path $env:TEMP "easypim-function-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$zipPath = "$tempDir.zip"
$sourceDir = Join-Path $PSScriptRoot ".." "EasyPIM-secret-change-detected"

Write-Host "📦 Preparing function deployment package..." -ForegroundColor Blue
Write-Host "   Source: $sourceDir"
Write-Host "   Temp: $tempDir"

# Create temp directory and copy function files
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Copy-Item -Path "$sourceDir\*" -Destination $tempDir -Recurse -Force

# Create the zip package
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)

Write-Host "✅ Function package created: $zipPath" -ForegroundColor Green

# Deploy the function
Write-Host "🔄 Deploying function to Azure..." -ForegroundColor Blue
try {
    az functionapp deployment source config-zip `
        --resource-group $ResourceGroupName `
        --name $FunctionAppName `
        --src $zipPath

    Write-Host "✅ Function deployed successfully!" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to deploy function: $_"
    exit 1
}

# Configure environment variables if GitHub token is provided
if ($GitHubToken) {
    Write-Host "🔧 Configuring environment variables..." -ForegroundColor Blue

    try {
        # Set the GitHub token
        az functionapp config appsettings set `
            --resource-group $ResourceGroupName `
            --name $FunctionAppName `
            --settings "GITHUB_TOKEN=$GitHubToken"

        # Set default EasyPIM configuration
        az functionapp config appsettings set `
            --resource-group $ResourceGroupName `
            --name $FunctionAppName `
            --settings "EASYPIM_WHATIF=false" "EASYPIM_MODE=delta" "EASYPIM_VERBOSE=true"

        Write-Host "✅ Environment variables configured!" -ForegroundColor Green
    } catch {
        Write-Warning "⚠️  Failed to set environment variables: $_"
        Write-Host "Please set them manually in the Azure Portal:" -ForegroundColor Yellow
        Write-Host "   Function App → Configuration → Application settings" -ForegroundColor Yellow
    }
}

# Get the function URL for Event Grid subscription
Write-Host "🔗 Getting function URL..." -ForegroundColor Blue
try {
    $functionKey = az functionapp keys list --resource-group $ResourceGroupName --name $FunctionAppName --query "functionKeys.default" -o tsv
    $functionUrl = "https://$FunctionAppName.azurewebsites.net/api/EasyPIM-secret-change-detected?code=$functionKey"

    Write-Host "✅ Function URL: $functionUrl" -ForegroundColor Green
    Write-Host "📋 Use this URL for your Event Grid subscription endpoint" -ForegroundColor Yellow
} catch {
    Write-Warning "⚠️  Could not retrieve function URL. Get it from Azure Portal → Function App → Functions → Get Function URL"
}

# Clean up
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

Write-Host "🎉 Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. If you didn't provide a GitHub token, set GITHUB_TOKEN in Function App settings"
Write-Host "   2. Create/update your Event Grid subscription with the function URL above"
Write-Host "   3. Test by modifying a secret in your Key Vault"
Write-Host "   4. Check GitHub Actions for automated workflow runs"
Write-Host ""
Write-Host "🔧 Optional Configuration (Function App → Configuration):" -ForegroundColor Cyan
Write-Host "   EASYPIM_WHATIF=true     # Enable preview mode"
Write-Host "   EASYPIM_MODE=initial    # Use initial mode"
Write-Host "   EASYPIM_VERBOSE=false   # Disable verbose logging"
