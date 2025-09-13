// EasyPIM Event-Driven Governance - Azure Infrastructure Template
// This Bicep template deploys all required Azure resources for EasyPIM CI/CD integration

@description('Prefix for all resource names')
param resourcePrefix string = 'easypim'

@description('Environment name (e.g., dev, staging, prod)')
param environment string = 'prod'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('GitHub repository (format: owner/repo)')
param gitHubRepo string

@description('GitHub branch for OIDC trust')
param gitHubBranch string = 'main'

@description('Tenant ID for initial configuration')
param tenantId string = subscription().tenantId

@description('Subscription ID for initial configuration')
param subscriptionId string = subscription().subscriptionId

@description('Your Azure AD object ID for initial Key Vault access')
param adminObjectId string

@description('Service Principal Client ID (if already created)')
param clientId string = ''

// Variables
var resourceToken = uniqueString(resourceGroup().id)
var keyVaultName = 'kv-${resourcePrefix}-${resourceToken}'

// Key Vault for storing configuration and secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: {
    'azd-env-name': environment
    purpose: 'EasyPIM-Configuration'
  }
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: adminObjectId
        permissions: {
          secrets: ['all']
          keys: ['all']
          certificates: ['all']
        }
      }
    ]
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
  }
}

// Store essential configuration in Key Vault
resource tenantIdSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-TENANT-ID'
  properties: {
    value: tenantId
  }
}

resource subscriptionIdSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-SUBSCRIPTION-ID'
  properties: {
    value: subscriptionId
  }
}

resource clientIdSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (clientId != '') {
  parent: keyVault
  name: 'AZURE-CLIENT-ID'
  properties: {
    value: clientId
  }
}

resource gitHubRepoSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'GITHUB-REPOSITORY'
  properties: {
    value: gitHubRepo
  }
}

// Sample EasyPIM configuration
resource easyPimConfig 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'easypim-config-json'
  properties: {
    contentType: 'application/json'
    value: '''
{
  "version": "1.0",
  "description": "EasyPIM Configuration for CI/CD Integration",
  "policies": [
    {
      "name": "Global-Admins-JIT",
      "displayName": "Global Administrator - Just-In-Time Access",
      "roleDefinitionId": "62e90394-69f5-4237-9190-012177145e10",
      "principalType": "Group",
      "assignmentType": "Eligible",
      "maxActivationDuration": "PT8H",
      "requireJustification": true,
      "requireApproval": false,
      "requireMFA": true
    }
  ],
  "settings": {
    "enableAuditLogs": true,
    "notificationSettings": {
      "enableEmailNotifications": true
    }
  }
}
'''
  }
}

// Outputs for use in CI/CD pipelines
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output resourceGroupName string = resourceGroup().name
output subscriptionId string = subscriptionId
output tenantId string = tenantId
output gitHubRepository string = gitHubRepo

// Configuration output for pipeline setup
output pipelineConfiguration object = {
  keyVaultName: keyVault.name
  secretName: 'easypim-config-json'
  serviceConnection: 'EasyPIM-Azure-Connection'
  environment: environment
  gitHubRepo: gitHubRepo
  gitHubBranch: gitHubBranch
}
