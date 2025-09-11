# Test just the Set-AzureDevOpsConfiguration function to find the syntax issue
function Set-AzureDevOpsConfiguration {
    param(
        [string]$Organization,
        [string]$Project,
        [hashtable]$Outputs,
        [bool]$Force
    )

    Write-Host "🔧 Configuring Azure DevOps for project: $Organization/$Project" -ForegroundColor Cyan

    $orgUrl = "https://dev.azure.com/$Organization"

    # Define variables to set (Azure DevOps uses variables for both secrets and regular values)
    $variables = @{
        "AZURE_TENANT_ID" = @{ value = $Outputs.TenantId; isSecret = $true }
        "AZURE_SUBSCRIPTION_ID" = @{ value = $Outputs.SubscriptionId; isSecret = $true }
        "AZURE_CLIENT_ID" = @{ value = $Outputs.ClientId; isSecret = $true }
        "AZURE_RESOURCE_GROUP" = @{ value = $Outputs.ResourceGroup; isSecret = $false }
        "AZURE_KEY_VAULT_NAME" = @{ value = $Outputs.KeyVaultName; isSecret = $false }
        "AZURE_KEY_VAULT_URI" = @{ value = $Outputs.KeyVaultUri; isSecret = $false }
        "EASYPIM_SECRET_NAME" = @{ value = $Outputs.SecretName; isSecret = $false }
    }

    $variableGroupName = "EasyPIM-Variables"

    Write-Host "   📝 Creating/updating variable group: $variableGroupName" -ForegroundColor Gray

    try {
        # Check if variable group exists
        $existingGroup = az pipelines variable-group list --organization $orgUrl --project $Project --group-name $variableGroupName 2>$null | ConvertFrom-Json

        if ($existingGroup -and $existingGroup.Count -gt 0) {
            $groupId = $existingGroup[0].id
            Write-Host "      ✅ Found existing variable group (ID: $groupId)" -ForegroundColor Green

            # Update existing variables
            foreach ($variable in $variables.GetEnumerator()) {
                try {
                    if ($variable.Value.isSecret) {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value --secret $true 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            # Variable might exist, try to update
                            az pipelines variable-group variable update --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value --secret $true 2>$null
                        }
                    } else {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            # Variable might exist, try to update
                            az pipelines variable-group variable update --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value 2>$null
                        }
                    }
                    Write-Host "      ✅ $($variable.Key)" -ForegroundColor Green
                }
                catch {
                    Write-Host "      ❌ Failed to set $($variable.Key): $_" -ForegroundColor Red
                }
            }
        } else {
            # Create new variable group
            Write-Host "      📋 Creating new variable group..." -ForegroundColor Gray

            # Create the variable group first
            $newGroup = az pipelines variable-group create --organization $orgUrl --project $Project --name $variableGroupName --description "EasyPIM Event-Driven Governance CI/CD Variables" | ConvertFrom-Json
            $groupId = $newGroup.id

            # Add variables to the new group
            foreach ($variable in $variables.GetEnumerator()) {
                try {
                    if ($variable.Value.isSecret) {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value --secret $true
                    } else {
                        az pipelines variable-group variable create --organization $orgUrl --project $Project --group-id $groupId --name $variable.Key --value $variable.Value.value
                    }
                    Write-Host "      ✅ $($variable.Key)" -ForegroundColor Green
                }
                catch {
                    Write-Host "      ❌ Failed to set $($variable.Key): $_" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "      ❌ Failed to configure variable group: $_" -ForegroundColor Red
        return
    }

    # Configure Azure DevOps OIDC authentication
    Write-Host "   🔐 Setting up Azure DevOps OIDC authentication..." -ForegroundColor Gray
    try {
        # Add federated identity credential for Azure DevOps
        $adoSubject = "sc://$Organization/$Project"
        $adoIssuer = "https://vstoken.dev.azure.com/$Organization"

        # Check if OIDC credential already exists
        $existingCreds = az ad app federated-credential list --id $Outputs.ClientId | ConvertFrom-Json
        $adoCredExists = $existingCreds | Where-Object { $_.subject -eq $adoSubject }

        if (-not $adoCredExists) {
            Write-Host "      📝 Creating Azure DevOps OIDC credential..." -ForegroundColor Gray

            # Create temporary JSON file for the credential
            $credentialJson = @{
                name = "azuredevops-$Organization-$Project"
                issuer = $adoIssuer
                subject = $adoSubject
                description = "Azure DevOps OIDC for $Organization/$Project"
                audiences = @("api://AzureADTokenExchange")
            } | ConvertTo-Json -Depth 10

            $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
            $credentialJson | Out-File -FilePath $tempFile -Encoding UTF8

            az ad app federated-credential create --id $Outputs.ClientId --parameters $tempFile
            Remove-Item $tempFile -Force

            Write-Host "      ✅ Azure DevOps OIDC credential created" -ForegroundColor Green
        } else {
            Write-Host "      ✅ Azure DevOps OIDC credential already exists" -ForegroundColor Green
        }

        # Create Azure DevOps Service Connection
        Write-Host "      🔗 Creating Azure DevOps service connection..." -ForegroundColor Gray

        $serviceConnectionName = "EasyPIM-Azure-Connection"

        # Check if service connection already exists
        $existingConnections = az devops service-endpoint list --organization $orgUrl --project $Project | ConvertFrom-Json
        $connectionExists = $existingConnections | Where-Object { $_.name -eq $serviceConnectionName }

        if (-not $connectionExists) {
            # Create service connection with OIDC
            $serviceConnectionConfig = @{
                name = $serviceConnectionName
                type = "AzureRM"
                url = "https://management.azure.com/"
                description = "EasyPIM Azure connection using OIDC authentication"
                authorization = @{
                    parameters = @{
                        tenantid = $Outputs.TenantId
                        serviceprincipalid = $Outputs.ClientId
                    }
                    scheme = "WorkloadIdentityFederation"
                }
                serviceEndpointProjectReferences = @(
                    @{
                        projectReference = @{
                            id = (az devops project show --project $Project --organization $orgUrl --query 'id' -o tsv)
                            name = $Project
                        }
                        name = $serviceConnectionName
                    }
                )
                data = @{
                    subscriptionId = $Outputs.SubscriptionId
                    subscriptionName = "EasyPIM Subscription"
                    environment = "AzureCloud"
                    scopeLevel = "Subscription"
                    creationMode = "Manual"
                }
            } | ConvertTo-Json -Depth 10

            $tempConnectionFile = [System.IO.Path]::GetTempFileName() + ".json"
            $serviceConnectionConfig | Out-File -FilePath $tempConnectionFile -Encoding UTF8

            az devops service-endpoint create --service-endpoint-configuration $tempConnectionFile --organization $orgUrl --project $Project
            Remove-Item $tempConnectionFile -Force

            Write-Host "      ✅ Service connection '$serviceConnectionName' created" -ForegroundColor Green
        } else {
            Write-Host "      ✅ Service connection '$serviceConnectionName' already exists" -ForegroundColor Green
        }

    }
    catch {
        Write-Host "      ⚠️  OIDC setup encountered an issue: $_" -ForegroundColor Yellow
    }

    Write-Host "✅ Test completed!" -ForegroundColor Green
}

# Test the function
Write-Host "Testing function syntax..." -ForegroundColor Cyan
