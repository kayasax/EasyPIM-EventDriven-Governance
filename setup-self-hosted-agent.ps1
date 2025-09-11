# 🖥️ Automated Azure DevOps Self-Hosted Agent Setup
# Run this script as Administrator

param(
    [Parameter(Mandatory=$true)]
    [string]$PersonalAccessToken,

    [Parameter(Mandatory=$false)]
    [string]$AgentName = "$env:COMPUTERNAME-EasyPIM",

    [Parameter(Mandatory=$false)]
    [string]$AgentDir = "C:\AzureAgent"
)

Write-Host "🚀 Setting up Azure DevOps Self-Hosted Agent..." -ForegroundColor Cyan

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host "   Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Variables
$orgUrl = "https://dev.azure.com/loic0161"
$pool = "Default"
$agentDownloadUrl = "https://github.com/Microsoft/azure-pipelines-agent/releases/download/v3.243.1/vsts-agent-win-x64-3.243.1.zip"

try {
    # Step 1: Create agent directory
    Write-Host "`n📁 Creating agent directory: $AgentDir" -ForegroundColor Yellow
    if (Test-Path $AgentDir) {
        Write-Host "   Directory already exists, cleaning..." -ForegroundColor Gray
        Remove-Item "$AgentDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $AgentDir -Force | Out-Null
    }

    # Step 2: Download agent
    Write-Host "`n📥 Downloading Azure DevOps agent..." -ForegroundColor Yellow
    $agentZip = "$AgentDir\agent.zip"

    # Test network connectivity first
    Write-Host "   Testing network connectivity..." -ForegroundColor Gray
    try {
        $testConnection = Test-NetConnection -ComputerName "vstsagentpackage.azureedge.net" -Port 443 -WarningAction SilentlyContinue
        if (-not $testConnection.TcpTestSucceeded) {
            throw "Cannot reach Azure DevOps agent download server"
        }
        Write-Host "   ✅ Network connectivity confirmed" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ Network test failed, trying alternative method..." -ForegroundColor Yellow
    }

    # Try multiple download methods
    $downloadSuccess = $false

    # Method 1: Invoke-WebRequest (modern approach)
    try {
        Write-Host "   Attempting download with Invoke-WebRequest..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $agentDownloadUrl -OutFile $agentZip -UseBasicParsing -TimeoutSec 60
        $downloadSuccess = $true
        Write-Host "   ✅ Download completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Invoke-WebRequest failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Method 2: WebClient (fallback)
    if (-not $downloadSuccess) {
        try {
            Write-Host "   Attempting download with WebClient..." -ForegroundColor Gray
            $webClient = New-Object System.Net.WebClient
            $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            $webClient.DownloadFile($agentDownloadUrl, $agentZip)
            $downloadSuccess = $true
            Write-Host "   ✅ Download completed successfully" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ WebClient failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Method 3: Manual download instruction
    if (-not $downloadSuccess) {
        Write-Host "`n❌ Automatic download failed. Manual download required:" -ForegroundColor Red
        Write-Host "   1. Go to: https://github.com/microsoft/azure-pipelines-agent/releases" -ForegroundColor Yellow
        Write-Host "   2. Download latest vsts-agent-win-x64-*.zip" -ForegroundColor Yellow
        Write-Host "   3. Save as: $agentZip" -ForegroundColor Yellow
        Write-Host "   4. Run this script again" -ForegroundColor Yellow
        throw "Manual download required"
    }
    Write-Host "   ✅ Agent downloaded" -ForegroundColor Green

    # Step 3: Extract agent
    Write-Host "`n📦 Extracting agent..." -ForegroundColor Yellow
    Expand-Archive -Path $agentZip -DestinationPath $AgentDir -Force
    Remove-Item $agentZip
    Write-Host "   ✅ Agent extracted" -ForegroundColor Green

    # Step 4: Configure agent
    Write-Host "`n🔧 Configuring agent..." -ForegroundColor Yellow
    Set-Location $AgentDir

    # Create unattended config
    $configArgs = @(
        "--unattended"
        "--url", $orgUrl
        "--auth", "pat"
        "--token", $PersonalAccessToken
        "--pool", $pool
        "--agent", $AgentName
        "--acceptTeeEula"
        "--runAsService"
    )

    & ".\config.cmd" @configArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Agent configured successfully" -ForegroundColor Green
    } else {
        throw "Agent configuration failed with exit code $LASTEXITCODE"
    }

    # Step 5: Install and start service
    Write-Host "`n🔄 Installing and starting service..." -ForegroundColor Yellow

    & ".\svc.cmd" "install"
    if ($LASTEXITCODE -ne 0) {
        throw "Service installation failed"
    }

    Start-Sleep -Seconds 2

    & ".\svc.cmd" "start"
    if ($LASTEXITCODE -ne 0) {
        throw "Service start failed"
    }

    Write-Host "   ✅ Service installed and started" -ForegroundColor Green

    # Step 6: Verify
    Write-Host "`n✅ Setup completed successfully!" -ForegroundColor Green
    Write-Host "`n📋 Agent Details:" -ForegroundColor Cyan
    Write-Host "   Name: $AgentName" -ForegroundColor White
    Write-Host "   Pool: $pool" -ForegroundColor White
    Write-Host "   Directory: $AgentDir" -ForegroundColor White
    Write-Host "   Service: Azure Devops Agent ($AgentName)" -ForegroundColor White

    Write-Host "`n🔍 Verify your agent at:" -ForegroundColor Yellow
    Write-Host "   $orgUrl/EasyPIM-CICD/_settings/agentpools?poolId=1&view=agents" -ForegroundColor Gray

    Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Check agent status in Azure DevOps (should show Online)" -ForegroundColor White
    Write-Host "   2. Update pipeline to use: pool: Default" -ForegroundColor White
    Write-Host "   3. Run your EasyPIM pipeline - no parallelism limits!" -ForegroundColor White

} catch {
    Write-Host "❌ Setup failed: $_" -ForegroundColor Red
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verify PAT token has 'Agent Pools (read, manage)' permissions" -ForegroundColor White
    Write-Host "   2. Check internet connectivity" -ForegroundColor White
    Write-Host "   3. Ensure running as Administrator" -ForegroundColor White
    Write-Host "   4. Check Windows Defender/antivirus exclusions" -ForegroundColor White
}

Write-Host "`n📖 For manual setup instructions, see: docs\Self-Hosted-Agent-Setup.md" -ForegroundColor Gray
