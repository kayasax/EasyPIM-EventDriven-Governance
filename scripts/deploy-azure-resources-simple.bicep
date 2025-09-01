// EasyPIM CI/CD Infrastructure - Azure Resources Only
// This template creates Azure resources for EasyPIM CI/CD testing
// Note: Azure AD Application and Service Principal are created via Azure CLI

targetScope = 'resourceGroup'

@description('Key Vault name')
param keyVaultName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Environment suffix')
param environmentSuffix string = 'test'

@description('Object ID of the current user (for Key Vault access)')
param currentUserObjectId string

@description('Object ID of the service principal (for Key Vault access)')
param servicePrincipalObjectId string

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
  name: guid(keyVault.id, servicePrincipalObjectId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
output resourceGroupName string = resourceGroup().name
