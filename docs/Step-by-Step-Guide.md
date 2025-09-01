# EasyPIM CI/CD Testing - Complete Step-by-Step Guide

**Based on:** [Official EasyPIM Step 14 CI/CD Guide](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)
**Updated for:** EasyPIM CI/CD Testing Repository with Bicep Infrastructure
**Date:** August 31, 2025

---

## 🎯 Overview

This guide provides a complete, secure setup for EasyPIM CI/CD testing using:
- ✅ **Official EasyPIM Step 14 patterns** - Uses `Invoke-EasyPIMOrchestrator` PowerShell cmdlets
- 🏗️ **Automated Azure infrastructure** - Bicep template deploys all required resources
- 🔐 **OIDC authentication** - No client secrets in GitHub repository
- 🔑 **Azure Key Vault integration** - Centralized, secure configuration storage
- ⚡ **GitHub Actions workflows** - Automated testing and deployment

---

## ⚠️ **Safety Notice**

**This guide uses harmless roles like "Printer Technician" and "Authentication Administrator" for all examples and testing.** These roles have minimal permissions and are safe for learning and testing purposes.

**In production environments:**
- Replace example roles with your actual production roles
- Always test policy changes in non-production environments first
- Use the principle of least privilege when assigning roles
- Review and approve all configuration changes through proper governance processes

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Deploy Azure Infrastructure](#step-1-deploy-azure-infrastructure)
3. [Step 2: Configure GitHub Repository](#step-2-configure-github-repository)
4. [Step 3: Initial EasyPIM Configuration](#step-3-initial-easypim-configuration)
5. [Step 4: Test Authentication Workflow](#step-4-test-authentication-workflow)
6. [Step 5: Progressive EasyPIM Validation](#step-5-progressive-easypim-validation)
7. [Step 6: Policy Drift Detection](#step-6-policy-drift-detection)
8. [Step 7: Full CI/CD Integration](#step-7-full-cicd-integration)
9. [Troubleshooting](#troubleshooting)
10. [Security Best Practices](#security-best-practices)

---

## Prerequisites

### Required Access & Permissions
- **Azure Subscription** with appropriate permissions:
  - `Contributor` + `User Access Administrator` roles
  - Access to create Azure AD applications and service principals
  - Ability to grant admin consent for Graph API permissions

- **GitHub Repository** access:
  - Admin access to `kayasax/EasyPIM-CICD-test` repository
  - Ability to configure secrets and variables

### Required Tools
- **PowerShell 7.0+** with modules:
  ```powershell
  Install-Module -Name Az.Accounts, Az.Resources, Az.KeyVault -Force
  ```
- **Azure CLI** (required for Bicep installation and Microsoft Graph support):
  ```powershell
  # Install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
  # Verify installation
  az --version
  ```

- **GitHub CLI** (optional, for automated GitHub configuration):
  ```powershell
  # Install GitHub CLI from: https://cli.github.com/
  # Or using winget on Windows
  winget install --id GitHub.cli

  # Verify installation and authenticate
  gh --version
  gh auth login
  ```
- **Azure Bicep CLI** (required for infrastructure deployment):

  **Install via Azure CLI (Recommended)**
  ```powershell
  # Install Bicep via Azure CLI
  az bicep install

  # Also install standalone Bicep CLI for PowerShell compatibility
  $installPath = "$env:USERPROFILE\.bicep"
  $installDir = New-Item -ItemType Directory -Path $installPath -Force
  $installDir.Attributes += 'Hidden'

  # Download latest Bicep CLI
  (New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")

  # Add to PATH
  # ---
  # By default, this adds Bicep to your **User PATH** (affects only your user, new shells required)
  # To add Bicep to the **System PATH** (all users, all shells), run the System option as Administrator
  # After updating PATH, you must restart all VS Code windows and terminals for changes to take effect!
  # ---

  # Option 1: Add to User PATH (no admin required)
  $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($currentPath -notlike "*$installPath*") {
      [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installPath", "User")
      $env:PATH += ";$installPath"
  }
  ```

  **Verify Installation:**
  ```powershell
  bicep --version
  az bicep version
  ```

- **Important Notes About Microsoft Graph in Bicep**:

  **Microsoft Graph Extension Status**: The Microsoft Graph Bicep extension is currently in **preview** and has some limitations:

  1. **Syntax Complexity**: The extension uses dynamic types that require careful configuration
  2. **Preview Status**: Features may change and aren't production-ready
  3. **Permission Requirements**: Requires elevated permissions for deployment

  **Recommended Approach**: We'll use **Azure CLI within the PowerShell script** for creating Azure AD resources, which is more stable and widely supported.

  Our deployment will:
  - ✅ Use **Bicep** for Azure resources (Key Vault, RBAC)
  - ✅ Use **Azure CLI** for Entra ID resources (App Registration, Service Principal, OIDC)
  - ✅ Combine both in a **PowerShell orchestration script**

  This hybrid approach provides reliability while maintaining Infrastructure as Code principles.

- **Git** for repository management### Target Environment
- **Azure Tenant** with PIM-enabled subscription
- **Test user accounts** for PIM assignment testing
- **Break-glass accounts** identified for protection

---

## Step 1: Deploy Azure Infrastructure

### 1.1 Prepare Deployment

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/kayasax/EasyPIM-CICD-test.git
   cd EasyPIM-CICD-test
   ```

2. **Review deployment parameters:**
   ```powershell
   # Edit scripts/deploy-azure-resources.parameters.json if needed
   code scripts/deploy-azure-resources.parameters.json
   ```

   **Key Parameters:**
   - **`environment`**: Environment suffix (dev, test, prod) used for:
     - 📛 **Resource naming**: `easypim-cicd-test-kv-abc123` (includes "test")
     - 🏷️ **Resource tagging**: Tags all resources with environment label
     - 🔑 **Service principal naming**: `easypim-cicd-test-sp`
     - 🔐 **Security configurations**: Different settings per environment (e.g., Key Vault purge protection disabled for "test")
   - **`location`**: Azure region (currently set to "francecentral")
   - **`githubRepository`**: Must match your actual GitHub repository


> **ℹ️ Region Note:**
> The deployment script automatically reads the region from your `deploy-azure-resources.parameters.json` file if you don't specify `-Location` explicitly.
> If you want to override the parameters file, use `-Location "your-region"` in the command. The script will show which location it's using during execution.

### 1.2 Execute Deployment

**Option A: PowerShell Script (Recommended)**
```powershell
# Connect to Azure (Azure CLI and PowerShell)
az login
Connect-AzAccount

# Deploy all resources using the hybrid approach
# The script will automatically use the region from your parameters file
.\scripts\deploy-azure-resources-hybrid.ps1 `
  -GitHubRepository "kayasax/EasyPIM-CICD-test" `
  -ResourceGroupName "rg-easypim-cicd-test"

# Or override the region explicitly if needed:
# .\scripts\deploy-azure-resources-hybrid.ps1 `
#   -GitHubRepository "kayasax/EasyPIM-CICD-test" `
#   -ResourceGroupName "rg-easypim-cicd-test" `
#   -Location "francecentral"
```

> **📝 Note:** The hybrid deployment script combines Azure CLI (for Entra ID resources) and Bicep (for Azure resources) to provide a reliable, production-ready deployment. The script will automatically create the resource group if it doesn't exist.

**Option B: Azure CLI with Bicep**
```bash
# Create resource group
az group create --name "rg-easypim-cicd-test" --location "East US"

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-easypim-cicd-test" \
  --template-file scripts/deploy-azure-resources.bicep \
  --parameters @scripts/deploy-azure-resources.parameters.json \
  --parameters githubRepository="kayasax/EasyPIM-CICD-test"
```

### 1.3 Post-Deployment Configuration

After successful deployment, you'll receive output similar to:

```
🔑 GitHub Repository Secrets:
  AZURE_CLIENT_ID: 12345678-1234-1234-1234-123456789012
  AZURE_TENANT_ID: 87654321-4321-4321-4321-210987654321
  AZURE_SUBSCRIPTION_ID: 11111111-2222-3333-4444-555555555555

🔧 GitHub Repository Variables:
  AZURE_KEYVAULT_NAME: easypim-cicd-test-kv-abc123
  AZURE_RESOURCE_GROUP: rg-easypim-cicd-test
```

**Save these values** - you'll need them for GitHub configuration.

---

## Step 2: Configure GitHub Repository

### 2.1 Grant Graph API Admin Consent

1. **Go to Azure Portal** → Azure Active Directory → App registrations
2. **Find your application:** `easypim-cicd-test-sp`
3. **Navigate to:** API permissions
4. **Click:** "Grant admin consent for [Your Tenant]"
5. **Verify permissions granted:**
   - ✅ User.Read.All
   - ✅ RoleManagement.ReadWrite.Directory
   - ✅ PrivilegedAccess.ReadWrite.AzureResources
   - ✅ RoleManagementPolicy.ReadWrite.Directory
   - ✅ RoleManagementPolicy.ReadWrite.AzureADGroup
   - ✅ PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup
   - ✅ PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup
   - ✅ PrivilegedAccess.ReadWrite.AzureADGroup
   - ✅ Directory.Read.All
   - ✅ Group.Read.All

### 2.2 Configure GitHub Secrets

**Option A: Automated Setup (Recommended) 🚀**
```powershell
# Navigate to scripts directory
cd scripts

# Run the automated configuration script
.\configure-github-cicd.ps1 -GitHubRepository "kayasax/EasyPIM-CICD-test"

# Or with force overwrite if secrets/variables already exist
.\configure-github-cicd.ps1 -GitHubRepository "kayasax/EasyPIM-CICD-test" -Force
```

**Option B: Manual Setup**

1. **Go to GitHub repository:** `ex: https://github.com/kayasax/EasyPIM-CICD-test`
2. **Navigate to:** Settings → Secrets and variables → Actions
3. **Add Repository Secrets:**
   ```
   AZURE_CLIENT_ID: [from deployment output]
   AZURE_TENANT_ID: [from deployment output]
   AZURE_SUBSCRIPTION_ID: [from deployment output]
   ```

### 2.3 Configure GitHub Variables

**Automated Setup:** If you used the automated script above, this step is already completed.

**Manual Setup:**

1. **In the same location:** Settings → Secrets and variables → Actions → Variables tab
2. **Add Repository Variables:**
   ```
   AZURE_KEYVAULT_NAME: [from deployment output]
   AZURE_KEYVAULT_SECRET_NAME: easypim-config-json
   AZURE_RESOURCE_GROUP: [from deployment output]
   AZURE_KEY_VAULT_URI: [from deployment output]
   ```

> **💡 Tip:** The automated script `configure-github-cicd.ps1` handles both secrets and variables automatically by reading your Azure deployment outputs. It requires GitHub CLI (`gh`) to be installed and authenticated.

---

## Step 3: Initial EasyPIM Configuration

### 3.1 Identify Protected Users

**Critical:** Before any PIM operations, identify your break-glass and critical accounts and note their principal IDs

### 3.2 Create Initial Configuration

Update the Key Vault secret with your protected users:

```powershell
# Connect to Azure
Connect-AzAccount

# Get the Key Vault name from deployment
$kvName = "easypim-cicd-test-kv-abc123"  # Replace with your actual KV name

# Create minimal configuration with protected users
$config = @{
    "ProtectedUsers" = @(
        "00000000-0000-0000-0000-000000000001",  # Replace with actual break-glass account Object ID
        "00000000-0000-0000-0000-000000000002"   # Replace with actual admin group Object ID
    )
    "PolicyTemplates" = @{
        "Standard" = @{
            "ActivationDuration" = "PT8H"
            "ActivationRequirement" = "MultiFactorAuthentication,Justification"
            "ApprovalRequired" = $false
        }
        "HighSecurity" = @{
            "ActivationDuration" = "PT2H"
            "ActivationRequirement" = "MultiFactorAuthentication,Justification"
            "ApprovalRequired" = $true
            "Approvers" = @(
                @{ "id" = "00000000-0000-0000-0000-000000000002"; "description" = "PIM Approvers" }
            )
        }
    }
    # Using harmless roles for testing - replace with your actual roles in production
    "EntraRoles" = @{
        "Policies" = @{
            "Printer Technician" = @{ "Template" = "Standard" }
        }
    }
    "Assignments" = @{
        "EntraRoles" = @()
        "AzureRoles" = @()
    }
}

# Convert to JSON and store in Key Vault
$configJson = $config | ConvertTo-Json -Depth 10
Set-AzKeyVaultSecret -VaultName $kvName -Name "easypim-config-json" -SecretValue (ConvertTo-SecureString $configJson -AsPlainText -Force)

Write-Host "✅ Initial EasyPIM configuration stored in Key Vault" -ForegroundColor Green
```

### 3.3 Upload Existing Configuration (Alternative)

**If you already have an existing EasyPIM configuration JSON file:**

```powershell
# Connect to Azure
Connect-AzAccount

# Get the Key Vault name from deployment
$kvName = "easypim-cicd-test-kv-abc123"  # Replace with your actual KV name

# Option A: Upload from local file
$configPath = "C:\path\to\your\pim-config.json"  # Update path to your JSON file
$configJson = Get-Content -Path $configPath -Raw

# Option B: Upload from the provided sample config
$configPath = ".\configs\pim-config.json"  # Use the sample config from repository
$configJson = Get-Content -Path $configPath -Raw

# Validate JSON format
try {
    $config = $configJson | ConvertFrom-Json
    Write-Host "✅ JSON configuration is valid" -ForegroundColor Green
} catch {
    Write-Error "❌ Invalid JSON format: $($_.Exception.Message)"
    return
}

# Store in Key Vault
Set-AzKeyVaultSecret -VaultName $kvName -Name "easypim-config-json" -SecretValue (ConvertTo-SecureString $configJson -AsPlainText -Force)

Write-Host "✅ Existing EasyPIM configuration uploaded to Key Vault" -ForegroundColor Green
Write-Host "📄 Configuration file: $configPath" -ForegroundColor Cyan
```

**Important Notes:**
- ⚠️ **Review your configuration** before uploading to ensure it matches your testing environment
- 🔒 **Update protected users** in the JSON file with your actual break-glass account Object IDs
- 🎯 **Use safe roles** for testing (like "Printer Technician") before moving to production roles
- 📝 **Validate JSON syntax** using the validation check above

---

## Step 4: Test Authentication Workflow

### 4.1 Commit and Push Changes

Before running the GitHub Actions workflow, you need to commit and push your local changes:

```powershell
# Check current git status
git status

# Add all modified files
git add .

# Commit changes
git commit -m "Configure EasyPIM: Add Azure resources, workflows, and configuration files"

# Push to remote repository
git push origin main
```

> **💡 Note:** Ensure you're on the correct branch and have proper git remote configured before pushing.

### 4.2 Run Authentication Test

1. **Go to GitHub repository:** Actions tab
2. **Select workflow:** "Phase 1: Authentication Test - EasyPIM CI/CD"
3. **Click:** "Run workflow" → "Run workflow" (use default parameters)
4. **Monitor execution** and verify the 5 authentication tests:
   - ✅ EasyPIM module installation and import
   - ✅ Azure OIDC authentication
   - ✅ Key Vault access (requires AZURE_KEY_VAULT_NAME secret)
   - ✅ Microsoft Graph connectivity
   - ✅ EasyPIM function availability

### 4.2 Verify Output

Check the workflow logs for successful authentication tests:

```
🔐 Phase 1: Authentication Test - Per Step 4.2 Guidelines
============================================================

🚀 Test 1: Installing EasyPIM modules from PowerShell Gallery...
✅ EasyPIM modules installed successfully

📦 Test 2: Importing EasyPIM.Orchestrator module...
✅ EasyPIM modules imported successfully

🔑 Test 3: Verifying Key Vault access...
   Key Vault: kv-easypim-XXXX
   Secret Name: easypim-config-json
✅ Key Vault access confirmed
✅ Configuration retrieved successfully

🌐 Test 4: Testing Microsoft Graph connectivity...
✅ Microsoft Graph connectivity verified
   Tenant: [Your Tenant Name]

🔧 Test 5: Verifying EasyPIM functions are available...
✅ EasyPIM.Orchestrator commands available: 4
   ✅ Invoke-EasyPIMOrchestrator available
   ✅ Test-PIMPolicyDrift available

🎉 Phase 1 Authentication Test Complete!
```

> **📝 Note:** If Key Vault test shows a warning, configure the `AZURE_KEY_VAULT_NAME` secret in GitHub repository settings with your Key Vault name (e.g., `kv-easypim-8368`).

---

## Step 5: Progressive EasyPIM Validation

### 5.1 Local Testing (Recommended First)

Before running in GitHub Actions, test the configuration locally:

```powershell
# Install EasyPIM modules
Install-Module -Name EasyPIM -Force -Scope CurrentUser
Install-Module -Name EasyPIM.Orchestrator -Force -Scope CurrentUser
Import-Module EasyPIM.Orchestrator -Force

# Connect to required services
Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory"
Connect-AzAccount
Set-AzContext -SubscriptionId "[your-subscription-id]"

# Test with Key Vault configuration (WhatIf mode)
Invoke-EasyPIMOrchestrator `
  -KeyVaultName "[your-keyvault-name]" `
  -SecretName "easypim-config-json" `
  -TenantId "[your-tenant-id]" `
  -SubscriptionId "[your-subscription-id]" `
  -WhatIf `
  -SkipAssignments
```

### 5.2 Progressive Configuration Steps

Follow the official EasyPIM guide progression:

**Step 5.2.1: Minimal Config (Protected Users Only)**
- ✅ Already completed in Step 3.2
- Verify WhatIf shows protected users are recognized

**Step 5.2.2: Add Entra Role Policy (Template)**
```json
{
  "ProtectedUsers": ["..."],
  "PolicyTemplates": {
    "Standard": {
      "ActivationDuration": "PT8H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": false
    }
  },
  "EntraRoles": {
    "Policies": {
      "Printer Technician": { "Template": "Standard" }
    }
  }
}
```

**Step 5.2.3: Add Entra Role Assignments**
```json
{
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "Printer Technician",
        "assignments": [
          {
            "principalId": "[test-user-object-id]",
            "assignmentType": "Eligible",
            "justification": "Testing EasyPIM CI/CD"
          }
        ]
      }
    ]
  }
}
```

**Step 5.2.4: Add Azure Role Policies and Assignments**
```json
{
  "AzureRoles": {
    "Policies": {
      "Reader": {
        "Scope": "/subscriptions/[subscription-id]",
        "Template": "Standard"
      }
    }
  },
  "Assignments": {
    "AzureRoles": [
      {
        "roleName": "Reader",
        "scope": "/subscriptions/[subscription-id]",
        "assignments": [
          {
            "principalId": "[test-user-object-id]",
            "assignmentType": "Eligible",
            "justification": "Testing Azure PIM"
          }
        ]
      }
    ]
  }
}
```

### 5.3 Update Configuration in Key Vault

After each step, update the Key Vault secret:

```powershell
# Update configuration
$newConfig = @{ ... }  # Your updated configuration
$configJson = $newConfig | ConvertTo-Json -Depth 10
Set-AzKeyVaultSecret -VaultName $kvName -Name "easypim-config-json" -SecretValue (ConvertTo-SecureString $configJson -AsPlainText -Force)
```

### 5.4 Test Each Step

For each configuration update:

1. **Test locally first:**
   ```powershell
   Invoke-EasyPIMOrchestrator -KeyVaultName $kvName -SecretName "easypim-config-json" -TenantId $tenantId -SubscriptionId $subscriptionId -WhatIf
   ```

2. **Run GitHub Actions workflow** (Phase 2: Read-Only Operations)

3. **Apply changes when satisfied:**
   ```powershell
   # Remove -WhatIf to apply
   Invoke-EasyPIMOrchestrator -KeyVaultName $kvName -SecretName "easypim-config-json" -TenantId $tenantId -SubscriptionId $subscriptionId
   ```

---

## Step 6: Policy Drift Detection

### 6.1 Configure Drift Detection

Add drift detection to your workflow:

```yaml
# In .github/workflows/02-pim-read-test.yml
- name: 'Test Policy Drift'
  shell: pwsh
  run: |
    Test-PIMPolicyDrift `
      -KeyVaultName '${{ vars.AZURE_KEYVAULT_NAME }}' `
      -SecretName 'easypim-config-json' `
      -TenantId '${{ secrets.AZURE_TENANT_ID }}' `
      -SubscriptionId '${{ secrets.AZURE_SUBSCRIPTION_ID }}' `
      -OutputPath './drift-report'
```

> **🚀 Future Enhancement Note:** The next version of EasyPIM will add native Azure Key Vault support for `Test-PIMPolicyDrift`, allowing direct parameter usage:
> ```powershell
> Test-PIMPolicyDrift -KeyVaultName "your-keyvault" -SecretName "easypim-config-json" -TenantId "..." -SubscriptionId "..."
> ```
> This will simplify the workflow by eliminating the need to download configurations to temporary files.

### 6.2 Monitor Drift Reports

Drift detection will:
- ✅ Compare live policies vs. configuration
- ⚠️ Highlight any out-of-band changes
- 📊 Generate reports for audit purposes

---

## Step 7: Full CI/CD Integration

### 7.1 Production-Ready Workflow

Create comprehensive workflow with:

```yaml
# .github/workflows/04-full-integration.yml
name: 'EasyPIM Full Integration'

on:
  workflow_dispatch:
    inputs:
      apply:
        description: 'Apply changes (remove -WhatIf)'
        required: false
        default: 'false'
        type: boolean
      mode:
        description: 'Mode: delta (safe) or initial (destructive)'
        required: false
        default: 'delta'
        type: choice
        options:
          - delta
          - initial

  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6 AM UTC

env:
  TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  KEYVAULT_NAME: ${{ vars.AZURE_KEYVAULT_NAME }}

permissions:
  id-token: write
  contents: read

jobs:
  easypim-orchestrator:
    runs-on: ubuntu-latest
    environment: production  # Require manual approval for production

    steps:
    - name: 'Checkout'
      uses: actions/checkout@v4

    - name: 'Azure OIDC Login'
      uses: azure/login@v2
      with:
        client-id: ${{ env.CLIENT_ID }}
        tenant-id: ${{ env.TENANT_ID }}
        subscription-id: ${{ env.SUBSCRIPTION_ID }}

    - name: 'Install EasyPIM Modules'
      shell: pwsh
      run: |
        Install-Module -Name EasyPIM -Force -Scope CurrentUser
        Install-Module -Name EasyPIM.Orchestrator -Force -Scope CurrentUser
        Import-Module EasyPIM.Orchestrator -Force

    - name: 'Policy Drift Detection'
      shell: pwsh
      run: |
        Test-PIMPolicyDrift `
          -KeyVaultName '${{ env.KEYVAULT_NAME }}' `
          -SecretName 'easypim-config-json' `
          -TenantId '${{ env.TENANT_ID }}' `
          -SubscriptionId '${{ env.SUBSCRIPTION_ID }}' `
          -OutputPath './drift-report'

    - name: 'EasyPIM Orchestrator Execution'
      shell: pwsh
      run: |
        $apply = '${{ github.event.inputs.apply }}' -eq 'true'
        $mode = '${{ github.event.inputs.mode }}'
        if (-not $mode) { $mode = 'delta' }

        $params = @{
          KeyVaultName = '${{ env.KEYVAULT_NAME }}'
          SecretName = 'easypim-config-json'
          TenantId = '${{ env.TENANT_ID }}'
          SubscriptionId = '${{ env.SUBSCRIPTION_ID }}'
          Mode = $mode
        }

        if (-not $apply) {
          $params.WhatIf = $true
          Write-Host "🔍 Running in WhatIf mode (preview only)" -ForegroundColor Yellow
        } else {
          Write-Host "⚡ Applying changes" -ForegroundColor Green
        }

        if ($mode -eq 'initial') {
          Write-Host "⚠️ DESTRUCTIVE MODE: Will remove assignments not in config (except ProtectedUsers)" -ForegroundColor Red
        }

        Invoke-EasyPIMOrchestrator @params

    - name: 'Upload Artifacts'
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: easypim-reports
        path: |
          ./drift-report/*
          ./LOGS/*
```

### 7.2 Environment Protection

Configure GitHub environment protection:

1. **Go to:** Repository Settings → Environments
2. **Create environment:** `production`
3. **Configure protection rules:**
   - ✅ Required reviewers (1-2 people)
   - ✅ Wait timer: 5 minutes
   - ✅ Restrict to protected branches only

---

## Troubleshooting

### Common Issues

**Issue:** "Cannot find Bicep. Please add Bicep to your PATH"
```
Error: Cannot retrieve the dynamic parameters for the cmdlet. Cannot find Bicep.
Solution: Install Azure Bicep CLI using one of the methods in Prerequisites section.
After installation, restart PowerShell and verify with: bicep --version
```

**Issue:** Graph API permissions denied
```
Solution: Ensure admin consent granted for all required permissions:
- User.Read.All
- RoleManagement.ReadWrite.Directory
- PrivilegedAccess.ReadWrite.AzureResources
```

**Issue:** Key Vault access denied
```
Solution: Verify service principal has "Key Vault Secrets User" role on Key Vault
```

**Issue:** Federated credential authentication fails
```
Solution: Check federated credential configuration:
- Issuer: https://token.actions.githubusercontent.com
- Subject: repo:kayasax/EasyPIM-CICD-test:ref:refs/heads/main
- Audiences: api://AzureADTokenExchange
```

**Issue:** EasyPIM module installation fails
```
Solution: Update PowerShell execution policy and install modules explicitly:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module -Name EasyPIM, EasyPIM.Orchestrator -Force -Scope CurrentUser
```

### Validation Commands

```powershell
# Test Azure authentication
Get-AzContext

# Test Key Vault access
Get-AzKeyVaultSecret -VaultName "[keyvault-name]" -Name "easypim-config-json"

# Test Microsoft Graph connectivity
Connect-MgGraph -Scopes "User.Read.All"
Get-MgUser -Top 1

# Validate EasyPIM configuration
$config = Get-AzKeyVaultSecret -VaultName "[keyvault-name]" -Name "easypim-config-json" -AsPlainText
$config | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

---

## Security Best Practices

### 🔐 Authentication Security
- ✅ **Use OIDC federation** - No client secrets in repository
- ✅ **Limit federated credential scope** - Specific to repository and branch
- ✅ **Regular credential rotation** - OIDC tokens rotate automatically
- ✅ **Audit authentication events** - Monitor Azure AD sign-in logs

### 🛡️ Access Control
- ✅ **Least privilege service principal** - Only required permissions granted
- ✅ **Environment protection** - Manual approval for production changes
- ✅ **Protected users list** - Break-glass accounts never removed
- ✅ **Branch protection** - Changes require PR review

### 📊 Monitoring & Auditing
- ✅ **Drift detection** - Regular policy compliance checks
- ✅ **Change logging** - All operations logged and archived
- ✅ **Artifact retention** - Reports stored for audit purposes
- ✅ **Alert on failures** - Notification for failed workflows

### 🚨 Emergency Procedures
- ✅ **Manual override capability** - Local execution possible
- ✅ **Rollback procedures** - Previous configurations stored
- ✅ **Break-glass access** - Protected accounts for emergency access
- ✅ **Incident response** - Clear escalation procedures

---

## Conclusion

This guide provides a complete, production-ready EasyPIM CI/CD testing framework that:

- 🏗️ **Automates infrastructure deployment** with Bicep templates
- 🔐 **Implements security best practices** with OIDC and Key Vault
- ⚡ **Enables progressive validation** following official EasyPIM patterns
- 📊 **Provides comprehensive monitoring** with drift detection and auditing
- 🛡️ **Includes safety mechanisms** with protected users and approval workflows

The framework is now ready for testing real PIM scenarios while maintaining security and providing a path to production deployment.

For additional support, refer to:
- [Official EasyPIM Documentation](https://github.com/kayasax/EasyPIM/wiki)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure OIDC Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
