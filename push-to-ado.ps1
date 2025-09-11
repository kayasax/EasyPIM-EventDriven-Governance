# Push to Azure DevOps without credential prompts
# This script uses Azure CLI authentication to push changes

Write-Host "🚀 Pushing to Azure DevOps repository..." -ForegroundColor Green

# Check if we're authenticated with Azure CLI
$azContext = az account show --query "user.name" -o tsv 2>$null
if (!$azContext) {
    Write-Host "❌ Not authenticated with Azure CLI. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Authenticated as: $azContext" -ForegroundColor Green

# Use az repos to push instead of git directly
Write-Host "📤 Pushing changes to Azure DevOps..." -ForegroundColor Yellow

try {
    # First, let's get the current branch and commit
    $currentBranch = git branch --show-current
    $lastCommit = git log -1 --pretty=format:"%h %s"
    
    Write-Host "Current branch: $currentBranch" -ForegroundColor Cyan
    Write-Host "Last commit: $lastCommit" -ForegroundColor Cyan
    
    # Create a temporary remote with Azure CLI authentication
    $tempRemote = "temp-ado-$(Get-Random)"
    
    # Get an access token for Azure DevOps
    $token = az account get-access-token --resource https://dev.azure.com/ --query accessToken -o tsv
    
    if ($token) {
        # Add temporary remote with token authentication
        $repoUrl = "https://loic@yespapa.eu:$token@dev.azure.com/loic0161/EasyPIM-CICD/_git/EasyPIM-CICD"
        git remote add $tempRemote $repoUrl
        
        # Push using the temporary remote
        git push $tempRemote main --force
        
        # Clean up the temporary remote
        git remote remove $tempRemote
        
        Write-Host "✅ Successfully pushed to Azure DevOps!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to get Azure DevOps access token" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error pushing to Azure DevOps: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
