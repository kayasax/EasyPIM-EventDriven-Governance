# 🚀 EasyPIM Dual Platform Architecture - Complete Setup Guide

## 🎯 **Intelligent Event-Driven Governance**

The EasyPIM platform now features **intelligent dual-platform routing** that automatically chooses between GitHub Actions and Azure DevOps pipelines based on your Key Vault secret naming patterns.

## ⚡ **Automatic Configuration**

### **🔧 One-Command Setup**

```powershell
# Setup both platforms automatically
.\scripts\setup-platform.ps1 -Platform Both -GitHubRepository "owner/repo" -AzureDevOpsOrganization "contoso" -AzureDevOpsProject "EasyPIM"

# Interactive setup (recommended for first-time users)
.\scripts\setup-platform.ps1

# GitHub Actions only
.\scripts\setup-platform.ps1 -Platform GitHub -GitHubRepository "owner/repo"

# Azure DevOps only
.\scripts\setup-platform.ps1 -Platform AzureDevOps -AzureDevOpsOrganization "contoso" -AzureDevOpsProject "EasyPIM"
```

The setup script **automatically configures all required environment variables** for both platforms!

## 🏗️ **Smart Routing Architecture**

```
Key Vault Secret Change → Azure Function (Smart Router) → Platform Selection
     (Any Secret Name)      (Dual Platform Logic)           ↓
                                                    ┌─────────────────────┐
                                                    │  🧠 Smart Routing   │
                                                    │   Pattern Detection │
                                                    └─────────────────────┘
                                                             ↓
    ┌────────────────────────────────────────────────────────┼────────────────────────────────────────┐
    │                                                        │                                        │
    ▼ (Default Routes)                                       ▼ (Pattern Routes)                     │
📘 GitHub Actions                                       🔷 Azure DevOps                             │
                                                                                                     │
• easypim-config                                        • easypim-config-ado                       │
• easypim-prod                                          • easypim-prod-azdo                        │
• easypim-test (WhatIf)                                • easypim-test-devops (WhatIf)              │
• Any other pattern                                     • Any secret containing 'ado|azdo|devops'  │
                                                                                                     │
    │                                                        │                                        │
    ▼                                                        ▼                                        │
┌─────────────────────┐                            ┌─────────────────────┐                        │
│   GitHub Actions    │                            │  Azure DevOps       │                        │
│                     │                            │  Pipeline           │                        │
│ • Workflow Dispatch │                            │                     │                        │
│ • OIDC Security     │                            │ • REST API Trigger  │                        │
│ • Rich Dashboards   │                            │ • Service Principal │                        │
│ • Mature Ecosystem  │                            │ • Enterprise Grade  │                        │
└─────────────────────┘                            └─────────────────────┘                        │
                                                                                                     │
└─────────────────────────────── 🔄 Unified EasyPIM Execution ────────────────────────────────────┘
```

## 🎯 **Routing Logic Examples**

### **📘 GitHub Actions Routes (Default)**
| Secret Name | Platform | Mode | Description |
|-------------|----------|------|-------------|
| `easypim-config` | GitHub Actions | Normal | Production deployment |
| `easypim-prod` | GitHub Actions | Normal | Production deployment |
| `easypim-test` | GitHub Actions | **WhatIf** | Test mode (preview only) |
| `easypim-debug` | GitHub Actions | **WhatIf** | Debug mode (preview only) |
| `any-other-name` | GitHub Actions | Normal | Default routing |

### **🔷 Azure DevOps Routes (Pattern-Based)**
| Secret Name | Platform | Mode | Description |
|-------------|----------|------|-------------|
| `easypim-config-ado` | Azure DevOps | Normal | Production deployment |
| `easypim-prod-azdo` | Azure DevOps | Normal | Production deployment |
| `easypim-test-devops` | Azure DevOps | **WhatIf** | Test mode (preview only) |
| `company-config-ado` | Azure DevOps | Normal | Enterprise deployment |
| `anything-with-ado` | Azure DevOps | Normal | Pattern-based routing |

## 🔧 **Automatic Environment Configuration**

The setup script automatically configures these Function App environment variables:

### **📘 GitHub Actions (Always Required)**
```bash
GITHUB_TOKEN=your_github_pat_token
```

### **🔷 Azure DevOps (Pattern-Based Routing)**
```bash
ADO_ORGANIZATION=your-ado-org
ADO_PROJECT=your-ado-project
ADO_PIPELINE_ID=your-pipeline-id
ADO_PAT=your-personal-access-token
```

## 🧠 **Smart Features**

### **⚡ Intelligent Parameter Detection**

The Function automatically adjusts parameters based on secret names:

- **Test/Debug Mode**: Secrets containing `test|debug|dev` → **WhatIf mode enabled**
- **Initial Setup**: Secrets containing `initial|setup|bootstrap` → **Initial mode**
- **Verbose Logging**: Secrets containing `verbose|debug` → **Verbose mode enabled**

### **🔄 Environment Variable Overrides**

Override default behavior with Function App environment variables:

```bash
EASYPIM_WHATIF=true          # Force WhatIf mode for all executions
EASYPIM_MODE=initial         # Force initial mode for all executions
EASYPIM_VERBOSE=true         # Force verbose mode for all executions
```

## 📋 **Function App Logs Examples**

### **GitHub Actions Routing**
```
🔍 Processing Key Vault event for secret: easypim-prod in vault: kv-easypim-8368
🎯 Using default GitHub Actions routing for secret: easypim-prod
✅ GitHub Actions workflow triggered successfully!
```

### **Azure DevOps Routing**
```
🔍 Processing Key Vault event for secret: easypim-config-ado in vault: kv-easypim-8368
🎯 Detected Azure DevOps pattern - routing to Azure DevOps pipeline
✅ Azure DevOps pipeline triggered successfully!
Pipeline Run ID: 12345
Pipeline URL: https://dev.azure.com/contoso/EasyPIM/_build/results?buildId=12345
```

## 🚀 **Testing Your Setup**

### **Test GitHub Actions Routing**
1. Create/update a Key Vault secret named `easypim-test`
2. Check Function App logs for GitHub Actions routing
3. Verify GitHub Actions workflow is triggered with WhatIf mode

### **Test Azure DevOps Routing**
1. Create/update a Key Vault secret named `easypim-test-ado`
2. Check Function App logs for Azure DevOps routing
3. Verify Azure DevOps pipeline is triggered with WhatIf mode

## 🎛️ **Advanced Configuration**

### **Custom Routing Patterns**

You can modify the routing logic in your Function App by editing the pattern matching:

```powershell
# Current pattern in run.ps1
if ($secretName -match "ado|azdo|devops") {
    # Route to Azure DevOps
}

# Add custom patterns
if ($secretName -match "ado|azdo|devops|enterprise|company") {
    # Route to Azure DevOps
}
```

### **Multi-Environment Support**

Use descriptive secret names for different environments:

```bash
easypim-dev-config          # GitHub Actions, WhatIf mode
easypim-staging-config      # GitHub Actions, normal mode
easypim-prod-config         # GitHub Actions, normal mode
easypim-dev-ado             # Azure DevOps, WhatIf mode
easypim-staging-azdo        # Azure DevOps, normal mode
easypim-prod-devops         # Azure DevOps, normal mode
```

## 🎯 **Benefits of Dual Platform Architecture**

| Benefit | Description |
|---------|-------------|
| **🚀 Flexibility** | Choose the best platform for each team/environment |
| **🔄 Gradual Migration** | Migrate from one platform to another gradually |
| **🏢 Enterprise Ready** | Azure DevOps for enterprise, GitHub for agility |
| **🛡️ Risk Mitigation** | Fallback options if one platform is unavailable |
| **👥 Team Preference** | Different teams can use their preferred platform |
| **🎛️ Smart Automation** | Intelligent routing based on business rules |

## 🔍 **Troubleshooting**

### **Function App Not Routing Correctly**
1. Check Function App logs in Azure Portal
2. Verify environment variables are set correctly
3. Test secret name patterns match expectations

### **Azure DevOps Not Triggering**
1. Verify `ADO_*` environment variables are configured
2. Check Personal Access Token permissions
3. Confirm Pipeline ID is correct

### **GitHub Actions Not Triggering**
1. Verify `GITHUB_TOKEN` is configured
2. Check GitHub repository permissions
3. Confirm workflow file exists and is enabled

## 📈 **Next Steps**

1. **Run the setup script** with your preferred platform(s)
2. **Test both routing paths** with different secret names
3. **Monitor Function App logs** for routing decisions
4. **Configure additional environments** as needed
5. **Set up monitoring and alerts** for failed executions

Your EasyPIM platform is now ready for intelligent dual-platform event-driven governance! 🎉
