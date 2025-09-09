// EasyPIM CI/CD Infrastructure - Simple Resource Creation
// Creates only missing resources, skips existing ones via parameters

// Parameters
@description('Name prefix for all resources')
param resourcePrefix string = 'easypim-cicd'

@description('Environment suffix (dev, test, prod)')
param environment string = 'test'

@description('GitHub repository name in format: owner/repo')
param githubRepository string

@description('Storage Account name to use for Function App')
param storageAccountName string

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
var applicationInsightsName = '${resourcePrefix}-${environment}-ai-${uniqueSuffix}'
var logAnalyticsWorkspaceName = '${resourcePrefix}-${environment}-law-${uniqueSuffix}'

// Always create these resources (they're lightweight and project-specific)
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

// Reference existing storage account
resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Outputs for use in CI/CD pipelines and other resources
output storageAccountName string = existingStorageAccount.name
output storageAccountId string = existingStorageAccount.id
output applicationInsightsName string = applicationInsights.name
output applicationInsightsId string = applicationInsights.id
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output resourceGroupName string = resourceGroup().name
output subscriptionId string = subscription().subscriptionId
output tenantId string = tenant().tenantId
