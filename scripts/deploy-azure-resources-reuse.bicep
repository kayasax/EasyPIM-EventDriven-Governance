// EasyPIM CI/CD Infrastructure - Reuse Existing Resources Version
// Deploys Azure resources for EasyPIM Event-Driven Governance
// Modified to reuse existing resources when provided

// Parameters
@description('Name prefix for all resources')
param resourcePrefix string = 'easypim-cicd'

@description('Environment suffix (dev, test, prod)')
param environment string = 'test'

@description('GitHub repository name in format: owner/repo')
param githubRepository string

@description('Azure AD Application Client ID (create separately with Azure CLI - optional for template)')
param azureClientId string = ''

@description('Key Vault access policies - additional users/groups with admin access (future use)')
param keyVaultAdministrators array = []

@description('Existing Key Vault name to reuse (if provided, skips creation)')
param existingKeyVaultName string = ''

@description('Existing Storage Account name to reuse (if provided, skips creation)')
param existingStorageAccountName string = ''

@description('Existing Function App name to reuse (if provided, skips creation)')
param existingFunctionAppName string = ''

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {
  Project: 'EasyPIM-EventDriven-Governance'
  Environment: environment
  Purpose: 'CI-CD-Automation'
  CreatedBy: 'Bicep-Template'
  Repository: githubRepository
}

// Variables
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var keyVaultName = empty(existingKeyVaultName) ? 'kv${replace(resourcePrefix, '-', '')}${environment}${uniqueSuffix}' : existingKeyVaultName
var storageAccountName = empty(existingStorageAccountName) ? '${replace(resourcePrefix, '-', '')}${environment}st${uniqueSuffix}' : existingStorageAccountName
var functionAppName = empty(existingFunctionAppName) ? '${resourcePrefix}-${environment}-func-${uniqueSuffix}' : existingFunctionAppName
var applicationInsightsName = '${resourcePrefix}-${environment}-ai-${uniqueSuffix}'
var logAnalyticsWorkspaceName = '${resourcePrefix}-${environment}-law-${uniqueSuffix}'

// Always create these resources (they're typically lightweight and project-specific)
// Log Analytics Workspace for monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights for monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
  }
}

// Conditionally create Key Vault only if not using existing
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = if (empty(existingKeyVaultName)) {
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
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Reference existing Key Vault if provided
resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!empty(existingKeyVaultName)) {
  name: existingKeyVaultName
}

// Conditionally create Storage Account only if not using existing
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (empty(existingStorageAccountName)) {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Reference existing Storage Account if provided
resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (!empty(existingStorageAccountName)) {
  name: existingStorageAccountName
}

// Only create Function App if not using existing (Function Apps are more complex to reuse)
resource functionApp 'Microsoft.Web/sites@2023-12-01' = if (empty(existingFunctionAppName)) {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: empty(existingStorageAccountName) ?
            'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}' :
            'DefaultEndpointsProtocol=https;AccountName=${existingStorageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${listKeys(existingStorageAccount.id, existingStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: empty(existingStorageAccountName) ?
            'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}' :
            'DefaultEndpointsProtocol=https;AccountName=${existingStorageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${listKeys(existingStorageAccount.id, existingStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'GITHUB_REPOSITORY'
          value: githubRepository
        }
      ]
    }
  }
}

// Outputs for use in CI/CD pipelines and other resources
output keyVaultName string = keyVaultName
output keyVaultId string = empty(existingKeyVaultName) ? keyVault.id : existingKeyVault.id
output storageAccountName string = storageAccountName
output storageAccountId string = empty(existingStorageAccountName) ? storageAccount.id : existingStorageAccount.id
output functionAppName string = functionAppName
output functionAppId string = empty(existingFunctionAppName) ? functionApp.id : '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${existingFunctionAppName}'
output functionAppPrincipalId string = empty(existingFunctionAppName) ? functionApp.identity.principalId : 'existing-function-app'
output applicationInsightsName string = applicationInsights.name
output applicationInsightsId string = applicationInsights.id
output resourceGroupName string = resourceGroup().name
output subscriptionId string = subscription().subscriptionId
output tenantId string = tenant().tenantId
