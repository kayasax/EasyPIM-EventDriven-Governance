# 🚀 EasyPIM Event-Driven Governance - Customer Template

> **⚗️ One-Click Setup for Enterprise PIM Automation**

Transform your Privileged Identity Management with automated, event-driven governance that responds to configuration changes in real-time.

---

## 🎯 **Quick Start** (3 minutes)

```powershell
# 1. Clone this template
git clone <your-repository-url>
cd EasyPIM-EventDriven-Governance

# 2. Run the setup wizard (handles everything automatically)
.\scripts\setup-platform.ps1

# 3. Choose your CI/CD platform:
#    • GitHub Actions (recommended for most teams)  
#    • Azure DevOps (enterprise integration)
#    • Both (maximum flexibility)
```

**That's it!** The setup wizard handles:
- ✅ Azure resource deployment 
- ✅ CI/CD platform configuration
- ✅ Authentication & security setup
- ✅ Event-driven automation

---

## 📁 **Repository Structure** 

```
📦 EasyPIM-EventDriven-Governance
├── 📁 scripts/
│   ├── 📜 setup-platform.ps1          ⭐ MAIN ENTRY POINT
│   ├── 📜 configure-cicd.ps1           (Platform configuration)
│   ├── 📜 deploy-azure-resources-enhanced.ps1  (Azure deployment)
│   └── 📁 workflows/                   (GitHub Actions workflows)
├── 📁 templates/
│   ├── 📜 deploy-azure-resources-working.bicep
│   ├── 📜 deploy-azure-resources-working.parameters.json
│   ├── 📜 deploy-azure-resources-simple.bicep
│   └── 📜 deploy-azure-resources-simple.parameters.json
├── 📁 examples/
│   └── 📁 event-grid/                  (Advanced automation examples)
└── 📁 docs/                           (Detailed guides)
```

---

## 🎯 **What You Get**

### **🏗️ Azure Infrastructure**
- **Key Vault** - Secure configuration storage with event triggers
- **Azure Function** - Event processing and PIM orchestration  
- **Service Principal** - OIDC authentication for CI/CD
- **Monitoring** - Application Insights and Log Analytics

### **🔄 CI/CD Integration** 
- **GitHub Actions** - Ready-to-use workflows with modern dashboards
- **Azure DevOps** - Enterprise pipelines with comprehensive reporting
- **Event Automation** - Key Vault changes automatically trigger PIM updates

### **🔐 Security Features**
- **OIDC Authentication** - No stored secrets, federated identity
- **Least Privilege** - Automated role assignments and cleanups
- **Audit Trail** - Complete tracking of all PIM changes
- **What-If Mode** - Preview changes before applying

---

## 💡 **Customer Customization**

### **🎯 Required Changes**
1. **Repository URL** - Update in setup script prompts
2. **PIM Policies** - Configure your policies in Key Vault secrets  
3. **Azure Naming** - Adjust resource naming conventions
4. **Environment Config** - Set up TEST/PROD configurations

### **⚙️ Optional Enhancements**
- **Event Grid Integration** - See `examples/event-grid/` for advanced automation
- **Multi-Environment** - Deploy separate TEST/PROD instances
- **Custom Dashboards** - Power BI templates and monitoring
- **Compliance Reports** - Automated governance reporting

---

## 📚 **Documentation**

| Guide | Description | When to Use |
|-------|-------------|-------------|
| **[Platform Setup Guide](docs/Platform-Setup-Guide.md)** | Detailed setup instructions | First-time deployment |
| **[GitHub Actions Guide](docs/GitHub-Actions-Guide.md)** | GitHub-specific configuration | Using GitHub Actions |
| **[Azure DevOps Guide](docs/Azure-DevOps-Guide.md)** | Azure DevOps configuration | Using Azure DevOps |
| **[Troubleshooting Guide](docs/troubleshooting.md)** | Common issues & solutions | When things go wrong |

---

## 🆘 **Support & Community**

- 📖 **Documentation** - Complete guides in `docs/` folder
- 🐛 **Issues** - [GitHub Issues](../../issues) for bug reports
- 💬 **Discussions** - [Community Forum](../../discussions) for questions
- 🚀 **Updates** - Watch this repository for latest improvements

---

## 🏢 **Enterprise Features**

### **Multi-Tenant Support**
- Deploy across multiple Azure tenants
- Centralized governance and reporting
- Tenant-specific policy configurations

### **Integration Ready**
- REST API endpoints for custom integrations
- PowerBI dashboard templates
- SIEM integration capabilities
- Custom webhook support

### **Compliance & Security**
- SOC 2 / ISO 27001 aligned logging
- Automated compliance reporting
- Zero-trust security model
- Audit trail preservation

---

## 🎊 **Ready to Get Started?**

Run the setup wizard to deploy your EasyPIM automation in minutes:

```powershell
.\scripts\setup-platform.ps1
```

**Transform your PIM management from reactive to proactive with intelligent, event-driven automation!** 

---

*💡 **Pro Tip**: Start with a test environment and GitHub Actions for the smoothest experience. You can always add Azure DevOps integration later.*
