// EasyPIM CI/CD Testing Infrastructure
// Deploys required Azure resources for secure GitHub Actions CI/CD testing
// Note: Azure AD Application and Service Principal must be created manually or via Azure CLI

// Parameters
@description('Name prefix for all resources')
param resourcePrefix string = 'easypim-cicd'

@description('Environment suffix (dev, test, prod)')
param environment string = 'test'

@description('GitHub repository name in format: owner/repo')
param githubRepository string

@description('Azure AD Application Client ID (must be created manually first)')
param azureClientId string = ''

@description('Key Vault access policies - additional users/groups with admin access')
param keyVaultAdministrators array = []

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {
  Project: 'EasyPIM-CICD-Testing'
  Environment: environment
  Purpose: 'CI-CD-Automation'
  CreatedBy: 'Bicep-Template'
}

// Variables
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var keyVaultName = '${resourcePrefix}-${environment}-kv-${uniqueSuffix}'

// Key Vault for secure configuration storage
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false // Disabled for testing environment
    networkAcls: {
      defaultAction: 'Allow' // Allow access from GitHub Actions
      bypass: 'AzureServices'
    }
    accessPolicies: [] // Using RBAC instead
  }
}

// Azure AD Application for GitHub Actions
resource application 'Microsoft.Graph/applications@v1.0' = {
  displayName: applicationName
  description: 'Service Principal for EasyPIM CI/CD GitHub Actions'
  tags: [
    'Environment=${environment}'
    'Purpose=CI-CD'
    'Repository=${githubRepository}'
  ]
  requiredResourceAccess: [
    {
      // Microsoft Graph
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        {
          // User.Read.All
          id: 'df021288-bdef-4463-88db-98f22de89214'
          type: 'Role'
        }
        {
          // RoleManagement.ReadWrite.Directory
          id: '9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8'
          type: 'Role'
        }
        {
          // PrivilegedAccess.ReadWrite.AzureResources
          id: 'a84a9652-ffd3-496e-a991-22078a99a34b'
          type: 'Role'
        }
      ]
    }
  ]
  web: {
    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: false
    }
  }
  api: {
    acceptMappedClaims: true
  }
}

// Service Principal for the Application
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: application.appId
  displayName: servicePrincipalName
  description: 'Service Principal for EasyPIM CI/CD operations'
  tags: [
    'Environment=${environment}'
    'Purpose=CI-CD'
  ]
}

// Federated Identity Credential for GitHub Actions
resource federatedCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  parent: application
  name: 'github-actions-${environment}'
  audiences: ['api://AzureADTokenExchange']
  issuer: 'https://token.actions.githubusercontent.com'
  subject: empty(githubEnvironment)
    ? 'repo:${githubRepository}:ref:refs/heads/main'
    : 'repo:${githubRepository}:environment:${githubEnvironment}'
  description: 'GitHub Actions OIDC for ${githubRepository}'
}

// Role Assignment: Key Vault Secrets User for Service Principal
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, servicePrincipal.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: servicePrincipal.id
    principalType: 'ServicePrincipal'
    description: 'Allow EasyPIM CI/CD to read secrets from Key Vault'
  }
}

// Role Assignment: Key Vault Administrator for specified users/groups
resource kvAdminRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (admin, index) in keyVaultAdministrators: {
  name: guid(keyVault.id, admin, 'Key Vault Administrator', string(index))
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: admin
    principalType: 'User' // Adjust if you need groups
    description: 'Administrative access to Key Vault for EasyPIM CI/CD'
  }
}]

// Store essential configuration in Key Vault
resource secretTenantId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-TENANT-ID'
  properties: {
    value: tenant().tenantId
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  tags: tags
}

resource secretSubscriptionId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-SUBSCRIPTION-ID'
  properties: {
    value: subscription().subscriptionId
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  tags: tags
}

resource secretClientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-CLIENT-ID'
  properties: {
    value: application.appId
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  tags: tags
}

// Sample EasyPIM configuration stored in Key Vault
resource secretPimConfig 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'easypim-config-json'
  properties: {
    value: string({
      ProtectedUsers: [
        '00000000-0000-0000-0000-000000000001' // Replace with actual protected user IDs
      ]
      PolicyTemplates: {
        Standard: {
          ActivationDuration: 'PT8H'
          ActivationRequirement: 'MultiFactorAuthentication,Justification'
          ApprovalRequired: false
          MaxActivationDuration: 'PT8H'
          EligibilityExpiration: 'P365D'
        }
        Restricted: {
          ActivationDuration: 'PT4H'
          ActivationRequirement: 'MultiFactorAuthentication,Justification'
          ApprovalRequired: true
          MaxActivationDuration: 'PT4H'
          EligibilityExpiration: 'P180D'
        }
      }
      EntraRoles: {
        Policies: {
          'User Administrator': {
            Template: 'Standard'
          }
          'Groups Administrator': {
            Template: 'Restricted'
          }
        }
      }
      AzureRoles: {
        Policies: {}
      }
      Assignments: {
        EntraRoles: []
        AzureRoles: []
      }
    })
    contentType: 'application/json'
    attributes: {
      enabled: true
    }
  }
  tags: tags
}

// Outputs for GitHub repository configuration
output servicePrincipalClientId string = application.appId
output servicePrincipalObjectId string = servicePrincipal.id
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output resourceGroupName string = resourceGroup().name

// GitHub Secrets Configuration (for documentation)
output githubSecretsConfiguration object = {
  AZURE_CLIENT_ID: application.appId
  AZURE_TENANT_ID: tenant().tenantId
  AZURE_SUBSCRIPTION_ID: subscription().subscriptionId
}

output githubVariablesConfiguration object = {
  AZURE_KEYVAULT_NAME: keyVault.name
  AZURE_RESOURCE_GROUP: resourceGroup().name
}

// Required Graph API Permissions (for manual admin consent)
output requiredGraphPermissions array = [
  {
    permission: 'User.Read.All'
    type: 'Application'
    description: 'Read all user profiles'
  }
  {
    permission: 'RoleManagement.ReadWrite.Directory'
    type: 'Application'
    description: 'Read and write directory roles'
  }
  {
    permission: 'PrivilegedAccess.ReadWrite.AzureResources'
    type: 'Application'
    description: 'Read and write PIM for Azure resources'
  }
]

// Post-deployment configuration instructions
output postDeploymentInstructions array = [
  '1. Grant admin consent for Graph API permissions in Azure Portal'
  '2. Configure GitHub repository secrets with the provided values'
  '3. Configure GitHub repository variables with the provided values'
  '4. Update Key Vault secrets with your actual protected user IDs'
  '5. Customize the EasyPIM configuration in Key Vault as needed'
  '6. Test the GitHub Actions workflow with authentication-only operations first'
]
