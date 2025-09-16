# Enhanced Azure Function - Multi-Platform Event Routing
# This script extends your existing Function App to support both GitHub Actions and Azure DevOps pipeline triggering

param($req, $TriggerMetadata)

$body = $req.Body
try {
    # Handle different body formats (existing logic)
    if ($body -is [string]) {
        if ($body.StartsWith('{') -or $body.StartsWith('[')) {
            $eventData = $body | ConvertFrom-Json
        } else {
            Write-Host "Received non-JSON body: $body"
            $eventData = @{ eventType = "Unknown"; data = @{} }
        }
    } else {
        $eventData = $body
    }

    $eventType = $eventData.eventType
    $eventData | Out-String | Write-Host
} catch {
    Write-Error "Failed to parse eventGridEvent: $_"
    $body | Out-String | Write-Host
    $eventData = @{ eventType = "Unknown"; data = @{} }
    $eventType = "Unknown"
}

# Handle Event Grid subscription validation event (existing logic)
if ($eventType -eq 'Microsoft.EventGrid.SubscriptionValidationEvent') {
    $validationCode = $eventData.data.validationCode
    Write-Host "Responding to EventGrid validation: $validationCode"

    $validationResponse = @{ validationResponse = $validationCode }
    Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
        StatusCode = 200
        Headers = @{ "Content-Type" = "application/json" }
        Body = ($validationResponse | ConvertTo-Json)
    })
    return
}

# Extract information from Key Vault event
$secretName = "Unknown"
$vaultName = "Unknown"
if ($eventData.data) {
    if ($eventData.data.ObjectName) { $secretName = $eventData.data.ObjectName }
    if ($eventData.data.VaultName) { $vaultName = $eventData.data.VaultName }
}

Write-Host "🔍 Processing Key Vault event for secret: $secretName in vault: $vaultName"

# 🚀 NEW: Platform routing logic based on secret name
$targetPlatform = "github"  # default to existing behavior

if ($secretName -match "ado|azdo|devops") {
    $targetPlatform = "azuredevops"
    Write-Host "📊 Detected Azure DevOps pattern in secret name: $secretName"
} else {
    Write-Host "📊 Using default GitHub Actions platform for secret: $secretName"
}

Write-Host "🎯 Routing to platform: $targetPlatform"

# Route to appropriate platform
switch ($targetPlatform) {
    "github" {
        $result = TriggerGitHubActions -SecretName $secretName -VaultName $vaultName
    }
    "azuredevops" {
        $result = TriggerAzureDevOpsPipeline -SecretName $secretName -VaultName $vaultName
    }
    default {
        Write-Error "❌ Unknown platform: $targetPlatform"
        Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
            StatusCode = 400
            Headers = @{ "Content-Type" = "application/json" }
            Body = "Unknown target platform: $targetPlatform"
        })
        return
    }
}

# Return success response
if ($result.success) {
    Write-Host "✅ Platform trigger successful for $targetPlatform"
    Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
        StatusCode = 200
        Headers = @{ "Content-Type" = "application/json" }
        Body = "Event processed successfully - triggered $targetPlatform"
    })
} else {
    Write-Host "❌ Platform trigger failed for $targetPlatform`: $($result.error)"
    Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
        StatusCode = 500
        Headers = @{ "Content-Type" = "application/json" }
        Body = "Failed to trigger $targetPlatform`: $($result.error)"
    })
}

#region GitHub Actions Trigger (existing logic, now refactored into function)
function TriggerGitHubActions {
    param(
        [string]$SecretName,
        [string]$VaultName
    )
    
    Write-Host "🚀 Triggering GitHub Actions workflow..."
    
    # Get GitHub token from environment variable
    $token = $env:GITHUB_TOKEN
    if (-not $token) {
        Write-Error "GITHUB_TOKEN environment variable not set"
        return @{ success = $false; error = "Missing GitHub token" }
    }

    $repo = "kayasax/EasyPIM-EventDriven-Governance"
    $workflow = "02-orchestrator-test.yml"

    # Build intelligent workflow inputs (existing logic)
    $workflowInputs = @{
        configSecretName = $SecretName  # Pass the secret name to the workflow
        run_description = "Triggered by Key Vault secret change: $SecretName in $VaultName"
        WhatIf = $false
        Mode = "delta"
        SkipPolicies = $false
        SkipAssignments = $false
        AllowProtectedRoles = $false
        Verbose = $false
        ExportWouldRemove = $true
    }

    # Smart parameter detection based on secret name (existing logic)
    if ($SecretName -match "test|debug") {
        $workflowInputs.WhatIf = $true  # Use preview mode for test secrets
        $workflowInputs.run_description += " (Test Mode - Preview Only)"
    }

    if ($SecretName -match "initial|setup|bootstrap") {
        $workflowInputs.Mode = "initial"  # Use initial mode for setup secrets
        $workflowInputs.run_description += " (Initial Setup Mode)"
    }

    # Environment variable overrides (existing logic)
    $customWhatIf = $env:EASYPIM_WHATIF
    $customMode = $env:EASYPIM_MODE
    $customVerbose = $env:EASYPIM_VERBOSE

    if ($null -ne $customWhatIf) {
        $workflowInputs.WhatIf = [System.Convert]::ToBoolean($customWhatIf)
    }
    if ($null -ne $customMode -and $customMode -in @("delta", "initial")) {
        $workflowInputs.Mode = $customMode
    }
    if ($null -ne $customVerbose) {
        $workflowInputs.Verbose = [System.Convert]::ToBoolean($customVerbose)
    }

    Write-Host "📋 GitHub Actions Parameters:" -ForegroundColor Blue
    $workflowInputs | ConvertTo-Json -Depth 2 | Write-Host

    # GitHub API call (existing logic)
    $body = @{
        ref = "main"
        inputs = $workflowInputs
    } | ConvertTo-Json -Depth 3

    $headers = @{
        "Authorization" = "token $token"
        "Accept" = "application/vnd.github.v3+json"
        "Content-Type" = "application/json"
    }

    try {
        $apiUrl = "https://api.github.com/repos/$repo/actions/workflows/$workflow/dispatches"
        Write-Host "🌐 Calling GitHub API: $apiUrl"
        
        Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $body
        
        Write-Host "✅ GitHub Actions workflow triggered successfully!"
        return @{ success = $true; platform = "github" }
    }
    catch {
        Write-Error "❌ Failed to trigger GitHub Actions: $($_.Exception.Message)"
        return @{ success = $false; error = $_.Exception.Message }
    }
}
#endregion

#region Azure DevOps Pipeline Trigger (new functionality)
function TriggerAzureDevOpsPipeline {
    param(
        [string]$SecretName,
        [string]$VaultName
    )
    
    Write-Host "🚀 Triggering Azure DevOps pipeline..."
    
    # Azure DevOps configuration from environment variables
    $adoOrganization = $env:ADO_ORGANIZATION
    $adoProject = $env:ADO_PROJECT
    $adoPipeline = $env:ADO_PIPELINE_ID
    $adoToken = $env:ADO_PAT
    
    if (-not $adoToken) {
        Write-Error "ADO_PAT environment variable not set"
        return @{ success = $false; error = "Missing Azure DevOps PAT token" }
    }
    
    if (-not $adoOrganization -or -not $adoProject -or -not $adoPipeline) {
        Write-Error "Missing Azure DevOps configuration: ADO_ORGANIZATION, ADO_PROJECT, or ADO_PIPELINE_ID"
        return @{ success = $false; error = "Missing Azure DevOps configuration" }
    }
    
    # Build intelligent pipeline parameters (same logic as GitHub Actions)
    $pipelineParameters = @{
        "configSecretName" = $SecretName
        "whatIfMode" = ($SecretName -match "test|debug|dev").ToString().ToLower()
        "mode" = if ($SecretName -match "initial|setup") { "initial" } else { "delta" }
        "verbose" = ($SecretName -match "verbose|debug").ToString().ToLower()
        "runDescription" = "Triggered by Key Vault secret change: $SecretName in $VaultName"
    }
    
    # Apply the same smart parameter detection as GitHub Actions
    if ($SecretName -match "test|debug") {
        $pipelineParameters.runDescription += " (Test Mode - Preview Only)"
    }
    
    if ($SecretName -match "initial|setup|bootstrap") {
        $pipelineParameters.runDescription += " (Initial Setup Mode)"
    }
    
    # Environment variable overrides (same logic as GitHub Actions)
    if ($env:EASYPIM_WHATIF) { $pipelineParameters.whatIfMode = $env:EASYPIM_WHATIF.ToLower() }
    if ($env:EASYPIM_MODE) { $pipelineParameters.mode = $env:EASYPIM_MODE }
    if ($env:EASYPIM_VERBOSE) { $pipelineParameters.verbose = $env:EASYPIM_VERBOSE.ToLower() }
    
    Write-Host "📋 Azure DevOps Parameters:" -ForegroundColor Blue
    $pipelineParameters | ConvertTo-Json -Depth 2 | Write-Host
    
    # Azure DevOps REST API call
    $apiUrl = "https://dev.azure.com/$adoOrganization/$adoProject/_apis/pipelines/$adoPipeline/runs?api-version=7.0"
    
    $body = @{
        resources = @{
            repositories = @{
                self = @{
                    refName = "refs/heads/main"
                }
            }
        }
        templateParameters = $pipelineParameters
    } | ConvertTo-Json -Depth 4
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$adoToken"))
        "Content-Type" = "application/json"
    }
    
    try {
        Write-Host "🌐 Calling Azure DevOps API: $apiUrl"
        Write-Host "🔧 Pipeline ID: $adoPipeline in $adoOrganization/$adoProject"
        
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body -Headers $headers
        
        Write-Host "✅ Azure DevOps pipeline triggered successfully!"
        Write-Host "📊 Run ID: $($response.id)"
        if ($response._links -and $response._links.web -and $response._links.web.href) {
            Write-Host "🔗 Pipeline URL: $($response._links.web.href)"
        }
        
        return @{
            success = $true
            platform = "azuredevops"
            runId = $response.id
            runUrl = $response._links.web.href
        }
    }
    catch {
        Write-Error "❌ Failed to trigger Azure DevOps pipeline: $($_.Exception.Message)"
        Write-Error "Response: $($_.ErrorDetails.Message)"
        return @{ success = $false; error = $_.Exception.Message }
    }
}
#endregion
