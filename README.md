# EasyPIM CI/CD Testing Framework

A comprehensive testing framework for demonstrating **EasyPIM** integration in CI/CD pipelines using the `invoke-easypimorchestrator` GitHub Action.

## Overview

This repository demonstrates how to integrate **EasyPIM** (Privileged Identity Management) into CI/CD workflows for secure, just-in-time access to Azure resources. The framework uses the official EasyPIM orchestrator action to test various authentication methods, privilege escalation scenarios, and deployment patterns.

## 🎯 Testing Phases

### Phase 1: EasyPIM Authentication Test
- **Workflow**: `01-auth-test.yml`
- **Scope**: OIDC authentication, EasyPIM orchestrator connectivity
- **Purpose**: Establish secure connection patterns using `invoke-easypimorchestrator`

### Phase 2: PIM Read Operations
- **Workflow**: `02-pim-read-test.yml`
- **Scope**: List eligible roles, get PIM settings, read-only operations
- **Purpose**: Test safe PIM query operations

### Phase 3: PIM Role Activation
- **Workflow**: `03-pim-activation-test.yml`
- **Scope**: Role activation/deactivation with EasyPIM orchestrator
- **Purpose**: Test controlled privilege escalation

### Phase 4: Full Deployment Integration
- **Workflow**: `04-full-deployment.yml`
- **Scope**: Complete deployment with PIM-enabled roles
- **Purpose**: Real-world deployment scenarios

## 🔧 Setup Requirements

### Azure Configuration
1. **Entra ID Application Registration**
   - Federated credentials for GitHub OIDC
   - Microsoft Graph permissions:
     - `User.Read.All`
     - `RoleManagement.ReadWrite.Directory`
     - `PrivilegedAccess.ReadWrite.AzureResources`

2. **PIM Configuration**
   - Eligible role assignments for the service principal
   - Activation policies configured
   - Approval workflows (if required)

### GitHub Configuration
1. **Repository Secrets**
   ```
   AZURE_CLIENT_ID          # Application (client) ID
   AZURE_TENANT_ID          # Directory (tenant) ID
   AZURE_SUBSCRIPTION_ID    # Target subscription
   ```

2. **Environment Protection Rules**
   - Required reviewers for production deployments
   - Environment-specific configurations

## 📁 Repository Structure

```
├── .github/
│   └── workflows/              # GitHub Actions workflows
│       ├── 01-auth-test.yml    # EasyPIM authentication test
│       ├── 02-pim-read-test.yml
│       ├── 03-pim-activation-test.yml
│       └── 04-full-deployment.yml
├── configs/                    # EasyPIM configuration files
│   ├── pim-config.json        # Main EasyPIM configuration
│   └── test-resources.json    # Test resource configurations
├── docs/                      # Documentation
│   ├── setup-guide.md         # Detailed setup instructions
│   ├── troubleshooting.md     # Common issues and solutions
│   └── best-practices.md      # PIM CI/CD best practices
└── tests/                     # Test configurations
    ├── unit/                  # Unit test scenarios
    └── integration/           # Integration test scenarios
```

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/kayasax/EasyPIM-CICD-test.git
   cd EasyPIM-CICD-test
   ```

2. **Configure Azure resources** (see `docs/setup-guide.md`)

3. **Set up GitHub secrets** (see configuration section above)

4. **Run Phase 1 workflow**
   - Navigate to Actions tab in GitHub
   - Select "Phase 1: EasyPIM Authentication Test"
   - Click "Run workflow"

## 🔍 EasyPIM Integration

### Using invoke-easypimorchestrator Action

All workflows use the official `kayasax/invoke-easypimorchestrator` GitHub Action:

```yaml
- name: 'List Eligible Roles'
  uses: kayasax/invoke-easypimorchestrator@main
  with:
    operation: 'ListEligibleRoles'
    config-path: './configs/pim-config.json'
    dry-run: true
```

### Configuration Schema

The `pim-config.json` follows the EasyPIM standard schema:

```json
{
  "version": "1.0",
  "configuration": {
    "tenant_id": "{{ .Env.AZURE_TENANT_ID }}",
    "subscription_id": "{{ .Env.AZURE_SUBSCRIPTION_ID }}",
    "dry_run": true
  },
  "pim_groups": [
    {
      "group_name": "Development Environment Access",
      "roles": [
        {
          "role_definition_id": "21090545-7ca7-4776-b22c-e363652d74d2",
          "role_name": "Key Vault Reader",
          "scope": "/subscriptions/.../resourceGroups/rg-dev",
          "justification": "CI/CD pipeline access",
          "duration": "PT1H"
        }
      ]
    }
  ]
}
```

## 📊 Monitoring & Logging

All workflows include comprehensive logging:
- EasyPIM orchestrator execution status
- PIM role activation attempts
- Configuration validation results
- Error details and troubleshooting information

## 🔒 Security Considerations

- **No Scripts Required**: Uses official EasyPIM orchestrator action
- **Schema Validation**: Configuration validated by EasyPIM
- **Audit Trail**: All operations logged for compliance
- **Dry Run Mode**: Safe testing without actual role activations
- **Least Privilege**: Minimal permissions following EasyPIM recommendations
