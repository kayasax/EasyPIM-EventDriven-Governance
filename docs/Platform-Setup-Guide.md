# 🚀 EasyPIM Event-Driven Governance - Platform Setup Guide

**Choose Your CI/CD Platform and Get Started Quickly**

---

## 🎯 **Welcome to EasyPIM Event-Driven Governance**

This guide helps you choose the right CI/CD platform and provides tailored setup instructions for your organization's needs.

### ✨ **What You Get**
- **🔄 Event-Driven Automation**: Real-time PIM updates triggered by Key Vault changes
- **🛡️ Secure OIDC Authentication**: No secrets in code, enterprise-grade security
- **📊 Comprehensive Monitoring**: Automated compliance and drift detection
- **🏗️ Infrastructure as Code**: Reproducible deployments across environments

---

## 🏗️ **Platform Choice Matrix**

Choose the platform that best fits your organization:

| Factor | GitHub Actions | Azure DevOps | Both Platforms |
|--------|----------------|---------------|----------------|
| **🏢 Organization Type** | Open Source, Small Teams | Enterprise, Large Organizations | Multi-Platform Organizations |
| **💰 Cost** | Free for public repos | Requires Azure DevOps licensing | Higher setup complexity |
| **🔐 Security** | GitHub-managed runners | Self-hosted or Microsoft-hosted | Maximum flexibility |
| **🛠️ Integration** | GitHub ecosystem | Microsoft ecosystem | Best of both worlds |
| **📈 Scalability** | Good | Excellent | Maximum |
| **⚡ Setup Time** | 15-30 minutes | 30-45 minutes | 45-60 minutes |

---

## 🎯 **Quick Platform Selector**

### 🚀 **Choose GitHub Actions If:**
- ✅ Your code is hosted on GitHub
- ✅ You prefer simple, fast setup
- ✅ You're working with open source projects
- ✅ You want to get started quickly
- ✅ You have small to medium teams

**→ [GitHub Actions Setup Guide](GitHub-Actions-Guide.md)**

### 🔵 **Choose Azure DevOps If:**
- ✅ Your organization uses Microsoft ecosystem
- ✅ You need enterprise-grade project management
- ✅ You require advanced compliance features
- ✅ You have complex branching strategies
- ✅ You need tight integration with Azure services

**→ [Azure DevOps Setup Guide](Azure-DevOps-Guide.md)**

### 🌟 **Choose Both Platforms If:**
- ✅ You want maximum flexibility
- ✅ Different teams prefer different platforms
- ✅ You're migrating between platforms
- ✅ You need redundancy and options

**→ Continue with Multi-Platform Setup Below**

---

## 🔧 **Prerequisites (All Platforms)**

### **Required Before Starting:**

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Azure CLI** | Azure resource management | [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| **PowerShell 7+** | Script execution | [Install PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) |

### **Platform-Specific Tools:**

| Platform | Additional Requirements |
|----------|------------------------|
| **GitHub** | [GitHub CLI](https://cli.github.com/) + `gh auth login` |
| **Azure DevOps** | Azure DevOps CLI extension (auto-installed) |

### **Azure Permissions:**
- **Contributor** + **User Access Administrator** on target subscription
- **Application Administrator** in Azure AD (for service principal creation)
- **Privileged Role Administrator** in Azure AD (for PIM configuration)

---

## 🚀 **Quick Start - Multi-Platform Setup**

### **Step 1: Preview Your Deployment**
```powershell
# Clone the repository (if not done already)
git clone https://github.com/kayasax/EasyPIM-EventDriven-Governance.git
cd EasyPIM-EventDriven-Governance

# Preview what will be deployed (safe - no changes made)
.\scripts\setup-platform.ps1 -Platform Both -WhatIf
```

### **Step 2: Interactive Setup**
```powershell
# Interactive setup with prompts
.\scripts\setup-platform.ps1 -Platform Both
```

### **Step 3: Non-Interactive Setup** *(Optional)*
```powershell
# Automated setup (if you have all parameters)
.\scripts\setup-platform.ps1 `
  -Platform Both `
  -GitHubRepository "YourOrg/YourRepo" `
  -AzureDevOpsOrganization "YourOrg" `
  -AzureDevOpsProject "YourProject" `
  -Interactive:$false
```

---

## 📋 **Setup Process Overview**

### **Phase 1: Azure Infrastructure** ⚡
- **Azure Resource Group** with platform-optimized settings
- **Key Vault** for secure configuration storage
- **Azure Function** for event processing  
- **Event Grid** for real-time triggering
- **Service Principal** with OIDC federation
- **Application Insights** for monitoring

### **Phase 2: CI/CD Platform Configuration** 🔧
- **GitHub**: Repository secrets and variables
- **Azure DevOps**: Variable groups and service connections
- **Authentication** setup and testing
- **Workflow/Pipeline** validation

---

## 🎉 **What Happens After Setup**

### **Immediate Capabilities:**
- ✅ **Manual Workflow Triggers**: Run PIM operations on-demand
- ✅ **Secure Authentication**: OIDC-based, no secrets in code
- ✅ **Comprehensive Logging**: Full audit trail and artifacts
- ✅ **Dashboard Reporting**: Rich execution summaries

### **Event-Driven Automation:**
- 🔄 **Key Vault Change** → **Event Grid** → **Azure Function** → **CI/CD Workflow** → **EasyPIM Execution**
- ⚡ **Real-time PIM Updates**: Changes applied within minutes of configuration updates
- 📊 **Automatic Compliance**: Continuous monitoring and drift detection

---

## 📚 **Platform-Specific Guides**

### 🚀 **GitHub Actions**
**Best for:** Quick setup, open source projects, GitHub-native teams

**Features:**
- GitHub-hosted runners (no infrastructure management)
- Seamless GitHub integration
- Rich action marketplace
- Built-in security features

**→ [Complete GitHub Actions Guide](GitHub-Actions-Guide.md)**

### 🔵 **Azure DevOps** 
**Best for:** Enterprise environments, complex workflows, Microsoft ecosystem

**Features:**
- Microsoft-hosted or self-hosted agents
- Advanced project management integration
- Enterprise security and compliance
- Sophisticated pipeline templates

**→ [Complete Azure DevOps Guide](Azure-DevOps-Guide.md)**

---

## 🛠️ **Advanced Configuration**

### **Custom Resource Names**
```powershell
.\scripts\setup-platform.ps1 `
  -Platform Both `
  -ResourceGroupName "rg-myorg-easypim-prod" `
  -Location "West Europe"
```

### **Force Mode (No Prompts)**
```powershell
.\scripts\setup-platform.ps1 -Platform Both -Force
```

### **Environment-Specific Deployments**
```powershell
# Development environment
.\scripts\setup-platform.ps1 -Platform GitHub -ResourceGroupName "rg-easypim-dev"

# Production environment  
.\scripts\setup-platform.ps1 -Platform Both -ResourceGroupName "rg-easypim-prod"
```

---

## 🆘 **Troubleshooting & Support**

### **Common Issues:**
- **Authentication Errors**: Ensure `az login` and `gh auth login` are completed
- **Permission Denied**: Verify Azure subscription and AD permissions
- **Resource Conflicts**: Use unique resource group names across environments

### **Getting Help:**
- 📖 **Platform Guides**: Detailed troubleshooting in platform-specific guides
- 🐛 **Issues**: Report problems on the [GitHub Issues page](https://github.com/kayasax/EasyPIM-EventDriven-Governance/issues)
- 💡 **Discussions**: Community support in [GitHub Discussions](https://github.com/kayasax/EasyPIM-EventDriven-Governance/discussions)

### **Verification Steps:**
After setup, verify your deployment:
1. **Azure Resources**: Check Azure portal for deployed resources
2. **Authentication**: Test workflow/pipeline execution
3. **Event Automation**: Trigger Key Vault change and verify workflow execution

---

## 🎊 **Next Steps**

After completing platform setup:

1. **📋 Test Your Workflows**: Run authentication and orchestrator workflows
2. **🔧 Configure PIM Policies**: Add your organization's role assignments and policies
3. **⚡ Enable Event Automation**: Test Key Vault-triggered executions
4. **📊 Monitor Operations**: Set up alerts and monitoring dashboards
5. **🚀 Go Production**: Deploy to your production environment

---

**🎯 Ready to get started? Choose your platform above and follow the dedicated setup guide!**
