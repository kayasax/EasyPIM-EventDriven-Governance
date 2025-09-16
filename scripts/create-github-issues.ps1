# 🚀 Create GitHub Issues for Repository Improvements
# This script creates GitHub issues for tracking improvement tasks

# Ensure GitHub CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is required. Install it from: https://cli.github.com/"
    exit 1
}

# Check if authenticated
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Please authenticate with GitHub CLI first:"
    Write-Host "gh auth login"
    exit 1
}

Write-Host "🎯 Creating GitHub Issues for Repository Improvements..." -ForegroundColor Cyan

# Issue 1: Documentation Review
Write-Host "`n📚 Creating Documentation Review Issue..." -ForegroundColor Yellow

$docIssue = @"
## 🎯 **Objective**
Review and fix all documentation issues including broken links, missing icons, formatting problems, and outdated content across the repository.

## 🔍 **Identified Issues**

### **README.md Issues**
- [ ] **Broken workflow badges** - Some GitHub Actions workflow file names may not match the badge references
- [ ] **External link validation** - Check if all external Microsoft documentation links are current
- [ ] **Mermaid diagram rendering** - Verify diagrams display correctly on GitHub
- [ ] **Badge consistency** - Ensure all shields.io badges use consistent styling
- [ ] **Quick start commands** - Verify all PowerShell commands work with current script names

### **Documentation Files Issues**
- [ ] **Cross-references** - Verify internal document links work correctly
- [ ] **Image assets** - Check if any referenced images or diagrams are missing
- [ ] **Code examples** - Ensure all code snippets are accurate and up-to-date
- [ ] **Formatting consistency** - Standardize markdown formatting across all docs

### **Specific Files to Review**
- [ ] ``README.md`` - Main project documentation
- [ ] ``docs/Dual-Platform-Setup-Guide.md`` - Smart routing documentation
- [ ] ``docs/Step-by-Step-Guide.md`` - Implementation tutorial
- [ ] ``docs/GitHub-Actions-Guide.md`` - GitHub Actions specific docs
- [ ] ``docs/Azure-DevOps-Integration-Guide.md`` - Azure DevOps docs

## ✅ **Acceptance Criteria**
- [ ] All internal links tested and working
- [ ] All external links validated and updated if necessary
- [ ] GitHub Actions badges point to correct workflow files
- [ ] Mermaid diagrams render properly
- [ ] Code examples tested and verified working
- [ ] Consistent formatting and styling across all documentation
- [ ] No broken images or missing assets

## 🎯 **Priority**
**High** - Documentation is the first impression for new users
"@

# Issue 2: Azure DevOps Configuration
Write-Host "⚙️ Creating Azure DevOps Configuration Issue..." -ForegroundColor Yellow

$adoIssue = @"
## 🎯 **Objective**
Configure Azure DevOps environment variables in the Function App and validate that smart routing to Azure DevOps pipelines works correctly.

## 🔧 **Current Status**
The Function App ``easypimAKV2GH`` has Azure DevOps environment variables configured but they appear to contain placeholder/debug values instead of proper configuration.

## 📋 **Tasks Required**

### **1. Environment Variable Configuration**
- [ ] **Set ADO_ORGANIZATION** - Configure with actual Azure DevOps organization name
- [ ] **Set ADO_PROJECT** - Configure with target project name for EasyPIM
- [ ] **Set ADO_PIPELINE_ID** - Configure with the pipeline ID for orchestrator pipeline
- [ ] **Set ADO_PAT** - Configure with Personal Access Token (with Build execute permissions)

### **2. Pipeline Setup**
- [ ] **Create/verify Azure DevOps pipeline** - Ensure EasyPIM orchestrator pipeline exists
- [ ] **Pipeline permissions** - Verify PAT has required permissions (Build: read & execute)
- [ ] **Pipeline parameters** - Ensure pipeline accepts parameters from Function App

### **3. Routing Validation**
- [ ] **Test pattern detection** - Create Key Vault secret with 'ado' pattern (e.g., ``easypim-test-ado``)
- [ ] **Verify Function App logs** - Check that Azure DevOps routing is detected
- [ ] **Validate pipeline trigger** - Confirm Azure DevOps pipeline executes
- [ ] **Parameter passing** - Verify parameters are correctly passed to pipeline

### **4. Smart Routing Tests**
Test the following routing patterns:
- [ ] **``easypim-config-ado``** → Azure DevOps (Production mode)
- [ ] **``easypim-test-devops``** → Azure DevOps (WhatIf mode)
- [ ] **``company-settings-azdo``** → Azure DevOps (Pattern detection)

## ⚡ **Implementation Steps**

### **Step 1: Configure Environment Variables**
``````powershell
# Use the setup script
.\scripts\setup-platform.ps1 -Platform AzureDevOps
``````

### **Step 2: Test Smart Routing**
``````powershell
# Create test secret to trigger Azure DevOps routing
az keyvault secret set --vault-name "your-keyvault" --name "easypim-test-ado" --value "test-configuration"
``````

## ✅ **Acceptance Criteria**
- [ ] All ADO environment variables contain proper values (not debug output)
- [ ] Azure DevOps pipeline exists and is accessible
- [ ] Function App correctly routes secrets with 'ado|azdo|devops' patterns to Azure DevOps
- [ ] Pipeline executes successfully with parameters from Function App
- [ ] Function App logs show clear Azure DevOps routing decisions
- [ ] Both GitHub Actions (default) and Azure DevOps (pattern) routing work simultaneously

## 🚨 **Current Blocker**
Environment variables contain debug output instead of configuration values - this must be fixed before routing can work.

## 🎯 **Priority**
**High** - Dual platform architecture is incomplete without working Azure DevOps integration
"@

# Issue 3: Repository Cleanup
Write-Host "🧹 Creating Repository Cleanup Issue..." -ForegroundColor Yellow

$cleanupIssue = @"
## 🎯 **Objective**
Clean up the repository by removing outdated files, test scripts, and duplicate configurations to improve maintainability and clarity.

## 📁 **Files Identified for Cleanup**

### **Test & Debug Files**
The repository contains many test/debug files that should be cleaned up:
- [ ] ``azure-pipelines-minimal-test.yml``
- [ ] ``simple-auth-test.yml``
- [ ] Multiple ``test-*.ps1`` scripts
- [ ] ``ultra-simple-test.yml``

### **Duplicate/Legacy Pipeline Files**
Multiple Azure pipeline configurations that may be outdated:
- [ ] Various ``azure-pipelines-*.yml`` files
- [ ] Duplicate EasyPIM orchestrator files
- [ ] Legacy pipeline configurations

### **Temporary/Debug Scripts**
Scripts that appear to be temporary solutions or debugging tools:
- [ ] Various ``fix-*.ps1`` scripts
- [ ] Multiple permission scripts with similar functionality
- [ ] Debug and diagnostic scripts

### **Documentation Files**
Multiple similar documentation files that may be redundant:
- [ ] ``README-new.md``
- [ ] ``README_clean.md``
- [ ] Duplicate documentation in ``/docs`` folder

## 📋 **Cleanup Strategy**

### **Phase 1: Archive or Remove Test Files**
- [ ] **Move test files** to a ``/tests`` folder or remove if no longer needed
- [ ] **Keep essential test files** that are actively used for validation

### **Phase 2: Consolidate Pipeline Files**
- [ ] **Identify the current working pipeline** configuration
- [ ] **Archive legacy pipeline files** to ``/archive`` folder

### **Phase 3: Clean up Scripts**
- [ ] **Consolidate permission scripts** into one comprehensive script
- [ ] **Remove temporary fix scripts** that are no longer needed

### **Phase 4: Documentation Consolidation**
- [ ] **Merge duplicate README files** into the main README.md
- [ ] **Consolidate similar documentation** in ``/docs`` folder

## ⚠️ **Safety Measures**
- [ ] **Create archive branch** before deleting any files
- [ ] **Review each file** before removal to ensure it's not referenced elsewhere
- [ ] **Test functionality** after cleanup to ensure nothing is broken

## ✅ **Acceptance Criteria**
- [ ] Repository has clear, organized structure
- [ ] No duplicate or redundant files
- [ ] All remaining files serve a clear purpose
- [ ] Documentation updated to reflect new structure
- [ ] All functionality still works after cleanup
- [ ] Archive branch created with original state

## 🎯 **Priority**
**Medium** - Important for maintainability but doesn't affect core functionality
"@

# Issue 4: Summary Display Fixes
Write-Host "📊 Creating Summary Display Fixes Issue..." -ForegroundColor Yellow

$summaryIssue = @"
## 🎯 **Objective**
Fix GitHub Actions workflows so that step summaries and results are properly displayed in the Actions dashboard, improving visibility and monitoring capabilities.

## 🚨 **Current Issue**
GitHub Actions workflows are not displaying comprehensive summaries or results in the Actions tab, making it difficult to:
- Monitor execution results at a glance
- View policy validation outcomes
- See drift detection results
- Track performance metrics

## 📋 **Identified Problems**

### **Missing Step Summaries**
- [ ] **EasyPIM Orchestrator workflow** - Results not visible in Actions dashboard
- [ ] **Drift Detection workflow** - Summary data not displayed properly
- [ ] **Authentication Test workflow** - Status unclear from dashboard view

### **Incomplete Result Reporting**
- [ ] **Policy validation results** - Success/failure counts not shown
- [ ] **Execution metrics** - Timing and performance data missing
- [ ] **Error details** - Failures not properly surfaced in summaries

## 🔧 **Required Fixes**

### **1. Implement Step Summaries**
Add comprehensive step summaries to all workflows using ``$$GITHUB_STEP_SUMMARY``:

``````yaml
- name: Generate Summary
  run: |
    echo "## 📊 EasyPIM Execution Results" >> $$GITHUB_STEP_SUMMARY
    echo "| Metric | Value |" >> $$GITHUB_STEP_SUMMARY
    echo "|--------|-------|" >> $$GITHUB_STEP_SUMMARY
    echo "| Policies Processed | $$policy_count |" >> $$GITHUB_STEP_SUMMARY
``````

### **2. Enhance Result Visualization**
- [ ] **Rich markdown tables** with policy results
- [ ] **Visual indicators** (✅ ❌ ⚠️) for status reporting
- [ ] **Expandable sections** for detailed logs
- [ ] **Charts and metrics** where appropriate

### **3. Workflow-Specific Improvements**
- [ ] **EasyPIM Orchestrator**: Add policy processing summary table
- [ ] **Drift Detection**: Show drift analysis results in table format
- [ ] **Authentication Test**: Display authentication status clearly

## ✅ **Acceptance Criteria**
- [ ] All workflows display comprehensive summaries in the Actions dashboard
- [ ] Results are visible without clicking into individual steps
- [ ] Tables, charts, and visual indicators used effectively
- [ ] Error conditions properly reported with actionable information
- [ ] Performance metrics and timing data visible

## 🎯 **Priority**
**High** - Visibility into execution results is crucial for monitoring and debugging
"@

# Create the issues
try {
    Write-Host "`n🔄 Creating issues in GitHub repository..." -ForegroundColor Green
    
    $issue1 = gh issue create --title "📚 Documentation & README Review" --body $docIssue --label "documentation,bug,maintenance"
    Write-Host "✅ Created Documentation Review Issue: $issue1" -ForegroundColor Green
    
    $issue2 = gh issue create --title "⚙️ Azure DevOps Configuration & Routing Validation" --body $adoIssue --label "enhancement,azure-devops,configuration,testing"
    Write-Host "✅ Created Azure DevOps Configuration Issue: $issue2" -ForegroundColor Green
    
    $issue3 = gh issue create --title "🧹 Repository Cleanup & Organization" --body $cleanupIssue --label "maintenance,cleanup,organization"
    Write-Host "✅ Created Repository Cleanup Issue: $issue3" -ForegroundColor Green
    
    $issue4 = gh issue create --title "📊 Fix GitHub Actions Summary Display Issues" --body $summaryIssue --label "github-actions,enhancement,monitoring,dashboard"
    Write-Host "✅ Created Summary Display Fixes Issue: $issue4" -ForegroundColor Green
    
    Write-Host "`n🎉 All GitHub issues created successfully!" -ForegroundColor Cyan
    Write-Host "View them at: https://github.com/kayasax/EasyPIM-EventDriven-Governance/issues" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to create GitHub issues: $($_.Exception.Message)"
    Write-Host "`nYou can create these issues manually using the content from the generated files:" -ForegroundColor Yellow
    Write-Host "- issue-docs-review.md" -ForegroundColor Cyan
    Write-Host "- issue-ado-configuration.md" -ForegroundColor Cyan
    Write-Host "- issue-repo-cleanup.md" -ForegroundColor Cyan
    Write-Host "- issue-summary-fixes.md" -ForegroundColor Cyan
}