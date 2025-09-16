# 🚀 EasyPIM Multi-Platform Event Routing - Azure DevOps Integration

## 🎯 **Overview**

Extend your existing Key Vault → Function App → GitHub Actions automation to **also support Azure DevOps pipelines** based on secret naming patterns.

## 🏗️ **Enhanced Architecture**

```
Key Vault Secret Change → Azure Function → Route by Secret Name
     (easypim-config)      (PowerShell)           ↓
                                          ┌─────────────────────┐
                                          │  🔄 Smart Routing   │
                                          │                     │
    ┌─────────────────────────────────────┼─────────────────────┼─────────────────────────────────────┐
    │                                     │                     │                                     │
    ▼                                     │                     ▼                                     │
easypim-*-github                         │            easypim-*-ado                                  │
easypim-*-gh                             │            easypim-*-azdo                                 │
easypim-config                           │            easypim-*-devops                               │
    │                                     │                     │                                     │
    ▼                                     │                     ▼                                     │
┌─────────────────────┐                  │            ┌─────────────────────┐                      │
│   GitHub Actions    │                  │            │  Azure DevOps       │                      │
│                     │                  │            │  Pipeline           │                      │
│ • Workflow Dispatch │                  │            │                     │                      │
│ • Smart Parameters  │                  │            │ • REST API Trigger  │                      │
│ • Existing Logic    │                  │            │ • Variable Passing  │                      │
└─────────────────────┘                  │            └─────────────────────┘                      │
                                         │                                                           │
                                         └───────────────────────────────────────────────────────────┘
```

## 🔧 **Implementation Strategy**

### **1️⃣ Secret Name Routing Patterns**

**GitHub Actions (Current):**
```
easypim-config              → GitHub Actions (default)
easypim-prod-github         → GitHub Actions
easypim-test-gh             → GitHub Actions (WhatIf mode)
easypim-dev-config          → GitHub Actions (WhatIf mode)
```

**Azure DevOps (New):**
```
easypim-config-ado          → Azure DevOps Pipeline
easypim-prod-azdo           → Azure DevOps Pipeline
easypim-test-devops         → Azure DevOps Pipeline (WhatIf mode)
easypim-enterprise-ado      → Azure DevOps Pipeline
```

### **2️⃣ Enhanced Azure Function Logic**

Update your existing `run.ps1` to include ADO routing:

```powershell
# In your existing Azure Function
param($req, $TriggerMetadata)

# ... existing validation logic ...

# Extract secret information
$secretName = $eventData.data.ObjectName
$vaultName = $eventData.data.VaultName

# 🚀 NEW: Platform routing logic
$targetPlatform = "github"  # default
if ($secretName -match "ado|azdo|devops") {
    $targetPlatform = "azuredevops"
}

Write-Host "🎯 Routing to platform: $targetPlatform for secret: $secretName"

switch ($targetPlatform) {
    "github" {
        & TriggerGitHubActions -SecretName $secretName -VaultName $vaultName
    }
    "azuredevops" {
        & TriggerAzureDevOpsPipeline -SecretName $secretName -VaultName $vaultName
    }
}
```

### **3️⃣ Azure DevOps Pipeline Trigger Function**

Add this new function to your Azure Function:

```powershell
function TriggerAzureDevOpsPipeline {
    param(
        [string]$SecretName,
        [string]$VaultName
    )
    
    # Azure DevOps configuration
    $adoOrganization = $env:ADO_ORGANIZATION  # e.g., "mycompany"
    $adoProject = $env:ADO_PROJECT           # e.g., "EasyPIM"
    $adoPipeline = $env:ADO_PIPELINE_ID      # e.g., "12" or "EasyPIM-Orchestrator"
    $adoToken = $env:ADO_PAT                 # Personal Access Token
    
    if (-not $adoToken) {
        Write-Error "ADO_PAT environment variable not set"
        return
    }
    
    # Build intelligent pipeline parameters
    $pipelineParameters = @{
        "configSecretName" = $SecretName
        "whatIfMode" = ($SecretName -match "test|debug|dev").ToString().ToLower()
        "mode" = if ($SecretName -match "initial|setup") { "initial" } else { "delta" }
        "verbose" = ($SecretName -match "verbose|debug").ToString().ToLower()
        "runDescription" = "Triggered by Key Vault secret change: $SecretName in $VaultName"
    }
    
    # Environment variable overrides (same logic as GitHub)
    if ($env:EASYPIM_WHATIF) { $pipelineParameters.whatIfMode = $env:EASYPIM_WHATIF.ToLower() }
    if ($env:EASYPIM_MODE) { $pipelineParameters.mode = $env:EASYPIM_MODE }
    
    # Azure DevOps REST API call
    $apiUrl = "https://dev.azure.com/$adoOrganization/$adoProject/_apis/pipelines/$adoPipeline/runs?api-version=7.0"
    
    $body = @{
        resources = @{
            repositories = @{
                self = @{
                    refName = "refs/heads/main"
                }
            }
        }
        templateParameters = $pipelineParameters
    } | ConvertTo-Json -Depth 4
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$adoToken"))
        "Content-Type" = "application/json"
    }
    
    try {
        Write-Host "🚀 Triggering Azure DevOps pipeline: $adoPipeline"
        Write-Host "📋 Parameters: $($pipelineParameters | ConvertTo-Json -Compress)"
        
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body -Headers $headers
        
        Write-Host "✅ Azure DevOps pipeline triggered successfully!"
        Write-Host "📊 Run ID: $($response.id)"
        Write-Host "🔗 Pipeline URL: $($response._links.web.href)"
        
        return @{
            success = $true
            runId = $response.id
            runUrl = $response._links.web.href
        }
    }
    catch {
        Write-Error "❌ Failed to trigger Azure DevOps pipeline: $($_.Exception.Message)"
        return @{ success = $false; error = $_.Exception.Message }
    }
}
```

## 📋 **Environment Variables Setup**

Add these new environment variables to your Function App:

| Variable | Description | Example Value | Required |
|----------|-------------|---------------|----------|
| `ADO_ORGANIZATION` | Azure DevOps organization name | `mycompany` | ✅ **For ADO** |
| `ADO_PROJECT` | Azure DevOps project name | `EasyPIM` | ✅ **For ADO** |
| `ADO_PIPELINE_ID` | Pipeline ID or name | `12` or `EasyPIM-Orchestrator` | ✅ **For ADO** |
| `ADO_PAT` | Personal Access Token | `your-ado-pat-token` | ✅ **For ADO** |

## 🔐 **Azure DevOps Personal Access Token Setup**

1. **Azure DevOps** → **User Settings** → **Personal Access Tokens**
2. **Create new token** with scopes:
   - `Build (read and execute)` - To trigger pipelines
   - `Variable Groups (read)` - If using variable groups
3. **Copy token** and set as `ADO_PAT` in Function App settings

## 📊 **Azure DevOps Pipeline Template**

Create a pipeline in Azure DevOps that accepts the parameters:

```yaml
# azure-pipelines-easypim.yml
trigger: none  # Only triggered via API

parameters:
- name: configSecretName
  displayName: 'Configuration Secret Name'
  type: string
  default: 'easypim-config'

- name: whatIfMode
  displayName: 'What-If Mode (Preview Only)'
  type: boolean
  default: false

- name: mode
  displayName: 'Execution Mode'
  type: string
  default: 'delta'
  values:
  - delta
  - initial

- name: verbose
  displayName: 'Verbose Output'
  type: boolean
  default: false

- name: runDescription
  displayName: 'Run Description'
  type: string
  default: 'Manual trigger'

variables:
  KEYVAULT_NAME: 'kv-easypim-8368'
  TENANT_ID: $(AZURE_TENANT_ID)
  SUBSCRIPTION_ID: $(AZURE_SUBSCRIPTION_ID)
  CLIENT_ID: $(AZURE_CLIENT_ID)

stages:
- stage: EasyPIMExecution
  displayName: 'EasyPIM Policy Orchestration'
  jobs:
  - job: ExecuteEasyPIM
    displayName: 'Execute EasyPIM Orchestrator'
    pool:
      vmImage: 'ubuntu-latest'
    
    steps:
    - task: AzurePowerShell@5
      displayName: 'Setup Authentication'
      inputs:
        azureSubscription: 'EasyPIM-ServiceConnection'
        ScriptType: 'InlineScript'
        Inline: |
          Write-Host "🔐 Setting up authentication for EasyPIM..." -ForegroundColor Cyan
          Write-Host "Parameters received:" -ForegroundColor Blue
          Write-Host "  Secret: ${{ parameters.configSecretName }}"
          Write-Host "  WhatIf: ${{ parameters.whatIfMode }}"
          Write-Host "  Mode: ${{ parameters.mode }}"
          Write-Host "  Description: ${{ parameters.runDescription }}"
        
    - task: AzurePowerShell@5
      displayName: 'Execute EasyPIM Orchestrator'
      inputs:
        azureSubscription: 'EasyPIM-ServiceConnection'
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/scripts/workflows/Invoke-EasyPIMExecution.ps1'
        ScriptArguments: >
          -KeyVaultName "$(KEYVAULT_NAME)"
          -SecretName "${{ parameters.configSecretName }}"
          -TenantId "$(TENANT_ID)"
          -WhatIf:$${{ parameters.whatIfMode }}
          -Mode "${{ parameters.mode }}"
          -Verbose:$${{ parameters.verbose }}
        azurePowerShellVersion: 'LatestVersion'
        workingDirectory: '$(System.DefaultWorkingDirectory)'
```

## 🎯 **Usage Examples**

### **Scenario 1: GitHub Actions (Current Behavior)**
```json
// Key Vault secret name: "easypim-prod-config"
// Result: Triggers GitHub Actions workflow (existing logic)
```

### **Scenario 2: Azure DevOps Pipeline (New)**
```json
// Key Vault secret name: "easypim-prod-ado"
// Result: Triggers Azure DevOps pipeline with parameters
```

### **Scenario 3: Test Environment**
```json
// Key Vault secret name: "easypim-test-devops"
// Result: Triggers Azure DevOps pipeline with WhatIf=true
```

## 🔄 **Migration Strategy**

### **Phase 1: Parallel Deployment**
1. Keep existing GitHub Actions routing intact
2. Add Azure DevOps routing for new secret patterns
3. Test with dedicated test secrets (e.g., `easypim-test-ado`)

### **Phase 2: Gradual Migration**
1. Migrate specific environments to ADO by changing secret names
2. Monitor both platforms during transition
3. Maintain fallback to GitHub Actions for non-matching patterns

### **Phase 3: Full Integration**
1. Standardize on secret naming conventions
2. Document platform selection criteria
3. Implement cross-platform monitoring

## 📈 **Benefits**

✅ **Platform Flexibility:** Route to different CI/CD platforms based on needs  
✅ **Team Autonomy:** Different teams can use their preferred platform  
✅ **Enterprise Ready:** Azure DevOps integration for enterprise scenarios  
✅ **Smart Routing:** Automatic platform detection based on secret names  
✅ **Consistent Parameters:** Same intelligent parameter logic across platforms  
✅ **Zero Disruption:** Existing GitHub Actions workflows continue unchanged  

## 🛡️ **Security Considerations**

- **Separate tokens** for each platform (GitHub PAT vs ADO PAT)
- **Minimal permissions** for each Personal Access Token
- **Environment isolation** through secret naming patterns
- **Audit trail** across both GitHub Actions and Azure DevOps
- **Secret rotation** capability for both authentication methods

---

**🚀 This solution gives you the best of both worlds - keep your existing GitHub Actions automation while adding Azure DevOps support through intelligent routing!**
