# 🔵 EasyPIM Event-Driven Governance - Azure DevOps Guide

**Complete setup and integration guide for Azure DevOps pipelines**

> 📋 **New to EasyPIM?** Start with the [Platform Setup Guide](Platform-Setup-Guide.md) to choose your CI/CD platform.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EasyPIM Azure DevOps Architecture + Event Grid Automation │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Azure DevOps Project            Azure Infrastructure                       │
│  ┌─────────────────┐              ┌─────────────────────────────────────┐   │
│  │   🔧 Pipelines   │    OIDC      │  🔐 Service Principal              │   │
│  │  ┌─────────────┐ │◄────────────►│  • Federated Identity Credentials  │   │
│  │  │ Pipeline 1  │ │              │  • Graph API Permissions           │   │
│  │  │ Pipeline 2  │◄┼──────────────┼──🔔 Event Grid Automation        │   │
│  │  │ Pipeline 3  │ │              │  • Azure Function (PowerShell)    │   │
│  │  └─────────────┘ │              │  • Azure DevOps API Integration   │   │
│  └─────────────────┘              └─────────────────────────────────────┘   │
│                                                     │                       │
│  📋 Variable Groups               🗝️ Azure Key Vault │                      │
│  ┌─────────────────┐              ┌─────────────────┼─────────────────┐    │
│  │ • PIM Settings  │──────────────►│ • PIM Policies  │                 │    │
│  │ • Azure Config  │              │ • Role Assignments                 │    │
│  │ • Environments  │              │ • Secure Secret Storage           │    │
│  └─────────────────┘              │                 │                 │    │
│                                    │ 🚀 Secret Change│→ Event Grid     │    │
│                                    │                 │  ↓              │    │
│                                    │                 │  Azure Function │    │
│                                    │                 │  ↓              │    │
│                                    │                 │  ADO API Call   │    │
│                                    └─────────────────┼─────────────────┘    │
│                                                      ▼                       │
│                           ┌─────────────────────────────────────────┐       │
│                           │  🎯 Target Environment                 │       │
│                           │  • Entra ID Roles                      │       │
│                           │  • Azure Subscriptions                 │       │
│                           │  • Group Memberships                   │       │
│                           │  • Policy Enforcement (Real-Time!)     │       │
│                           └─────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘

🔄 Pipeline Execution Flow:
1️⃣ Authentication Test → Validates OIDC and connectivity
2️⃣ Orchestrator → Applies PIM configuration (Entra + Azure + Groups)  
3️⃣ Drift Detection → Monitors and reports compliance status

⚡️ Event-Driven Automation Flow:
🔄 Key Vault Change → Event Grid → Azure Function → Azure DevOps Pipeline → EasyPIM Orchestrator → Real-Time PIM Updates
```

---

## 📋 Table of Contents

1. [🎯 Azure DevOps Advantages](#-azure-devops-advantages)
2. [🔧 Prerequisites](#-prerequisites)
3. [🚀 Quick Setup](#-quick-setup)
4. [🏗️ Manual Setup (Detailed)](#️-manual-setup-detailed)
5. [📋 Azure DevOps Configuration](#-azure-devops-configuration)
6. [🔧 Pipeline Creation](#-pipeline-creation)
7. [🧪 Testing Your Setup](#-testing-your-setup)
8. [⚡️ Event-Driven Automation](#️-event-driven-automation)
9. [🛡️ Security & Best Practices](#️-security--best-practices)
10. [🆘 Troubleshooting](#-troubleshooting)

---

## 🎯 Azure DevOps Advantages

### ✨ **Why Choose Azure DevOps for EasyPIM?**

| Feature | Benefit |
|---------|---------|
| **🏢 Enterprise Integration** | Deep integration with Microsoft ecosystem |
| **🔐 Advanced Security** | Enterprise-grade security and compliance features |
| **📊 Project Management** | Built-in work item tracking and project management |
| **🌐 Hybrid Capabilities** | Self-hosted agents for on-premises requirements |
| **📈 Advanced Analytics** | Comprehensive reporting and analytics |
| **🔄 Complex Workflows** | Support for sophisticated pipeline scenarios |

### 🎯 **Perfect For:**
- Large enterprise organizations
- Teams requiring advanced project management
- Organizations with complex compliance requirements
- Multi-environment deployment scenarios
- Teams needing self-hosted build agents

---

## 🔧 Prerequisites

### **Required Tools:**

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Azure CLI** | Azure resource management | [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| **PowerShell 7+** | Script execution | [Install PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) |
| **Azure DevOps CLI** | ADO automation (auto-installed) | `az extension add --name azure-devops` |

### **Azure DevOps Requirements:**

| Requirement | Details |
|-------------|---------|
| **Azure DevOps Organization** | Your organization URL (e.g., `https://dev.azure.com/contoso`) |
| **Azure DevOps Project** | Project where pipelines will be created |
| **Basic License** | Required for pipeline usage |
| **Project Admin** | Permissions to create pipelines and service connections |

### **Azure Permissions:**
- **Contributor** + **User Access Administrator** on target subscription
- **Application Administrator** in Azure AD (for service principal creation)
- **Privileged Role Administrator** in Azure AD (for PIM configuration)

### **Authentication Setup:**
```powershell
# Authenticate to Azure
az login

# Authenticate to Azure DevOps
az devops configure --defaults organization=https://dev.azure.com/YourOrg project=YourProject
```

---

## 🚀 Quick Setup

### **Option 1: Automated Setup (Recommended)**
```powershell
# Clone and setup in one go
git clone https://github.com/kayasax/EasyPIM-EventDriven-Governance.git
cd EasyPIM-EventDriven-Governance

# Preview deployment first (safe)
.\scripts\setup-platform.ps1 -Platform AzureDevOps -WhatIf

# Interactive setup with prompts
.\scripts\setup-platform.ps1 -Platform AzureDevOps
```

### **Option 2: Non-Interactive Setup**
```powershell
# If you have all parameters ready
.\scripts\setup-platform.ps1 `
  -Platform AzureDevOps `
  -AzureDevOpsOrganization "YourOrg" `
  -AzureDevOpsProject "YourProject" `
  -ResourceGroupName "rg-easypim-ado" `
  -Interactive:$false
```

---

## 🏗️ Manual Setup (Detailed)

If you prefer step-by-step manual setup or need to understand each component:

### **Phase 1: Azure Infrastructure Deployment**

```powershell
# Deploy Azure resources optimized for Azure DevOps
.\scripts\deploy-azure-resources-enhanced.ps1 `
  -TargetPlatform AzureDevOps `
  -ResourceGroupName "rg-easypim-ado" `
  -Location "East US"
```

**This creates:**
- 🔐 **Service Principal** with Azure DevOps OIDC federation
- 🗝️ **Key Vault** for secure configuration storage
- ⚡ **Azure Function** for event processing
- 📡 **Event Grid** subscription for real-time triggers
- 📊 **Application Insights** for monitoring
- 🏷️ **ADO-optimized resource tags** and naming

### **Phase 2: Azure DevOps Configuration**

```powershell
# Configure variable groups and service connections
.\scripts\configure-cicd.ps1 `
  -Platform AzureDevOps `
  -AzureDevOpsOrganization "YourOrg" `
  -AzureDevOpsProject "YourProject" `
  -ResourceGroupName "rg-easypim-ado"
```

**This configures:**
- 📋 **Variable Groups** with Azure resource information
- 🔐 **Secure Variables** for sensitive configuration
- 🔗 **Service Connections** for Azure authentication
- ⚙️ **Pipeline Permissions** and security settings

---

## 📋 Azure DevOps Configuration

### **Variable Groups Created:**

| Variable Group | Purpose | Variables |
|----------------|---------|-----------|
| **EasyPIM-Azure** | Azure resource configuration | `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `RESOURCE_GROUP_NAME`, `KEY_VAULT_NAME` |
| **EasyPIM-Config** | EasyPIM-specific settings | `FUNCTION_APP_NAME`, `APPLICATION_INSIGHTS_NAME`, `EASYPIM_VERSION` |

### **Service Connections:**
- **Azure Resource Manager** connection with OIDC authentication
- **Workload Identity Federation** for secure, secret-free authentication
- **Automatic approval** for EasyPIM pipelines

### **Security Configuration:**
- 🔐 **Pipeline permissions** restricted to EasyPIM pipelines only
- 🛡️ **Variable group access** limited to authorized pipelines
- 📋 **Service connection scope** limited to EasyPIM resource group

---

## 🔧 Pipeline Creation

### **Current Status: Pipeline Templates**

> 🚧 **Note**: Azure DevOps pipeline templates are currently in development (Phase 2 of the ADO integration plan). The infrastructure and configuration are ready, but pipeline YAML files need to be created.

### **Available Now:**
- ✅ **Azure infrastructure** deployed and configured
- ✅ **Variable groups** set up with all required configuration
- ✅ **Service connections** configured with OIDC authentication
- ✅ **PowerShell scripts** ready for pipeline execution

### **Coming Soon:**
- 🚧 **Pipeline templates** (converted from GitHub Actions workflows)
- 🚧 **ADO-specific dashboard generation**
- 🚧 **Pipeline artifact management**

### **Manual Pipeline Creation (Interim Solution):**

You can create pipelines manually using the existing PowerShell scripts:

1. **Create New Pipeline** in Azure DevOps
2. **Select** "Existing Azure Pipelines YAML file" 
3. **Use** the following basic template:

```yaml
# Basic EasyPIM Pipeline Template
trigger: none  # Manual trigger only

variables:
- group: EasyPIM-Azure
- group: EasyPIM-Config

pool:
  vmImage: 'windows-latest'

steps:
- task: PowerShell@2
  displayName: 'Install EasyPIM Modules'
  inputs:
    filePath: 'scripts/workflows/Install-EasyPIMModules.ps1'
    
- task: PowerShell@2  
  displayName: 'Run EasyPIM Authentication Test'
  inputs:
    filePath: 'scripts/workflows/Invoke-EasyPIMWithAuth.ps1'
    arguments: '-ConfigSecretName "your-config-secret" -WhatIf'
```

---

## 🧪 Testing Your Setup

### **Step 1: Verify Azure Resources**
```powershell
# Check deployed resources
az group list --query "[?name=='rg-easypim-ado']" --output table
az keyvault list --resource-group rg-easypim-ado --output table
```

### **Step 2: Test Variable Groups**
```powershell
# List created variable groups
az pipelines variable-group list --organization https://dev.azure.com/YourOrg --project YourProject
```

### **Step 3: Validate Service Connection**
In Azure DevOps:
1. Go to **Project Settings** → **Service connections**
2. Find the **Azure Resource Manager** connection
3. Click **Verify** to test authentication

### **Step 4: Test Pipeline Execution**
1. Create a test pipeline using the template above
2. Run the pipeline manually
3. Verify successful authentication and module installation

---

## ⚡️ Event-Driven Automation

### **Azure Function Integration**

The deployed Azure Function is configured to trigger Azure DevOps pipelines via REST API:

```powershell
# Azure Function will call this endpoint when Key Vault changes
POST https://dev.azure.com/YourOrg/YourProject/_apis/pipelines/{pipelineId}/runs
```

### **Event Flow:**
1. **Key Vault Secret Change** detected by Event Grid
2. **Azure Function** processes the event
3. **Pipeline Trigger** via Azure DevOps REST API
4. **EasyPIM Execution** with automatic parameter passing
5. **Dashboard Update** with execution results

### **Configuration:**
The Azure Function uses these settings for ADO integration:
- `ADO_ORGANIZATION`: Your Azure DevOps organization
- `ADO_PROJECT`: Your project name  
- `ADO_PIPELINE_ID`: ID of the orchestrator pipeline
- `ADO_PAT`: Personal Access Token for API calls (stored in Key Vault)

---

## 🛡️ Security & Best Practices

### **OIDC Authentication:**
- ✅ **No secrets** in pipeline code
- ✅ **Workload Identity Federation** for Azure access
- ✅ **Least privilege** service principal permissions
- ✅ **Automatic token rotation** by Azure

### **Variable Group Security:**
- 🔐 **Secrets stored** in Azure Key Vault
- 🛡️ **Variable group permissions** restricted to specific pipelines
- 📋 **Audit logging** enabled for all access
- 🔒 **Encryption at rest** and in transit

### **Pipeline Security:**
- 🚫 **Branch protection** rules on main branch
- ✅ **Manual approval** for production deployments
- 📊 **Comprehensive logging** of all operations
- 🔍 **Automated security scanning** of pipeline changes

### **Compliance Features:**
- 📋 **Complete audit trail** of all PIM changes
- 🎯 **Policy compliance** validation before execution
- 📊 **Drift detection** and automatic alerting
- 🔄 **Rollback capabilities** for failed operations

---

## 🆘 Troubleshooting

### **Common Issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| **Pipeline not triggering** | Service connection not configured | Verify Azure Resource Manager connection |
| **Authentication failures** | OIDC not set up correctly | Check federated identity credentials |
| **Variable not found** | Variable group not linked | Add variable group to pipeline |
| **Permission denied** | Service principal lacks permissions | Grant required Azure AD and Azure permissions |

### **Diagnostic Commands:**
```powershell
# Check Azure DevOps authentication
az devops configure --list

# Test service connection
az pipelines list --organization https://dev.azure.com/YourOrg --project YourProject

# Verify variable groups
az pipelines variable-group list --organization https://dev.azure.com/YourOrg --project YourProject

# Test Azure Function
az functionapp show --name YourFunctionApp --resource-group rg-easypim-ado
```

### **Debug Mode:**
Enable detailed logging in pipelines:
```yaml
variables:
  system.debug: true  # Enable debug logging
```

### **Getting Help:**
- 📖 **Azure DevOps Documentation**: [Azure Pipelines Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- 🐛 **Report Issues**: [GitHub Issues](https://github.com/kayasax/EasyPIM-EventDriven-Governance/issues)
- 💬 **Community Support**: [GitHub Discussions](https://github.com/kayasax/EasyPIM-EventDriven-Governance/discussions)

---

## 🎉 Next Steps

After completing your Azure DevOps setup:

1. **🧪 Test Manual Pipeline Execution**
   - Verify authentication and basic functionality
   - Test EasyPIM module installation and execution

2. **🔧 Configure PIM Policies**
   - Add your organization's role assignments and policies to Key Vault
   - Test policy application and validation

3. **⚡ Enable Event Automation**
   - Configure Azure Function with your ADO organization details  
   - Test Key Vault-triggered pipeline executions

4. **📊 Set Up Monitoring**
   - Configure Application Insights dashboards
   - Set up alerting for failed operations

5. **🚀 Production Deployment**
   - Deploy to your production environment
   - Configure production-specific variable groups and policies

6. **📋 Team Training**
   - Train your team on pipeline usage and monitoring
   - Establish operational procedures and troubleshooting guides

---

## 🎊 **Congratulations!**

You've successfully set up EasyPIM Event-Driven Governance with Azure DevOps! Your organization now has enterprise-grade, automated privilege identity management with real-time policy enforcement.

**🎯 Ready to go further?** Check out the [Azure DevOps Integration Plan](Azure-DevOps-Integration-Plan.md) for advanced features and roadmap items.
