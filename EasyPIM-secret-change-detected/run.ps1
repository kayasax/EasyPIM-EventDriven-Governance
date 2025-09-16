param($req, $TriggerMetadata)

$body = $req.Body
try {
    # Handle different body formats
    if ($body -is [string]) {
        # If body is already a string, try to parse it as JSON
        if ($body.StartsWith('{') -or $body.StartsWith('[')) {
            $eventData = $body | ConvertFrom-Json
        } else {
            # If it's not JSON, treat it as a simple validation string
            Write-Host "Received non-JSON body: $body"
            $eventData = @{ eventType = "Unknown"; data = @{} }
        }
    } else {
        # If body is already an object, use it directly
        $eventData = $body
    }

    $eventType = $eventData.eventType
    $eventData | Out-String | Write-Host
} catch {
    Write-Error "Failed to parse eventGridEvent: $_"
    $body | Out-String | Write-Host
    # Continue processing with empty event data
    $eventData = @{ eventType = "Unknown"; data = @{} }
    $eventType = "Unknown"
}

# Handle Event Grid subscription validation event
if ($eventType -eq 'Microsoft.EventGrid.SubscriptionValidationEvent') {
    $validationCode = $eventData.data.validationCode
    Write-Host "Responding to EventGrid validation: $validationCode"

    # For Event Grid webhook validation, return the validation response directly
    $validationResponse = @{ validationResponse = $validationCode }
    Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
        StatusCode = 200
        Headers = @{ "Content-Type" = "application/json" }
        Body = ($validationResponse | ConvertTo-Json)
    })
    return
}

# Get GitHub token from environment variable (set this in Function App Configuration)
$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Error "GITHUB_TOKEN environment variable not set"
    Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
        StatusCode = 500
        Headers = @{ "Content-Type" = "application/json" }
        Body = "Missing GitHub token"
    })
    return
}

# Extract information from the Key Vault event
$secretName = "Unknown"
$vaultName = "Unknown"
$eventSource = "manual"
if ($eventData.data) {
    if ($eventData.data.ObjectName) { $secretName = $eventData.data.ObjectName }
    if ($eventData.data.VaultName) { $vaultName = $eventData.data.VaultName }
    if ($eventData.subject) { $eventSource = "keyvault" }
}

Write-Host "🔍 Processing Key Vault event for secret: $secretName in vault: $vaultName"

# 🚀 Platform routing based on secret name
if ($secretName -match "ado|azdo|devops") {
    Write-Host "🎯 Detected Azure DevOps pattern - routing to Azure DevOps pipeline"
    
    # Azure DevOps configuration
    $adoOrganization = $env:ADO_ORGANIZATION
    $adoProject = $env:ADO_PROJECT  
    $adoPipelineId = $env:ADO_PIPELINE_ID
    $adoToken = $env:ADO_PAT
    
    if (-not $adoToken -or -not $adoOrganization -or -not $adoProject -or -not $adoPipelineId) {
        Write-Error "❌ Azure DevOps configuration missing. Required: ADO_ORGANIZATION, ADO_PROJECT, ADO_PIPELINE_ID, ADO_PAT"
        Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
            StatusCode = 500
            Headers = @{ "Content-Type" = "application/json" }
            Body = "Azure DevOps configuration incomplete"
        })
        return
    }
    
    # Build Azure DevOps pipeline parameters (same logic as GitHub Actions)
    $pipelineParameters = @{
        "configSecretName" = $secretName
        "whatIfMode" = ($secretName -match "test|debug|dev").ToString().ToLower()
        "mode" = if ($secretName -match "initial|setup|bootstrap") { "initial" } else { "delta" }
        "verbose" = ($secretName -match "verbose|debug").ToString().ToLower()
        "runDescription" = "Triggered by Key Vault secret change: $secretName in $vaultName"
    }
    
    # Apply smart parameter detection
    if ($secretName -match "test|debug") {
        $pipelineParameters.runDescription += " (Test Mode - Preview Only)"
    }
    if ($secretName -match "initial|setup|bootstrap") {
        $pipelineParameters.runDescription += " (Initial Setup Mode)"
    }
    
    # Environment variable overrides (same as GitHub Actions logic)
    if ($env:EASYPIM_WHATIF) { $pipelineParameters.whatIfMode = $env:EASYPIM_WHATIF.ToLower() }
    if ($env:EASYPIM_MODE) { $pipelineParameters.mode = $env:EASYPIM_MODE }
    if ($env:EASYPIM_VERBOSE) { $pipelineParameters.verbose = $env:EASYPIM_VERBOSE.ToLower() }
    
    Write-Host "📋 Azure DevOps Parameters:" 
    $pipelineParameters | Format-Table | Out-String | Write-Host
    
    # Azure DevOps REST API call
    $apiUrl = "https://dev.azure.com/$adoOrganization/$adoProject/_apis/pipelines/$adoPipelineId/runs?api-version=7.0"
    
    $bodyObj = @{
        resources = @{
            repositories = @{
                self = @{
                    refName = "refs/heads/main"
                }
            }
        }
        templateParameters = $pipelineParameters
    }
    
    $adoHeaders = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$adoToken"))
        "Content-Type" = "application/json"
    }
    
    Write-Host "🚀 Triggering Azure DevOps pipeline..."
    Write-Host "URI: $apiUrl"
    Write-Host "Pipeline ID: $adoPipelineId in $adoOrganization/$adoProject"
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $adoHeaders -Body ($bodyObj | ConvertTo-Json -Depth 4)
        Write-Host "✅ Azure DevOps pipeline triggered successfully!"
        Write-Host "Pipeline Run ID: $($response.id)"
        if ($response._links -and $response._links.web -and $response._links.web.href) {
            Write-Host "Pipeline URL: $($response._links.web.href)"
        }
        
        # Return success response
        Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
            StatusCode = 200
            Headers = @{ "Content-Type" = "application/json" }
            Body = "Azure DevOps pipeline triggered successfully"
        })
        return
        
    } catch {
        Write-Error "❌ Failed to trigger Azure DevOps pipeline: $($_.Exception.Message)"
        if ($_.ErrorDetails.Message) {
            Write-Error "Response details: $($_.ErrorDetails.Message)"
        }
        Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
            StatusCode = 500
            Headers = @{ "Content-Type" = "application/json" }
            Body = "Failed to trigger Azure DevOps pipeline: $($_.Exception.Message)"
        })
        return
    }
    
} else {
    # 🎯 Default: Route to GitHub Actions (existing logic)
    Write-Host "🎯 Using default GitHub Actions routing for secret: $secretName"
}

$repo = "kayasax/EasyPIM-EventDriven-Governance"
$workflow = "02-orchestrator-test.yml"

# Build workflow inputs - customize these based on your needs
$workflowInputs = @{
    run_description = "Triggered by Key Vault secret change: $secretName in $vaultName"
    configSecretName = $secretName  # Pass the secret name for dynamic config path selection
    WhatIf = $false  # Set to true for preview mode, false for actual execution
    Mode = "delta"   # Use delta mode for incremental changes
    SkipPolicies = $false
    SkipAssignments = $false
    AllowProtectedRoles = $false
    Verbose = $false  # Enable verbose output for debugging
    ExportWouldRemove = $true
}

# Adjust parameters based on secret name or event type
if ($secretName -match "test|debug") {
    $workflowInputs.WhatIf = $true  # Use preview mode for test secrets
    $workflowInputs.run_description += " (Test Mode - Preview Only)"
    Write-Host "Test secret detected ($secretName) - enabling WhatIf mode"
}

if ($secretName -match "initial|setup|bootstrap") {
    $workflowInputs.Mode = "initial"  # Use initial mode for setup secrets
    $workflowInputs.run_description += " (Initial Setup Mode)"
    Write-Host "Initial setup secret detected ($secretName) - using initial mode"
}

Write-Host "Configuration will be read from secret: $secretName"

# Add environment variables for additional configuration
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

Write-Host "Workflow inputs configured:"
$workflowInputs | Format-Table | Out-String | Write-Host

# Trigger GitHub Actions workflow with parameters
$bodyObj = @{
    ref = "main"
    inputs = $workflowInputs
}
$uri = "https://api.github.com/repos/$repo/actions/workflows/$workflow/dispatches"
$headers = @{Authorization = "token $token"; Accept = "application/vnd.github.v3+json"}

Write-Host "Invoking GitHub Actions workflow dispatch..."
Write-Host "URI: $uri"
Write-Host "Body: $($bodyObj | ConvertTo-Json)"

try {
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body ($bodyObj | ConvertTo-Json)
    Write-Host "Workflow dispatch response: $($response | Out-String)"
} catch {
    Write-Error "Failed to invoke GitHub Actions workflow: $_"
}

# Return success response
Push-OutputBinding -Name res -Value ([HttpResponseContext]@{
    StatusCode = 200
    Headers = @{ "Content-Type" = "application/json" }
    Body = "Processed"
})