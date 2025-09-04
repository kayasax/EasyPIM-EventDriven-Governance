
# 🚀 EasyPIM CI/CD Template - Complete Integration Guide

**Transform your Privileged Identity Management with automated CI/CD workflows**

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          EasyPIM CI/CD Architecture                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  GitHub Repository                 Azure Infrastructure                     │
│  ┌─────────────────┐              ┌─────────────────────────────────────┐   │
│  │   🔧 Workflows   │    OIDC      │  🔐 Service Principal              │   │
│  │  ┌─────────────┐ │◄────────────►│  • Federated Identity Credentials  │   │
│  │  │ Flow 1: Auth│ │              │  • Graph API Permissions           │   │
│  │  │ Flow 2: Orch│ │              └─────────────────────────────────────┘   │
│  │  │ Flow 3: Drift│ │                           │                          │
│  │  └─────────────┘ │                           ▼                          │
│  └─────────────────┘              ┌─────────────────────────────────────┐   │
│                                    │  🗝️ Azure Key Vault                │   │
│  📋 Configuration                  │  • PIM Policies Configuration      │   │
│  ┌─────────────────┐              │  • Role Assignments                │   │
│  │ parameters.json │──────────────►│  • Secure Secret Storage           │   │
│  │ • Resource Names│              └─────────────────────────────────────┘   │
│  │ • GitHub Repo   │                           │                          │
│  │ • Environment   │                           ▼                          │
│  └─────────────────┘              ┌─────────────────────────────────────┐   │
│                                    │  🎯 Target Environment             │   │
│                                    │  • Entra ID Roles                  │   │
│                                    │  • Azure Subscriptions             │   │
│                                    │  • Group Memberships               │   │
│                                    └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

🔄 Workflow Execution Flow:
1️⃣ Authentication Test → Validates OIDC and connectivity
2️⃣ Orchestrator → Applies PIM configuration (Entra + Azure + Groups)
3️⃣ Drift Detection → Monitors and reports compliance status
```

---

## 📋 Table of Contents

1. [🎯 What This Template Provides](#-what-this-template-provides)
2. [🔧 Prerequisites](#-prerequisites)
3. [📁 Understanding the Parameters](#-understanding-the-parameters)
4. [🚀 Deployment Process](#-deployment-process)
5. [📝 Repository Configuration](#-repository-configuration)
6. [🧪 Testing Your Setup](#-testing-your-setup)
7. [🔍 Validation & Monitoring](#-validation--monitoring)
8. [🛡️ Security & Best Practices](#️-security--best-practices)

---

## 🎯 What This Template Provides

This repository serves as a **production-ready template** for implementing EasyPIM CI/CD automation. You get:

### ✨ **Ready-to-Use Components**
- 🏗️ **Complete Azure infrastructure** deployed via Bicep
- 🔐 **Secure OIDC authentication** (no secrets in code)
- 📋 **Three specialized workflows** for comprehensive PIM management
- 🔑 **Azure Key Vault integration** for configuration storage
- 📊 **Automated drift detection** and compliance reporting

### 🌟 **Key Benefits**
- **Zero-configuration OIDC**: All ARM API authentication works out-of-the-box
- **Infrastructure as Code**: Reproducible deployments across environments
- **Automated Compliance**: Continuous monitoring and drift detection
- **Audit Trail**: Complete logging and artifact collection
- **Enterprise Ready**: Security best practices built-in



---

## 🔧 Prerequisites

### 📋 **What You Need**

| Requirement | Details |
|-------------|---------|
| **Azure Subscription** | • Contributor + User Access Administrator roles<br>• Permission to create Azure AD apps<br>• Ability to grant admin consent |
| **GitHub Account** | • Repository admin access<br>• Ability to configure secrets/variables |
| **Local Development** | • PowerShell 7.0+<br>• Azure CLI + Bicep<br>• Git client |

### 🛠️ **Install Required Tools**

**Step 1: PowerShell 7+**
```powershell
# Check current version
$PSVersionTable.PSVersion

# If needed, install from: https://github.com/PowerShell/PowerShell/releases
```

**Step 2: Azure CLI + Bicep**
```powershell
# Install Azure CLI
# Download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# Verify installation
az --version

# Install/update Bicep
az bicep install
az bicep upgrade

# Verify Bicep
bicep --version
```

**Step 3: PowerShell Modules**
```powershell
# Install required Azure modules
Install-Module -Name Az.Accounts, Az.Resources, Az.KeyVault -Force -AllowClobber

# Verify installation
Get-Module -ListAvailable Az.Accounts, Az.Resources, Az.KeyVault
```

**Step 4: GitHub CLI (Optional but recommended)**
```powershell
# Install GitHub CLI
winget install --id GitHub.cli

# Authenticate
gh auth login

# Verify
gh auth status
```

---

## 📁 Understanding the Parameters

### 🎛️ **Core Configuration File: `scripts/deploy-azure-resources.parameters.json`**

This file controls your entire deployment. Let's break it down:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourcePrefix": {
      "value": "easypim-cicd"
    },
    "environment": {
      "value": "test"
    },
    "githubRepository": {
      "value": "kayasax/EasyPIM-CICD-test"
    },
    "location": {
      "value": "francecentral"
    },
    "servicePrincipalName": {
      "value": "easypim-cicd-test-sp"
    },
    "keyVaultAdministrators": {
      "value": []
    },
    "tags": {
      "value": {
        "Project": "EasyPIM-CICD-Testing",
        "Environment": "test",
        "Purpose": "CI-CD-Automation"
      }
    }
  }
}
```

### 🔧 **Parameter Explanation**

| Parameter | Purpose | Example | Notes |
|-----------|---------|---------|-------|
| `resourcePrefix` | Names your Azure resources | `"mycompany-pim"` | Keep it short, alphanumeric only |
| `environment` | Environment identifier | `"prod"`, `"dev"`, `"test"` | Used in resource naming |
| `githubRepository` | Your GitHub repo | `"myorg/my-easypim-repo"` | **CRITICAL**: Must match your actual repo |
| `location` | Azure region | `"eastus"`, `"westeurope"` | Choose closest to your users |
| `servicePrincipalName` | SP display name | `"MyCompany-EasyPIM-SP"` | Descriptive name for Azure AD |
| `keyVaultAdministrators` | User/Group IDs for KV access | `["user-guid", "group-guid"]` | Optional, auto-detected if empty |

### 📝 **Customization Checklist**

Before deployment, **MUST CHANGE**:
- [ ] `githubRepository` → Your repository path
- [ ] `resourcePrefix` → Your company/project identifier
- [ ] `location` → Your preferred Azure region

**SHOULD CHANGE**:
- [ ] `environment` → Match your deployment stage
- [ ] `servicePrincipalName` → Descriptive name
- [ ] `tags` → Your organization standards

---

## 🚀 Deployment Process

### 🎬 **Step-by-Step Deployment**

**Step 1: Fork and Clone This Repository**
```bash
# Fork the repository on GitHub first, then:
git clone https://github.com/YOUR-USERNAME/EasyPIM-CICD-test.git
cd EasyPIM-CICD-test
```

**Step 2: Customize Your Parameters**
```powershell
# Edit the parameters file
code scripts/deploy-azure-resources.parameters.json

# Update these REQUIRED values:
# - githubRepository: "YOUR-USERNAME/YOUR-REPO-NAME"
# - resourcePrefix: "your-company-pim"
# - location: "your-preferred-region"
```

**Step 3: Authenticate to Azure**
```powershell
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your-Subscription-Name-or-ID"

# Verify context
az account show
```

**Step 4: Run the Deployment Script**
```powershell
# Navigate to repository root
cd EasyPIM-CICD-test

# Run deployment with your parameters
./scripts/deploy-azure-resources.ps1 `
    -ResourceGroupName "rg-easypim-prod" `
    -GitHubRepository "mycompany/easypim-automation" `
    -Location "eastus" `
    -Environment "prod" `
    -Force
```

### 📊 **What the Deployment Creates**

The script deploys these Azure resources:

```
📦 Resource Group: rg-easypim-prod
├── 🔐 Service Principal: mycompany-pim-prod-sp
│   ├── Federated Identity Credentials (for GitHub OIDC)
│   └── Required Graph API permissions
├── 🗝️ Key Vault: mycompany-pim-prod-kv-abc123
│   ├── RBAC-enabled access
│   ├── Public network access (for GitHub Actions)
│   └── Sample PIM configuration stored as secret
└── 🏷️ Tags: Project, Environment, Purpose, etc.
```

### 🎯 **Deployment Outputs**

After successful deployment, you'll see:

```
✅ Deployment completed successfully!

🔑 GitHub Repository Secrets (add these to your repository):
  AZURE_TENANT_ID: 12345678-1234-1234-1234-123456789012
  AZURE_CLIENT_ID: 87654321-4321-4321-4321-210987654321
  AZURE_SUBSCRIPTION_ID: 11111111-2222-3333-4444-555555555555

🔧 GitHub Repository Variables (add these to your repository):
  AZURE_KEYVAULT_NAME: mycompany-pim-prod-kv-abc123
  AZURE_KEYVAULT_SECRET_NAME: easypim-config-json

⚠️ IMPORTANT: Grant admin consent for the Azure AD application!
1. Go to Azure Portal → Azure AD → App registrations
2. Find: mycompany-pim-prod-sp
3. Go to API permissions → Grant admin consent
```

**💾 Save these values - you'll need them for GitHub configuration!**

---

## 📝 Repository Configuration

### 🔐 **Configure GitHub Secrets and Variables**

**Step 1: Add Repository Secrets**
1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"** for each:

| Secret Name | Value | Source |
|-------------|-------|---------|
| `AZURE_TENANT_ID` | Your Azure tenant ID | Deployment output |
| `AZURE_CLIENT_ID` | Service principal app ID | Deployment output |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID | Deployment output |

**Step 2: Add Repository Variables**
1. In the same location, click **"Variables"** tab
2. Click **"New repository variable"** for each:

| Variable Name | Value | Source |
|---------------|-------|---------|
| `AZURE_KEYVAULT_NAME` | Key vault name | Deployment output |
| `AZURE_KEYVAULT_SECRET_NAME` | `easypim-config-json` | Default secret name |

### ✅ **Grant Azure AD Admin Consent**

**CRITICAL STEP - Don't skip this!**

1. Open **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Search for your service principal (e.g., "mycompany-pim-prod-sp")
3. Click on the application
4. Go to **API permissions**
5. Click **"Grant admin consent for [Your Organization]"**
6. Confirm by clicking **"Yes"**

You should see green checkmarks next to all permissions.

### 📤 **Commit and Push Your Changes**

```bash
# Add your parameter file changes
git add scripts/deploy-azure-resources.parameters.json

# Commit with descriptive message
git commit -m "Configure deployment parameters for production environment"

# Push to your repository
git push origin main
```

---

## 🧪 Testing Your Setup

### 🔄 **Three-Phase Validation Process**

Your repository includes three specialized workflows designed for comprehensive testing:

#### **Phase 1: Authentication Test** 🔐
- **File**: `.github/workflows/test-ultimate-telemetry.yml`
- **Purpose**: Validates OIDC authentication and Azure connectivity
- **Duration**: ~2-3 minutes
- **Tests**: OIDC tokens, Azure CLI auth, Graph API access, telemetry

#### **Phase 2: Orchestrator Execution** ⚙️
- **File**: `.github/workflows/02-orchestrator-test.yml`
- **Purpose**: Runs EasyPIM orchestrator with your configuration
- **Duration**: ~5-10 minutes
- **Features**: WhatIf mode, policy management, drift detection

#### **Phase 3: Drift Detection** 🔍
- **File**: `.github/workflows/03-policy-drift-check.yml`
- **Purpose**: Monitors configuration compliance and drift
- **Duration**: ~3-5 minutes
- **Output**: Compliance reports, drift analysis

### 🎯 **Running Phase 1: Authentication Test**

**Step 1: Navigate to Actions**
1. Go to your GitHub repository
2. Click the **"Actions"** tab
3. Look for **"Test Ultimate Telemetry"** workflow

**Step 2: Execute the Test**
1. Click on **"Test Ultimate Telemetry"**
2. Click **"Run workflow"** (top right)
3. Leave default settings
4. Click **"Run workflow"** button

**Step 3: Monitor Execution**
- Watch the workflow progress in real-time
- Typical runtime: 2-3 minutes
- Look for green checkmarks on all steps

**Step 4: Validate Results**
✅ **Success indicators:**
- OIDC authentication successful
- Azure CLI login working
- Microsoft Graph connection established
- Telemetry events sent successfully

❌ **If it fails:**
- Check that all secrets/variables are set correctly
- Verify admin consent was granted
- Review workflow logs for specific errors

### ⚙️ **Running Phase 2: Orchestrator Test**

**Step 1: Access the Workflow**
1. In **Actions** tab, find **"Phase 2: EasyPIM Orchestrator Test"**
2. Click on the workflow name

**Step 2: Configure Parameters**
1. Click **"Run workflow"**
2. **Recommended first-run settings:**
   - **WhatIf**: `true` (preview mode - no changes made)
   - **Mode**: `delta` (incremental updates)
   - **Skip Policies**: `false`
   - **Skip Assignments**: `false`
   - **Force**: `false`
   - **Verbose**: `true` (detailed logging)

**Step 3: Execute and Monitor**
1. Click **"Run workflow"**
2. Monitor the execution progress
3. Typical runtime: 5-10 minutes

**Step 4: Review Results**
✅ **Success indicators:**
- Configuration processed successfully
- No authentication errors
- Policy operations completed
- Summary shows applied/detected changes

### 🔍 **Running Phase 3: Drift Detection**

**Step 1: Execute Drift Check**
1. Find **"Phase 3: Policy Drift Check"** workflow
2. Click **"Run workflow"**
3. Use default parameters
4. Execute the workflow

**Step 2: Analyze Results**
- Review the workflow summary
- Download artifacts for detailed reports
- Check for any compliance issues

### 📋 **Workflow Summary Interpretation**

Each workflow provides a detailed summary:

```
🧪 EasyPIM CI/CD Test Results - Phase 2

✅ EasyPIM Orchestrator: SUCCESS
- Configuration processed successfully
- ARM API authentication working with updated EasyPIM
- No manual hotfix required

📊 Execution Summary
- WhatIf Mode: true
- Mode: delta
- Policies Processed: 5
- Assignments Processed: 12
- Drift Detected: 0 items

🔗 Next Steps
1. ✅ No action required - configuration is compliant
2. 📅 Maintain scheduled checks
```

---

## 🔍 Validation & Monitoring

### 📊 **Understanding Workflow Outputs**

Each workflow generates comprehensive artifacts and summaries:

#### **Artifacts Available for Download**
- **Execution Logs**: Complete PowerShell transcripts
- **Configuration Reports**: JSON summaries of applied changes
- **Drift Analysis**: Detailed compliance reports
- **Error Logs**: Troubleshooting information (if needed)

#### **Accessing Artifacts**
1. Click on any completed workflow run
2. Scroll to **"Artifacts"** section at the bottom
3. Download **"easypim-logs-[run-number]"**
4. Extract ZIP file to review contents

### 🎯 **Production Deployment Process**

Once validation is complete, follow this process for production deployment:

**Step 1: Switch to Apply Mode**
```
Orchestrator Parameters:
- WhatIf: false          ← Actually apply changes
- Mode: delta            ← Incremental updates
- Force: true            ← Skip confirmations
- Verbose: true          ← Detailed logging
```

**Step 2: Monitor First Production Run**
- Watch execution closely
- Review all logs and outputs
- Validate changes in Azure portal
- Confirm expected behavior

**Step 3: Establish Regular Monitoring**
- Schedule weekly drift detection runs
- Set up alerts for failed workflows
- Review monthly compliance reports
- Update configurations as needed

### 📈 **Ongoing Operations**

#### **Regular Tasks**
- **Weekly**: Run drift detection workflow
- **Monthly**: Review compliance reports and logs
- **Quarterly**: Update EasyPIM modules and configurations
- **As-needed**: Apply new policy requirements

#### **Monitoring Best Practices**
- Set up GitHub Actions notifications
- Monitor Key Vault access logs
- Review Azure AD sign-in logs for service principal
- Track workflow execution history and trends

---

## 🛡️ Security & Best Practices

### 🔐 **Security Considerations**

#### **Key Vault Access**
⚠️ **Important**: The deployment enables public network access to support GitHub Actions runners.

**For Production Environments:**
```powershell
# Option 1: Restrict to specific IP ranges (if available)
az keyvault network-rule add --name $keyVaultName --ip-address "GITHUB_RUNNER_IPS"
az keyvault update --name $keyVaultName --public-network-access Disabled

# Option 2: Use Private Endpoints (enterprise recommended)
# Requires additional VNET configuration

# Option 3: Monitor access with logging
az monitor diagnostic-settings create \
  --name "KeyVault-Audit" \
  --resource $keyVaultResourceId \
  --logs '[{"category":"AuditEvent","enabled":true}]'
```

#### **GitHub Security**
- Use environment protection rules for production
- Implement branch protection on main branch
- Regular review of repository access permissions
- Enable dependency scanning and security alerts

#### **Azure Security**
- Follow principle of least privilege for service principal
- Regular audit of Azure AD application permissions
- Monitor sign-in logs for unusual activity
- Implement Conditional Access policies if available

### 🎯 **Best Practices for Production**

#### **Environment Management**
- Use separate resource groups for dev/test/prod
- Implement consistent naming conventions
- Tag all resources appropriately
- Maintain separate GitHub repositories or branches

#### **Configuration Management**
- Store PIM configurations in Key Vault
- Version control all infrastructure code
- Document configuration changes
- Implement approval processes for production changes

#### **Monitoring and Alerting**
- Set up workflow failure notifications
- Monitor drift detection results
- Track policy compliance metrics
- Implement alerting for security events

### 📚 **Additional Resources**

- [Official EasyPIM Documentation](https://github.com/kayasax/EasyPIM/wiki)
- [Azure AD Privileged Identity Management](https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)

---

## 🎉 Congratulations!

You now have a **production-ready EasyPIM CI/CD pipeline** that provides:

✅ **Automated PIM Management** - Policies and assignments managed as code
✅ **Continuous Compliance** - Automated drift detection and reporting
✅ **Secure Authentication** - OIDC-based access with no stored secrets
✅ **Complete Audit Trail** - Full logging and change tracking
✅ **Enterprise Security** - Best practices built-in from day one

### 🚀 **What's Next?**

1. **Customize your PIM configuration** in Azure Key Vault
2. **Set up scheduled workflows** for regular compliance checks
3. **Integrate with your existing CI/CD pipelines**
4. **Train your team** on the new automated processes
5. **Expand to additional environments** using the same template

**Happy automating!** 🤖✨
