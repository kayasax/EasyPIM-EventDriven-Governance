// EasyPIM CI/CD Infrastructure - Azure Resources
// This template creates the required Azure resources for EasyPIM CI/CD testing

targetScope = 'resourceGroup'

// Import Microsoft Graph extension for Entra ID resources
extension microsoftGraphV1

@description('Name of the Azure Application')
param applicationName string = 'EasyPIM-CI-CD-Test'

@description('GitHub repository in format owner/repo')
param gitHubRepository string

@description('Branch name for OIDC federation')
param branchName string = 'main'

@description('Key Vault name')
param keyVaultName string = 'kv-easypim-${uniqueString(resourceGroup().id)}'

@description('Location for resources')
param location string = resourceGroup().location

@description('Environment suffix')
param environmentSuffix string = 'test'

@description('Object ID of the current user (for Key Vault access)')
param currentUserObjectId string

// Variables
var federatedCredentialName = 'GitHub-${branchName}-federation'
var gitHubSubject = 'repo:${gitHubRepository}:ref:refs/heads/${branchName}'

// Create Azure AD Application
resource azureApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: applicationName
  description: 'Application for EasyPIM CI/CD testing with OIDC federation'
  signInAudience: 'AzureADMyOrg'
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
      resourceAccess: [
        {
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
          type: 'Scope'
        }
        {
          id: '19dbc75e-c2e2-444c-a770-ec69d8559fc7' // Directory.ReadWrite.All
          type: 'Role'
        }
        {
          id: '1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9' // Application.ReadWrite.All
          type: 'Role'
        }
        {
          id: '9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8' // RoleManagement.ReadWrite.Directory
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
    acceptMappedClaims: false
    knownClientApplications: []
    preAuthorizedApplications: []
    requestedAccessTokenVersion: 2
  }
}

// Create Service Principal for the application
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: azureApp.appId
  displayName: applicationName
  servicePrincipalType: 'Application'
  accountEnabled: true

  dependsOn: [azureApp]
}

// Create federated credential for GitHub OIDC
resource federatedCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  parent: azureApp
  name: federatedCredentialName
  audiences: ['api://AzureADTokenExchange']
  description: 'GitHub OIDC federation for CI/CD'
  issuer: 'https://token.actions.githubusercontent.com'
  subject: gitHubSubject
}

// Create Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  tags: {
    Environment: environmentSuffix
    Purpose: 'EasyPIM-CI-CD-Testing'
  }
}

// Key Vault Secret Officer role for current user
resource keyVaultSecretOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, currentUserObjectId, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

// Key Vault Secrets User role for service principal
resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, servicePrincipal.id, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: servicePrincipal.id
    principalType: 'ServicePrincipal'
  }

  dependsOn: [servicePrincipal]
}

// Contributor role for service principal (for EasyPIM operations)
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, servicePrincipal.id, 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: servicePrincipal.id
    principalType: 'ServicePrincipal'
  }

  dependsOn: [servicePrincipal]
}

// Outputs for GitHub secrets and environment variables
output applicationId string = azureApp.appId
output servicePrincipalId string = servicePrincipal.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
output resourceGroupName string = resourceGroup().name
output gitHubSecrets object = {
  AZURE_CLIENT_ID: azureApp.appId
  AZURE_TENANT_ID: subscription().tenantId
  AZURE_SUBSCRIPTION_ID: subscription().subscriptionId
  AZURE_RESOURCE_GROUP: resourceGroup().name
  AZURE_KEY_VAULT_NAME: keyVault.name
  AZURE_KEY_VAULT_URI: keyVault.properties.vaultUri
}
