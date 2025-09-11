# Azure DevOps Self-Hosted Agent - Quick Setup
# This is a simpler version that works around network issues

param(
    [Parameter(Mandatory=$true)]
    [string]$PersonalAccessToken,

    [string]$AgentName = "$env:COMPUTERNAME-Agent",
    [string]$AgentDir = "C:\AzureAgent"
)

Write-Host "🚀 Azure DevOps Agent Quick Setup" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host "   Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$orgUrl = "https://dev.azure.com/loic0161"
$pool = "Default"

try {
    # Step 1: Check if agent directory exists
    Write-Host "`n📁 Checking agent directory: $AgentDir" -ForegroundColor Yellow
    if (-not (Test-Path $AgentDir)) {
        New-Item -ItemType Directory -Path $AgentDir -Force | Out-Null
        Write-Host "   ✅ Directory created" -ForegroundColor Green
    }

    # Step 2: Check if agent files exist
    $configPath = "$AgentDir\config.cmd"
    if (-not (Test-Path $configPath)) {
        Write-Host "`n📥 Agent files not found. Manual download required:" -ForegroundColor Yellow
        Write-Host "   1. Go to: https://github.com/Microsoft/azure-pipelines-agent/releases" -ForegroundColor Cyan
        Write-Host "   2. Download: vsts-agent-win-x64-[version].zip" -ForegroundColor Cyan
        Write-Host "   3. Extract to: $AgentDir" -ForegroundColor Cyan
        Write-Host "   4. Run this script again" -ForegroundColor Cyan

        Write-Host "`n🌐 Opening download page..." -ForegroundColor Yellow
        Start-Process "https://github.com/Microsoft/azure-pipelines-agent/releases"

        Read-Host "`nPress Enter after downloading and extracting the agent"

        if (-not (Test-Path $configPath)) {
            Write-Host "❌ Agent files still not found in $AgentDir" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "   ✅ Agent files found" -ForegroundColor Green

    # Step 3: Configure agent
    Write-Host "`n🔧 Configuring agent..." -ForegroundColor Yellow

    Set-Location $AgentDir

    $configArgs = @(
        "--unattended",
        "--url", $orgUrl,
        "--auth", "PAT",
        "--token", $PersonalAccessToken,
        "--pool", $pool,
        "--agent", $AgentName,
        "--replace",
        "--acceptTeeEula",
        "--runAsService"
    )

    Write-Host "   Running: .\config.cmd $($configArgs -join ' ')" -ForegroundColor Gray
    & .\config.cmd @configArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Agent configured successfully" -ForegroundColor Green

        Write-Host "`n🎉 Setup Complete!" -ForegroundColor Green
        Write-Host "==================" -ForegroundColor Green
        Write-Host "✅ Agent Name: $AgentName" -ForegroundColor White
        Write-Host "✅ Pool: $pool" -ForegroundColor White
        Write-Host "✅ Service: Azure Pipelines Agent ($AgentName)" -ForegroundColor White
        Write-Host "✅ Status: Running" -ForegroundColor White

        Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Go to Azure DevOps → Project Settings → Agent pools → Default" -ForegroundColor White
        Write-Host "2. Verify your agent is online" -ForegroundColor White
        Write-Host "3. Update your pipeline to use 'pool: Default'" -ForegroundColor White
        Write-Host "4. Run your EasyPIM pipeline!" -ForegroundColor White

    } else {
        Write-Host "   ❌ Agent configuration failed" -ForegroundColor Red
        Write-Host "   Check the output above for details" -ForegroundColor Yellow
    }

} catch {
    Write-Host "`n❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   • Verify your Personal Access Token has 'Agent Pools' permissions" -ForegroundColor White
    Write-Host "   • Check network connectivity to dev.azure.com" -ForegroundColor White
    Write-Host "   • Ensure you're running as Administrator" -ForegroundColor White
}

Read-Host "`nPress Enter to exit"
