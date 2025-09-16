# 🚀 EasyPIM Event-Driven Governance - Complete Step-by-Step Guide

This repository is a comprehensive **demonstration and tutorial** for implementing intelligent, event-driven PIM governance with dual-platform CI/CD integration.

## 🎯 **What You'll Build**

A complete **intelligent event-driven governance platform** that:
- **🔄 Automatically responds** to Key Vault configuration changes  
- **🧠 Smart routing** between GitHub Actions and Azure DevOps based on secret names
- **📊 Real-time monitoring** and compliance validation
- **🛡️ Enterprise-grade security** with zero stored secrets
- **⚡ Instant deployment** of PIM policy changes

## 🏗️ **Architecture Overview**

```
📦 Key Vault Secret Change → 🌐 Event Grid → ⚡ Azure Function (Smart Router)
                                                    ↓
                                          🧠 Intelligent Platform Selection
                                                    ↓
            ┌─────────────────────────────────────────────────────────┐
            │                                                         │
     📘 GitHub Actions                                   🔷 Azure DevOps
    (Default Routing)                                  (Pattern Routing)
            │                                                         │
            └─────────────────→ 🎯 EasyPIM Orchestrator ←─────────────┘
                                            ↓
                              📋 Automated PIM Policy Updates
```

## 📚 **Step-by-Step Implementation**

### **Phase 1: Foundation Setup** ⚡

#### **Step 1: Deploy Azure Infrastructure**
```powershell
# Deploy all Azure resources with one command
.\scripts\deploy-azure-resources.ps1 -ResourceGroupName "rg-easypim-demo" -Location "East US"
```

**What this creates:**
- ✅ **Azure Function App** (PowerShell runtime) with smart routing logic
- ✅ **Event Grid Subscription** for Key Vault change detection  
- ✅ **Key Vault** for secure configuration storage
- ✅ **Storage Account** with proper authentication
- ✅ **Application Insights** for monitoring and logging

#### **Step 2: Configure Authentication & Permissions**
```powershell
# Grant required permissions for EasyPIM operations
.\scripts\grant-required-permissions.ps1 -ResourceGroupName "rg-easypim-demo"
```

### **Phase 2: Dual Platform Configuration** 🚀

#### **Step 3: Choose Your Platform Architecture**

**🌟 Option A: Dual Platform (Recommended)**
```powershell
# Configure both GitHub Actions AND Azure DevOps
.\scripts\setup-platform.ps1 -Platform Both
```

**📘 Option B: GitHub Actions Only**  
```powershell
.\scripts\setup-platform.ps1 -Platform GitHub
```

**🔷 Option C: Azure DevOps Only**
```powershell
.\scripts\setup-platform.ps1 -Platform AzureDevOps
```

The setup script will **interactively guide you through:**
- 🔑 Personal Access Token collection
- 🏢 Organization/Repository configuration  
- ⚙️ Function App environment variable setup
- 🧪 Testing and validation instructions

### **Phase 3: Smart Routing Configuration** 🧠

#### **Step 4: Understand Intelligent Routing Patterns**

Your Azure Function now **automatically chooses** the CI/CD platform based on secret names:

**📘 GitHub Actions Routes (Default Behavior)**
- `easypim-config` → GitHub Actions (Production)
- `easypim-prod` → GitHub Actions (Production)  
- `easypim-test` → GitHub Actions (WhatIf Mode)
- `any-other-name` → GitHub Actions (Default)

**🔷 Azure DevOps Routes (Pattern Detection)**
- `easypim-config-ado` → Azure DevOps (Production)
- `easypim-prod-azdo` → Azure DevOps (Production)
- `easypim-test-devops` → Azure DevOps (WhatIf Mode)
- `anything-with-ado` → Azure DevOps (Pattern Match)

#### **Step 5: Test Your Smart Routing**

**Test GitHub Actions Path:**
```powershell
# This will route to GitHub Actions (WhatIf mode)
az keyvault secret set --vault-name "kv-easypim-demo" --name "easypim-test" --value "test-config"
```

**Test Azure DevOps Path:**
```powershell
# This will route to Azure DevOps (WhatIf mode)  
az keyvault secret set --vault-name "kv-easypim-demo" --name "easypim-test-ado" --value "test-config"
```

**Monitor Results:**
- 🔍 **Azure Portal** → Function App → Monitor → Logs
- 📊 **GitHub Actions** → Your Repository → Actions tab
- 🔷 **Azure DevOps** → Your Project → Pipelines

### **Phase 4: Production Deployment** 🎯

#### **Step 6: Deploy Your EasyPIM Configuration**

**Create your EasyPIM configuration** in Key Vault:
```powershell
# Production deployment (GitHub Actions)
az keyvault secret set --vault-name "kv-easypim-demo" --name "easypim-prod" --value @easypim-config.json

# Production deployment (Azure DevOps)
az keyvault secret set --vault-name "kv-easypim-demo" --name "easypim-prod-ado" --value @easypim-config.json
```

#### **Step 7: Monitor and Validate**

**Real-time Monitoring:**
- ✅ **Function App Logs** show routing decisions
- ✅ **GitHub Actions** workflows trigger automatically  
- ✅ **Azure DevOps** pipelines execute with parameters
- ✅ **EasyPIM** applies PIM policies based on configuration
- ✅ **Application Insights** provides detailed telemetry

## 🎛️ **Advanced Features**

### **🔧 Environment Variable Overrides**

Control Function behavior with these environment variables:

```bash
EASYPIM_WHATIF=true          # Force WhatIf mode for all executions
EASYPIM_MODE=initial         # Force initial mode for all executions  
EASYPIM_VERBOSE=true         # Enable verbose logging for all executions
```

### **🏢 Multi-Environment Support**

Structure your secrets for different environments:

```
easypim-dev-config          # Development (GitHub Actions, WhatIf)
easypim-staging-config      # Staging (GitHub Actions, Normal)
easypim-prod-config         # Production (GitHub Actions, Normal)

easypim-dev-ado             # Development (Azure DevOps, WhatIf)  
easypim-staging-azdo        # Staging (Azure DevOps, Normal)
easypim-prod-devops         # Production (Azure DevOps, Normal)
```

### **📊 Custom Routing Patterns**

Modify routing logic in your Function App:

```powershell
# Edit EasyPIM-secret-change-detected/run.ps1
if ($secretName -match "ado|azdo|devops|enterprise") {
    # Custom Azure DevOps routing patterns
}
```

## 🧪 **Validation & Testing**

### **🔍 Function App Validation**

**Expected Log Patterns:**
```
✅ GitHub Actions: "🎯 Using default GitHub Actions routing for secret: easypim-prod"
✅ Azure DevOps: "🎯 Detected Azure DevOps pattern - routing to Azure DevOps pipeline"  
✅ Parameters: "⚙️ Detected test/debug mode - enabling WhatIf parameter"
```

### **🎯 CI/CD Pipeline Validation**

**GitHub Actions Success Indicators:**
- ✅ Workflow triggered in Actions tab
- ✅ EasyPIM module installed successfully
- ✅ Authentication established via OIDC
- ✅ PIM policies applied/validated

**Azure DevOps Success Indicators:**
- ✅ Pipeline triggered via REST API
- ✅ Build logs show parameter passing
- ✅ Service Principal authentication successful
- ✅ EasyPIM execution completed

## 📋 **Troubleshooting Guide**

### **🔧 Common Issues & Solutions**

| **Issue** | **Cause** | **Solution** |
|-----------|-----------|-------------|
| Function not triggering | Event Grid subscription missing | Re-run deployment script |
| GitHub Actions fails | Invalid PAT token | Regenerate token with correct permissions |
| Azure DevOps not found | Wrong organization/project | Verify ADO_* environment variables |
| Storage authentication error | Public access disabled | Enable public access temporarily |
| PIM permissions denied | Missing AAD roles | Run grant-required-permissions.ps1 |

### **🔍 Debug Commands**

```powershell
# Check Function App settings
az functionapp config appsettings list --name "your-function-app" --resource-group "your-rg"

# View Function App logs  
az functionapp log tail --name "your-function-app" --resource-group "your-rg"

# Test Key Vault connectivity
az keyvault secret show --vault-name "your-keyvault" --name "test-secret"

# Verify Event Grid subscription
az eventgrid event-subscription list --source-resource-id "/subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/your-keyvault"
```

## 🎉 **Success Criteria**

You've successfully implemented EasyPIM dual-platform governance when:

- ✅ **Smart Routing Works** - Different secret names trigger different platforms
- ✅ **Parameters Flow Correctly** - WhatIf mode activates for test secrets  
- ✅ **Both Platforms Respond** - GitHub Actions AND Azure DevOps both work
- ✅ **Real-time Updates** - Key Vault changes trigger instant pipeline execution
- ✅ **Monitoring Active** - Function App logs show routing decisions clearly
- ✅ **PIM Policies Applied** - EasyPIM successfully updates role assignments

## 🚀 **Next Steps**

1. **📖 Read Advanced Documentation** - [Dual-Platform-Setup-Guide.md](Dual-Platform-Setup-Guide.md)
2. **🔧 Customize Routing Logic** - Modify patterns for your organization
3. **📊 Set up Alerting** - Configure Azure Monitor alerts for failures  
4. **🏢 Scale to Production** - Deploy across multiple environments
5. **👥 Train Your Team** - Share knowledge of intelligent routing capabilities

---

## 💡 **Key Learning Outcomes**

After completing this guide, you will have:

- 🎯 **Mastered Event-Driven Architecture** for governance automation
- 🧠 **Implemented Intelligent Routing** between multiple CI/CD platforms
- 🛡️ **Established Zero-Trust Security** with OIDC and managed identities
- 📊 **Built Real-time Monitoring** with comprehensive logging and alerting
- ⚡ **Achieved Instant Response** to configuration changes
- 🏢 **Created Enterprise-Grade** governance automation

**🎉 Congratulations!** You've built a production-ready, intelligent, event-driven governance platform that showcases the power of modern Azure automation and dual-platform CI/CD integration!
