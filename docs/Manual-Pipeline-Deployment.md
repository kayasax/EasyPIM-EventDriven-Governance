# 🚀 Manual Azure DevOps Pipeline Deployment Guide

## 📋 Problem Solved: No More Git Authentication Prompts!

To avoid continuous git credential prompts, use this manual approach instead of automated git operations.

## ✅ Available Pipeline Templates

Your templates are ready in: `templates/`

1. **azure-pipelines-auth-test.yml** - Authentication & module testing (FIXED for no parallelism)
2. **azure-pipelines-orchestrator.yml** - Main PIM policy execution
3. **azure-pipelines-drift-detection.yml** - Policy drift detection

## 🎯 Quick Deployment Steps

### Step 1: Open Azure DevOps
Go to: https://dev.azure.com/loic0161/EasyPIM-CICD/_build

### Step 2: Create New Pipeline
1. Click **"New Pipeline"**
2. Select **"Azure Repos Git"**
3. Choose repository: **"EasyPIM-CICD"**
4. Select **"Starter pipeline"** (we'll replace the content)

### Step 3: Replace Pipeline Content
1. **Delete** the default YAML content
2. **Copy** content from one of your local template files
3. **Paste** into the Azure DevOps editor
4. Click **"Save and run"**

### Step 4: Repeat for Each Template
Create 3 separate pipelines:
- **EasyPIM-01-Auth-Test** (using azure-pipelines-auth-test.yml)
- **EasyPIM-02-Policy-Orchestrator** (using azure-pipelines-orchestrator.yml)
- **EasyPIM-03-Drift-Detection** (using azure-pipelines-drift-detection.yml)

## 🔧 Authentication Test Pipeline Fixed

The authentication test pipeline has been **fixed to avoid parallelism issues**:
- ✅ **No parallel jobs** - single job with sequential steps
- ✅ **Ultra-minimal structure** - no stages, no complex configurations
- ✅ **Works with free Azure DevOps tier** - no hosted parallelism needed

## 📄 Template Content Preview

### Authentication Test (Fixed)
```yaml
# Azure DevOps Pipeline: EasyPIM Authentication Test
# Ultra-minimal structure to bypass parallelism requirements

trigger: none

variables:
- group: EasyPIM-EventDriven-Governance

steps:
- task: AzureCLI@2
  displayName: 'EasyPIM Authentication Test'
  inputs:
    azureSubscription: 'EasyPIM-Azure-Connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      echo "🔍 Testing Azure CLI authentication..."
      # ... complete test content
```

## 🎉 Benefits of Manual Approach

- ✅ **No git authentication prompts**
- ✅ **No credential manager popups**
- ✅ **Full control over pipeline creation**
- ✅ **Can customize templates before deployment**
- ✅ **Works with any authentication setup**

## 🔄 Alternative: Copy via File Explorer

1. **Open Azure DevOps repository**: https://dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD
2. **Create** a `templates` folder in the web interface
3. **Upload** your template files via the web interface
4. **Create pipelines** pointing to the uploaded templates

This approach completely avoids any git authentication issues while giving you full control over the deployment process!
