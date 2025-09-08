# 🚀 EasyPIM CI/CD Automation

[![Phase 1: Authentication Test](https://github.com/kayasax/EasyPIM-EventDriven-Governance/actions/workflows/01-auth-test.yml/badge.svg)](https://github.com/kayasax/EasyPIM-EventDriven-Governance/actions/workflows/01-auth-test.yml)
[![Phase 2: EasyPIM Policy Orchestrator](https://github.com/kayasax/EasyPIM-EventDriven-Governance/actions/workflows/02-orchestrator-test.yml/badge.svg)](https://github.com/kayasax/EasyPIM-EventDriven-Governance/actions/workflows/02-orchestrator-test.yml)
[![Phase 3: Policy Drift Detection](https://github.com/kayasax/EasyPIM-EventDriven-Governance/actions/workflows/03-policy-drift-check.yml/badge.svg)](https://github.com/kayasax/EasyPIM-EventDriven-Governance/actions/workflows/03-policy-drift-check.yml)

> **🛡️ Revolutionize your Azure Privileged Identity Management with event-driven automation!**
> Transform manual PIM operations into seamless, secure, and auditable workflows that respond to configuration changes in real-time.

---

## ✨ **Why Teams Choose This Framework**

<div align="center">

### 🔥 **The Problem We Solve**
*Manual PIM management is time-consuming, error-prone, and doesn't scale*

| ❌ **Before** | ✅ **After** |
|---------------|--------------|
| 🐌 Manual role assignments taking hours | ⚡ Automated workflows completing in minutes |
| 😰 Configuration drift going unnoticed | 🔍 Real-time drift detection and alerts |
| 🔄 Repetitive, error-prone tasks | 🤖 Intelligent automation with safety checks |
| 📋 Time-consuming compliance reporting | 📊 Automated compliance validation |
| 🚨 Security changes happening in isolation | 🔔 Event-driven responses to configuration changes |

</div>

---

## 🌟 **Multi-Platform Support**

<div align="center">

Choose the CI/CD platform that fits your organization:

| 🚀 **GitHub Actions** | 🔵 **Azure DevOps** | 🌟 **Both Platforms** |
|----------------------|---------------------|----------------------|
| ✅ Perfect for open source | ✅ Enterprise-grade features | ✅ Maximum flexibility |
| ✅ Quick setup (15 mins) | ✅ Advanced project management | ✅ Team choice freedom |
| ✅ GitHub-native integration | ✅ Hybrid cloud capabilities | ✅ Migration support |
| **[Setup Guide →](docs/GitHub-Actions-Guide.md)** | **[Setup Guide →](docs/Azure-DevOps-Guide.md)** | **[Platform Guide →](docs/Platform-Setup-Guide.md)** |

</div>

---

## 🎯 **Key Benefits That Matter**

<table>
<tr>
<td width="50%">

### 🛡️ **Enterprise Security**
- ✅ **Event-Driven Automation**: Responds instantly to Key Vault changes
- ✅ **Zero-Trust Architecture**: OIDC authentication, no stored secrets
- ✅ **Safety-First Design**: Built-in WhatIf modes and validation
- ✅ **Comprehensive Auditing**: Every action logged and traceable

</td>
<td width="50%">

### ⚡ **Operational Excellence**
- ✅ **Real-Time Monitoring**: Continuous drift detection
- ✅ **Smart Parameter Detection**: Automatic test vs. production modes
- ✅ **Scalable Architecture**: From startups to enterprise
- ✅ **DevOps Integration**: Native GitHub Actions workflows

</td>
</tr>
</table>

---

## 🚀 **Complete Event-Driven Automation**

```mermaid
flowchart LR
    KV["🔑 Key Vault<br/>Config Change"]
    EG["⚡ Event Grid<br/>Instant Trigger"]
    AF["🔧 Azure Function<br/>Smart Processing"]
    GH["🚀 GitHub Actions<br/>Workflow Dispatch"]
    EP["🛡️ EasyPIM<br/>Policy Enforcement"]

    KV --> EG
    EG --> AF
    AF --> GH
    GH --> EP

    style KV fill:#0078d4,stroke:#005a9f,stroke-width:2px,color:#ffffff
    style EG fill:#7b68ee,stroke:#5a4fcf,stroke-width:2px,color:#ffffff
    style AF fill:#00bcf2,stroke:#0099cc,stroke-width:2px,color:#ffffff
    style GH fill:#ff6b35,stroke:#cc4a1c,stroke-width:2px,color:#ffffff
    style EP fill:#e81123,stroke:#b8000d,stroke-width:2px,color:#ffffff
```

**🎭 Intelligence Built-In:**
- 🧠 **Smart Detection**: Test secrets trigger WhatIf mode, production secrets enable full automation
- 🔄 **Instant Response**: Configuration changes automatically trigger appropriate workflows
- 🛡️ **Safety Guardrails**: Multiple validation layers prevent unauthorized changes
- 📊 **Complete Visibility**: End-to-end tracing from change to enforcement

---

## 🎯 **Perfect For Your Team If...**

<div align="center">

| 🏢 **Enterprise IT** | 🚀 **DevOps Teams** | 🛡️ **Security Teams** |
|---------------------|---------------------|----------------------|
| Managing 100+ privileged roles | Need PIM in CI/CD pipelines | Require continuous compliance |
| Want to eliminate manual tasks | Building Infrastructure as Code | Must track all access changes |
| Need compliance automation | Love event-driven architectures | Want real-time security monitoring |

</div>

---

## 🎬 **Get Started in 15 Minutes**

<div align="center">

### 🔥 **Ready to Transform Your PIM Operations?**

**[📖 Choose Your Platform & Get Started →](docs/Platform-Setup-Guide.md)**

*Everything you need: Azure setup, Event Grid integration, GitHub configuration, and real-world examples*

</div>

---

## 📋 **What's Included**

| Component | Description | Status |
|-----------|-------------|--------|
| 🔐 **Authentication Framework** | OIDC integration with Azure AD | ✅ Production Ready |
| ⚡ **Event Grid Integration** | Real-time Key Vault change detection | ✅ Production Ready |
| 🔧 **Azure Function** | Smart workflow triggering with parameter detection | ✅ Production Ready |
| 🚀 **GitHub Actions Workflows** | 3-phase testing and deployment automation | ✅ Production Ready |
| 📊 **Drift Detection** | Continuous compliance monitoring | ✅ Production Ready |
| 🛠️ **Deployment Scripts** | One-click Azure resource provisioning | ✅ Production Ready |
| 📖 **Complete Documentation** | Multi-platform implementation guides | ✅ Production Ready |

---

<div align="center">

### 🎯 **Start Your PIM Automation Journey**

**[📖 Platform Setup Guide](docs/Platform-Setup-Guide.md)** • **[🚀 GitHub Actions Guide](docs/GitHub-Actions-Guide.md)** • **[🔵 Azure DevOps Guide](docs/Azure-DevOps-Guide.md)** • **[🔧 Scripts Documentation](scripts/README.md)**

---

*Built with ❤️ for Azure administrators who value security, automation, and operational excellence*
*Loïc*
</div>
