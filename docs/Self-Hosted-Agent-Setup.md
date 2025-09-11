# 🖥️ Azure DevOps Self-Hosted Agent Setup Guide

## 🎯 Overview
Self-hosted agents run on your own machine/VM and bypass all parallelism limitations for Azure DevOps free accounts.

## 📋 Prerequisites
- Windows machine with internet access
- Azure DevOps organization access (loic0161)
- Administrator rights on the machine
- PowerShell 5.1+ or PowerShell Core

## 🚀 Step-by-Step Setup

### **Step 1: Download Agent**
1. Go to Azure DevOps: https://dev.azure.com/loic0161/EasyPIM-CICD
2. Click **Project Settings** (bottom left)
3. Under **Pipelines** → click **Agent pools**
4. Click **Default** pool
5. Click **New agent** button
6. Select **Windows** tab
7. Click **Download** (saves `vsts-agent-win-x64-3.x.x.zip`)

### **Step 2: Create Agent Directory**
```powershell
# Create dedicated directory
New-Item -ItemType Directory -Path "C:\AzureAgent" -Force
Set-Location "C:\AzureAgent"

# Extract downloaded agent
Expand-Archive -Path "$env:USERPROFILE\Downloads\vsts-agent-win-x64-*.zip" -DestinationPath "C:\AzureAgent"
```

### **Step 3: Configure Agent**
```powershell
# Run configuration (interactive)
.\config.cmd

# When prompted, provide:
# Server URL: https://dev.azure.com/loic0161
# Authentication type: PAT (Personal Access Token)
# Personal access token: [You'll need to create this - see below]
# Agent pool: Default
# Agent name: [Accept default or customize]
# Work folder: [Accept default _work]
# Run as service: Y
```

### **Step 4: Create Personal Access Token (PAT)**
1. Go to Azure DevOps → Click your profile icon (top right)
2. Select **Personal access tokens**
3. Click **+ New Token**
4. Configure:
   - **Name**: `EasyPIM-Agent-Token`
   - **Expiration**: 90 days (or custom)
   - **Scopes**: Select **Agent Pools (read, manage)**
5. Click **Create** and **copy the token immediately**

### **Step 5: Install and Start Service**
```powershell
# Install as Windows service
.\svc.cmd install

# Start the service
.\svc.cmd start

# Verify status
.\svc.cmd status
```

### **Step 6: Verify Agent Registration**
1. Go back to Azure DevOps Agent pools page
2. Click **Default** pool
3. Go to **Agents** tab
4. You should see your agent listed as **Online**

## 🔧 Update Pipeline for Self-Hosted Agent

Once your agent is running, update the pipeline to use it:

```yaml
# Instead of:
pool:
  vmImage: 'windows-latest'

# Use:
pool: Default
# or
pool:
  name: Default
```

## ⚡ Quick Setup Script

Here's an automated setup script:
