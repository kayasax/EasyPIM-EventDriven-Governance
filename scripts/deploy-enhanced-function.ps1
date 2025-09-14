# Enhanced Function App Deployment Script
# This script updates your existing Azure Function to support both GitHub Actions and Azure DevOps pipeline triggering

param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory = $false)]
    [string]$AdoOrganization,
    
    [Parameter(Mandatory = $false)]
    [string]$AdoProject,
    
    [Parameter(Mandatory = $false)]
    [string]$AdoPipelineId,
    
    [Parameter(Mandatory = $false)]
    [string]$AdoToken
)

Write-Host "🚀 Deploying Enhanced EasyPIM Function App (Multi-Platform Support)" -ForegroundColor Cyan
Write-Host "Function App: $FunctionAppName" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White

# Check if Function App exists
try {
    $functionApp = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query "name" -o tsv 2>$null
    if (-not $functionApp) {
        Write-Host "❌ Function App '$FunctionAppName' not found in resource group '$ResourceGroupName'" -ForegroundColor Red
        Write-Host "Please create the Function App first or check the names." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Function App found: $FunctionAppName" -ForegroundColor Green
} catch {
    Write-Host "❌ Error checking Function App: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set up the enhanced function code
Write-Host "📦 Preparing enhanced function deployment package..." -ForegroundColor Yellow

$tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
Write-Host "   Temp directory: $tempDir" -ForegroundColor Gray

try {
    # Create function structure
    $functionDir = Join-Path $tempDir "EasyPIM-secret-change-detected"
    New-Item -ItemType Directory -Path $functionDir -Force | Out-Null
    
    # Copy the enhanced function code
    $functionCodePath = Join-Path $PSScriptRoot "enhanced-function-app-run.ps1"
    if (Test-Path $functionCodePath) {
        Copy-Item $functionCodePath (Join-Path $functionDir "run.ps1")
        Write-Host "   ✅ Enhanced function code copied" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Enhanced function code not found at: $functionCodePath" -ForegroundColor Red
        exit 1
    }
    
    # Create function.json
    $functionJson = @'
{
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": [ "post" ]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "res"
    }
  ]
}
'@
    $functionJson | Out-File -FilePath (Join-Path $functionDir "function.json") -Encoding UTF8
    Write-Host "   ✅ function.json created" -ForegroundColor Green
    
    # Create host.json (if needed)
    $hostJson = @'
{
  "version": "2.0",
  "functionTimeout": "00:05:00",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
'@
    $hostJson | Out-File -FilePath (Join-Path $tempDir "host.json") -Encoding UTF8
    
    # Create requirements.psd1 for PowerShell dependencies
    $requirementsPsd1 = @'
@{
    'Az' = '12.*'
    'Microsoft.Graph.Authentication' = '2.*'
}
'@
    $requirementsPsd1 | Out-File -FilePath (Join-Path $tempDir "requirements.psd1") -Encoding UTF8
    
    Write-Host "   ✅ Function package prepared" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error preparing function package: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Deploy the function
Write-Host "🔄 Deploying enhanced function to Azure..." -ForegroundColor Yellow

try {
    $deployResult = az functionapp deployment source config-zip --src "$tempDir.zip" --name $FunctionAppName --resource-group $ResourceGroupName 2>&1
    
    # Create zip file for deployment
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = "$tempDir.zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
    
    # Deploy using Azure CLI
    Write-Host "   Uploading function package..." -ForegroundColor Gray
    az functionapp deployment source config-zip --src $zipPath --name $FunctionAppName --resource-group $ResourceGroupName
    
    Write-Host "✅ Enhanced function deployed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error deploying function: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Deploy result: $deployResult" -ForegroundColor Gray
}

# Configure environment variables
Write-Host "⚙️ Configuring environment variables..." -ForegroundColor Yellow

$envVars = @()

# GitHub configuration (existing)
if ($GitHubToken) {
    $envVars += "GITHUB_TOKEN=$GitHubToken"
    Write-Host "   ✅ GitHub token configured" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ GitHub token not provided - GitHub Actions will not work" -ForegroundColor Yellow
}

# Azure DevOps configuration (new)
if ($AdoOrganization) {
    $envVars += "ADO_ORGANIZATION=$AdoOrganization"
    Write-Host "   ✅ Azure DevOps organization configured: $AdoOrganization" -ForegroundColor Green
}

if ($AdoProject) {
    $envVars += "ADO_PROJECT=$AdoProject"
    Write-Host "   ✅ Azure DevOps project configured: $AdoProject" -ForegroundColor Green
}

if ($AdoPipelineId) {
    $envVars += "ADO_PIPELINE_ID=$AdoPipelineId"
    Write-Host "   ✅ Azure DevOps pipeline ID configured: $AdoPipelineId" -ForegroundColor Green
}

if ($AdoToken) {
    $envVars += "ADO_PAT=$AdoToken"
    Write-Host "   ✅ Azure DevOps PAT token configured" -ForegroundColor Green
} else {
    if ($AdoOrganization) {
        Write-Host "   ⚠️ Azure DevOps PAT token not provided - ADO pipelines will not work" -ForegroundColor Yellow
    }
}

# Apply environment variables
if ($envVars.Count -gt 0) {
    try {
        Write-Host "   Setting environment variables..." -ForegroundColor Gray
        az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings $envVars
        Write-Host "   ✅ Environment variables configured" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Error setting environment variables: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Get function URL
try {
    $functionUrl = az functionapp function show --function-name "EasyPIM-secret-change-detected" --name $FunctionAppName --resource-group $ResourceGroupName --query "invokeUrlTemplate" -o tsv
    if ($functionUrl) {
        Write-Host "🔗 Function URL: $functionUrl" -ForegroundColor Cyan
        Write-Host "   Use this URL for your Event Grid subscription webhook endpoint" -ForegroundColor White
    }
} catch {
    Write-Host "⚠️ Could not retrieve function URL - check Function App portal" -ForegroundColor Yellow
}

# Clean up temp directory
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$tempDir.zip" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "🎉 Enhanced Function App Deployment Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Yellow
Write-Host "   ✅ Enhanced function code deployed with multi-platform support" -ForegroundColor White
Write-Host "   ✅ GitHub Actions integration: $(if ($GitHubToken) { 'CONFIGURED' } else { 'NOT CONFIGURED' })" -ForegroundColor White
Write-Host "   ✅ Azure DevOps integration: $(if ($AdoOrganization -and $AdoToken) { 'CONFIGURED' } else { 'NOT CONFIGURED' })" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Smart Routing Active:" -ForegroundColor Yellow
Write-Host "   • Secrets with 'ado', 'azdo', 'devops' → Azure DevOps pipelines" -ForegroundColor White
Write-Host "   • All other secrets → GitHub Actions (existing behavior)" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Yellow
if (-not $GitHubToken) {
    Write-Host "   1. Set GITHUB_TOKEN environment variable for GitHub Actions support" -ForegroundColor White
}
if (-not ($AdoOrganization -and $AdoToken)) {
    Write-Host "   2. Set Azure DevOps environment variables (ADO_ORGANIZATION, ADO_PROJECT, ADO_PIPELINE_ID, ADO_PAT)" -ForegroundColor White
}
Write-Host "   3. Test the enhanced routing with different secret name patterns" -ForegroundColor White
Write-Host "   4. Import the Azure DevOps pipeline template from templates/azure-pipelines-easypim.yml" -ForegroundColor White
Write-Host ""
