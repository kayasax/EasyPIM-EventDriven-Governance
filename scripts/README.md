# Azure Resources Deployment Guide

This directory contains the infrastructure-as-code (IaC) templates and scripts to deploy all Azure resources required for EasyPIM CI/CD testing.

## 📁 Files Overview

- **`deploy-azure-resources.bicep`** - Main Bicep template defining all Azure resources
- **`deploy-azure-resources.ps1`** - PowerShell deployment script with helper functions
- **`deploy-azure-resources.parameters.json`** - Parameters file for customization
- **`README.md`** - This documentation file

## 🏗️ Resources Deployed

The Bicep template creates the following Azure resources:

### 🔐 Identity & Security
- **Azure AD Application** - Service principal for GitHub Actions authentication
- **Federated Identity Credential** - OIDC trust relationship with GitHub
- **Service Principal** - Identity used by CI/CD workflows

### 🔑 Key Vault
- **Azure Key Vault** - Secure storage for configuration and secrets
- **RBAC Role Assignments** - Appropriate permissions for service principal and administrators
- **Initial Secrets** - Tenant ID, Subscription ID, Client ID, and sample EasyPIM config

### 📋 Configuration
- **Sample EasyPIM Configuration** - Pre-configured JSON with policies and templates
- **Required Graph API Permissions** - Documented permissions for admin consent

## 🚀 Quick Deployment

### Prerequisites
- Azure CLI or PowerShell Az modules installed
- Appropriate Azure permissions (Contributor + User Access Administrator)
- GitHub repository created: `kayasax/EasyPIM-CICD-test`

### Option 1: PowerShell Script (Recommended)
```powershell
# Connect to Azure
Connect-AzAccount

# Run deployment script
.\deploy-azure-resources.ps1 -ResourceGroupName "rg-easypim-cicd-test" -GitHubRepository "kayasax/EasyPIM-CICD-test"
```

### Option 2: Azure CLI with Bicep
```bash
# Create resource group
az group create --name "rg-easypim-cicd-test" --location "East US"

# Deploy Bicep template
az deployment group create \
  --resource-group "rg-easypim-cicd-test" \
  --template-file deploy-azure-resources.bicep \
  --parameters @deploy-azure-resources.parameters.json \
  --parameters githubRepository="kayasax/EasyPIM-CICD-test"
```

### Option 3: Azure Portal
1. Upload the Bicep template to Azure Portal
2. Fill in the required parameters
3. Deploy to your resource group

## ⚙️ Configuration Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `resourcePrefix` | Prefix for all resource names | `easypim-cicd` | No |
| `environment` | Environment suffix (dev/test/prod) | `test` | No |
| `githubRepository` | GitHub repo in format: owner/repo | - | **Yes** |
| `githubEnvironment` | GitHub environment name | `""` (any) | No |
| `location` | Azure region | `East US` | No |
| `keyVaultAdministrators` | User/group IDs for Key Vault admin access | `[]` | No |

## 📋 Post-Deployment Steps

After successful deployment, you need to complete these steps:

### 1. Grant Admin Consent for Graph API Permissions
```bash
# Using Azure CLI
az ad app permission admin-consent --id <APPLICATION_ID>
```

Or in Azure Portal:
1. Go to **Azure Active Directory** > **App registrations**
2. Find your application (e.g., `easypim-cicd-test-sp`)
3. Go to **API permissions**
4. Click **Grant admin consent for [Tenant]**

### 2. Configure GitHub Repository Secrets
Add these secrets to your GitHub repository:

```
AZURE_CLIENT_ID: <service-principal-client-id>
AZURE_TENANT_ID: <tenant-id>
AZURE_SUBSCRIPTION_ID: <subscription-id>
```

### 3. Configure GitHub Repository Variables
Add these variables to your GitHub repository:

```
AZURE_KEYVAULT_NAME: <key-vault-name>
AZURE_RESOURCE_GROUP: <resource-group-name>
```

### 4. Update Key Vault Configuration
Replace the sample configuration in Key Vault with your actual settings:

1. Go to your Key Vault in Azure Portal
2. Update the `easypim-config-json` secret
3. Replace placeholder protected user IDs with actual user GUIDs
4. Customize policies and assignments as needed

## 🔍 Troubleshooting

### Common Issues

**Issue**: Bicep deployment fails with permissions error
**Solution**: Ensure you have both `Contributor` and `User Access Administrator` roles

**Issue**: Graph API permissions not working
**Solution**: Make sure admin consent was granted and wait a few minutes for propagation

**Issue**: GitHub Actions can't authenticate
**Solution**: Verify federated identity credential configuration and repository secrets

**Issue**: Key Vault access denied
**Solution**: Check RBAC role assignments and ensure service principal has `Key Vault Secrets User` role

### Validation Commands

```powershell
# Check deployment status
Get-AzResourceGroupDeployment -ResourceGroupName "rg-easypim-cicd-test"

# Verify service principal
Get-AzADServicePrincipal -DisplayName "easypim-cicd-test-sp"

# Test Key Vault access
Get-AzKeyVaultSecret -VaultName "<key-vault-name>" -Name "AZURE-TENANT-ID"

# Check federated credential
Get-AzADAppFederatedCredential -ApplicationId "<application-id>"
```

## 🧹 Cleanup

To remove all deployed resources:

```powershell
# Remove the entire resource group
Remove-AzResourceGroup -Name "rg-easypim-cicd-test" -Force
```

```bash
# Using Azure CLI
az group delete --name "rg-easypim-cicd-test" --yes --no-wait
```

**Note**: This will permanently delete all resources. The Azure AD application and service principal may need to be cleaned up separately.

## 📚 Additional Resources

- [EasyPIM Step 14 Documentation](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub OIDC with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Key Vault with GitHub Actions](https://docs.microsoft.com/en-us/azure/key-vault/general/github-action)
