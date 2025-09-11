# 🚀 Simple Azure DevOps Pipeline Trigger - Correct Repository
# Repository: https://dev.azure.com/loic0161/EasyPIM-CICD/

Write-Host "🚀 AZURE DEVOPS PIPELINE VALIDATION" -ForegroundColor Green
Write-Host "Repository: https://dev.azure.com/loic0161/EasyPIM-CICD/" -ForegroundColor Cyan
Write-Host ""

# Correct configuration
$organization = "loic0161"
$project = "EasyPIM-CICD"
$pat = $env:AZURE_DEVOPS_PAT

# Check PAT token
if (-not $pat) {
    Write-Host "❌ Please set your Azure DevOps Personal Access Token:" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 Steps:" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://dev.azure.com/loic0161/_usersSettings/tokens"
    Write-Host "   2. Create token with 'Build (read and execute)' permissions"
    Write-Host "   3. Run: `$env:AZURE_DEVOPS_PAT = 'your_token_here'"
    Write-Host ""
    exit 1
}

Write-Host "✅ PAT token configured" -ForegroundColor Green

# Setup auth headers
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    "Authorization" = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

Write-Host "🔍 Finding build definitions..." -ForegroundColor Yellow

try {
    # Get build definitions
    $definitionsUrl = "https://dev.azure.com/$organization/$project/_apis/build/definitions?api-version=7.1"
    $definitions = Invoke-RestMethod -Uri $definitionsUrl -Method GET -Headers $headers
    
    Write-Host "✅ Found $($definitions.value.Count) build definitions:" -ForegroundColor Green
    
    $targetDef = $null
    foreach ($def in $definitions.value) {
        Write-Host "   ID: $($def.id) | Name: $($def.name)" -ForegroundColor White
        
        # Look for orchestrator pipeline
        if ($def.name -like "*orchestrator*" -or $def.name -like "*EasyPIM*" -or $def.name -like "*templates*") {
            $targetDef = $def
            Write-Host "   🎯 TARGET PIPELINE FOUND!" -ForegroundColor Green
        }
    }
    
    # If no specific match, ask user to choose
    if (-not $targetDef) {
        Write-Host ""
        Write-Host "❓ No orchestrator pipeline found automatically." -ForegroundColor Yellow
        Write-Host "Which build definition ID should I trigger? (Enter number): " -NoNewline
        $selectedId = Read-Host
        $targetDef = $definitions.value | Where-Object { $_.id -eq $selectedId }
    }
    
    if (-not $targetDef) {
        Write-Host "❌ No valid pipeline selected" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "🚀 Triggering pipeline: $($targetDef.name)" -ForegroundColor Green
    
    # Trigger the build
    $buildUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=7.1"
    $buildBody = @{
        definition = @{ id = $targetDef.id }
        sourceBranch = "refs/heads/main"
    } | ConvertTo-Json -Depth 3
    
    $buildResponse = Invoke-RestMethod -Uri $buildUrl -Method POST -Headers $headers -Body $buildBody
    $buildId = $buildResponse.id
    
    Write-Host "✅ Pipeline triggered successfully!" -ForegroundColor Green
    Write-Host "   Build ID: $buildId" -ForegroundColor White
    Write-Host "   Monitor at: $($buildResponse._links.web.href)" -ForegroundColor Blue
    
    # Simple monitoring (just 5 checks)
    Write-Host ""
    Write-Host "📊 Quick status check..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le 5; $i++) {
        Start-Sleep 10
        
        $statusUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds/$buildId?api-version=7.1"
        $status = Invoke-RestMethod -Uri $statusUrl -Method GET -Headers $headers
        
        Write-Host "[$i] Status: $($status.status)" -NoNewline
        if ($status.result) {
            $color = if ($status.result -eq "succeeded") { "Green" } else { "Red" }
            Write-Host " | Result: " -NoNewline
            Write-Host $status.result -ForegroundColor $color
            break
        } else {
            Write-Host " | Running..." -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "🔗 Continue monitoring at: $($buildResponse._links.web.href)" -ForegroundColor Blue
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check repository URL and permissions" -ForegroundColor Yellow
}
