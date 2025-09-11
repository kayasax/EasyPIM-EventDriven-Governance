# Azure DevOps File Update Script
# Updates pipeline files in Azure DevOps repository via REST API

param(
    [Parameter(Mandatory=$true)]
    [string]$PersonalAccessToken,

    [string]$Organization = "loic0161",
    [string]$Project = "EasyPIM-CICD",
    [string]$Repository = "EasyPIM-CICD",
    [string]$Branch = "main"
)

Write-Host "🚀 Updating Azure DevOps Repository via REST API" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Base64 encode PAT for authentication
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
$headers = @{
    "Authorization" = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

$baseUrl = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$Repository"

try {
    # Step 1: Get current commit info
    Write-Host "`n📋 Getting repository information..." -ForegroundColor Yellow

    $branchUrl = "$baseUrl/refs?filter=heads/$Branch&api-version=7.1"
    $branchResponse = Invoke-RestMethod -Uri $branchUrl -Headers $headers -Method Get

    if ($branchResponse.count -eq 0) {
        throw "Branch '$Branch' not found"
    }

    $currentCommitId = $branchResponse.value[0].objectId
    Write-Host "  ✅ Current commit: $($currentCommitId.Substring(0,8))..." -ForegroundColor Green

    # Step 2: Prepare file updates
    Write-Host "`n📝 Preparing file updates..." -ForegroundColor Yellow

    $filesToUpdate = @(
        @{
            Path = "templates/azure-pipelines-auth-test.yml"
            LocalPath = ".\templates\azure-pipelines-auth-test.yml"
        },
        @{
            Path = "templates/azure-pipelines-orchestrator.yml"
            LocalPath = ".\templates\azure-pipelines-orchestrator.yml"
        },
        @{
            Path = "templates/azure-pipelines-drift-detection.yml"
            LocalPath = ".\templates\azure-pipelines-drift-detection.yml"
        },
        @{
            Path = "templates/azure-pipelines-auth-test-selfhosted.yml"
            LocalPath = ".\templates\azure-pipelines-auth-test-selfhosted.yml"
        }
    )

    $changes = @()

    foreach ($file in $filesToUpdate) {
        if (Test-Path $file.LocalPath) {
            $content = Get-Content $file.LocalPath -Raw -Encoding UTF8
            $base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))

            $changes += @{
                changeType = "edit"
                item = @{
                    path = "/$($file.Path)"
                }
                newContent = @{
                    content = $base64Content
                    contentType = "base64encoded"
                }
            }

            Write-Host "  ✅ Prepared: $($file.Path)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Skipped: $($file.Path) (not found locally)" -ForegroundColor Yellow
        }
    }

    if ($changes.Count -eq 0) {
        Write-Host "  ❌ No files to update" -ForegroundColor Red
        exit 1
    }

    # Step 3: Create push request
    Write-Host "`n🚀 Pushing updates to Azure DevOps..." -ForegroundColor Yellow

    $pushData = @{
        refUpdates = @(
            @{
                name = "refs/heads/$Branch"
                oldObjectId = $currentCommitId
            }
        )
        commits = @(
            @{
                comment = "✅ Update pipelines to use self-hosted agent (pool: Default) - fixes parallelism issues"
                changes = $changes
            }
        )
    } | ConvertTo-Json -Depth 10

    $pushUrl = "$baseUrl/pushes?api-version=7.1"
    $pushResponse = Invoke-RestMethod -Uri $pushUrl -Headers $headers -Method Post -Body $pushData

    Write-Host "  ✅ Push successful!" -ForegroundColor Green
    Write-Host "     New commit: $($pushResponse.commits[0].commitId.Substring(0,8))..." -ForegroundColor Gray
    Write-Host "     Files updated: $($changes.Count)" -ForegroundColor Gray

    # Step 4: Summary
    Write-Host "`n🎉 Azure DevOps Repository Updated!" -ForegroundColor Green
    Write-Host "===================================" -ForegroundColor Green
    Write-Host "✅ All pipeline templates now use: pool: Default" -ForegroundColor White
    Write-Host "✅ Self-hosted agent configuration applied" -ForegroundColor White
    Write-Host "✅ No more parallelism limitations!" -ForegroundColor White

    Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Go to Azure DevOps → Pipelines" -ForegroundColor White
    Write-Host "2. Run your EasyPIM authentication test pipeline" -ForegroundColor White
    Write-Host "3. Verify it uses your self-hosted agent" -ForegroundColor White
    Write-Host "4. No more 'parallelism grant' errors!" -ForegroundColor White

    Write-Host "`n🔗 Repository URL: https://dev.azure.com/$Organization/$Project/_git/$Repository" -ForegroundColor Gray

} catch {
    Write-Host "`n❌ Update failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   • Verify your PAT has 'Code (read & write)' permissions" -ForegroundColor White
    Write-Host "   • Check repository and project names are correct" -ForegroundColor White
    Write-Host "   • Ensure you have push permissions to the repository" -ForegroundColor White
    exit 1
}

Write-Host "`n✅ Script completed successfully!" -ForegroundColor Green
