# Azure DevOps Parallelism Solutions

## 🚨 Problem: Hosted Parallelism Required

If you see this error when running pipelines:
```
##[error]No hosted parallelism has been purchased or granted. To request a free parallelism grant, please fill out the following form https://aka.ms/azpipelines-parallelism-request
```

This happens because Azure DevOps requires parallelism grants even for single jobs in many cases.

## ✅ Solution Options

### Option 1: Request Free Parallelism Grant (Recommended)

1. **Fill out the form**: https://aka.ms/azpipelines-parallelism-request
2. **Provide these details**:
   - **Organization**: loic0161
   - **Project**: EasyPIM-CICD
   - **Use case**: "Open source PowerShell project for Azure PIM policy automation"
   - **Repository**: Link to your GitHub repo
   - **Justification**: "Need to run CI/CD pipelines for testing Azure authentication and PIM policy deployment"

3. **Wait for approval** (usually 1-3 business days)
4. **Retry your pipelines** once approved

### Option 2: Use Self-Hosted Agent (Immediate Solution)

If you need to test immediately, you can use a self-hosted agent:

#### Step 1: Install Azure DevOps Agent

```powershell
# Download and install agent
$agentDir = "C:\azagent"
New-Item -ItemType Directory -Path $agentDir -Force
Set-Location $agentDir

# Download latest agent
$uri = "https://vstsagentpackage.azureedge.net/agent/3.232.0/vsts-agent-win-x64-3.232.0.zip"
Invoke-WebRequest -Uri $uri -OutFile "agent.zip"
Expand-Archive -Path "agent.zip" -DestinationPath . -Force

# Configure agent
.\config.cmd
```

#### Step 2: Agent Configuration
When prompted:
- **Server URL**: `https://dev.azure.com/loic0161`
- **Authentication**: Personal Access Token (PAT)
- **Agent pool**: Default
- **Agent name**: `EasyPIM-Agent-01`
- **Run as service**: Y

#### Step 3: Create PAT Token
1. Go to https://dev.azure.com/loic0161/_usersSettings/tokens
2. Click "New Token"
3. **Name**: `EasyPIM-Agent`
4. **Scopes**: Agent Pools (read, manage)
5. Copy the token for agent configuration

#### Step 4: Update Pipeline to Use Self-Hosted Agent

```yaml
# Replace this:
pool:
  vmImage: 'ubuntu-latest'

# With this:
pool:
  name: 'Default'
  demands:
  - agent.name -equals EasyPIM-Agent-01
```

### Option 3: Use GitHub Actions (Alternative)

If Azure DevOps parallelism continues to be an issue, you can use the GitHub Actions workflows instead:

1. **Fork the repository** to your GitHub account
2. **Run the GitHub setup script**:
   ```powershell
   .\scripts\configure-cicd.ps1 -Platform GitHub -GitHubRepository "yourusername/EasyPIM-CICD" -ResourceGroupName "rg-easypim-cicd-test" -Force
   ```
3. **Use GitHub Actions** which has more generous free tiers

## 🎯 Recommendation

**For production use**: Request the free parallelism grant (Option 1)
**For immediate testing**: Use self-hosted agent (Option 2)
**For development**: Consider GitHub Actions (Option 3)

## 📋 Current Pipeline Status

✅ **Pipeline Templates Updated**: All pipelines now use minimal parallelism
✅ **Sequential Execution**: Jobs run one after another
✅ **OIDC Authentication**: Ready for secure authentication
✅ **Variable Groups**: Configured with all required secrets

The pipelines are ready to run as soon as the parallelism issue is resolved!
