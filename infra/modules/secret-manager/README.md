# Secret Manager Module

This module creates secrets in Google Secret Manager for storing sensitive data like database credentials.

## Resources Created

- **Database Password Secret**: Secret for database password
- **Database User Secret**: Secret for database username
- **Database Name Secret**: Secret for database name
- **Additional Secrets**: Optional additional secrets
- **IAM Bindings**: Grant service accounts access to secrets

## Usage

```hcl
module "secret_manager" {
  source = "../../modules/secret-manager"

  project_id  = "my-project-dev"
  environment = "dev"

  db_password = "supersecret123"  # In practice, use a secure method to pass this
  db_user     = "appuser"
  db_name     = "appdb"

  # Optional additional secrets
  additional_secrets = {
    jwt-secret = "jwt-secret-key-here"
    api-key    = "external-api-key-here"
  }

  # Service accounts that can access these secrets
  accessor_service_accounts = [
    "serviceAccount:dev-api-sa@my-project-dev.iam.gserviceaccount.com",
    "serviceAccount:dev-event-processor-sa@my-project-dev.iam.gserviceaccount.com"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| environment | Environment name | string | - | yes |
| db_password | Database password | string (sensitive) | - | yes |
| db_user | Database username | string | appuser | no |
| db_name | Database name | string | appdb | no |
| additional_secrets | Map of additional secrets | map(string) (sensitive) | {} | no |
| accessor_service_accounts | Service accounts that can access secrets | list(string) | [] | no |

## Outputs

| Name | Description |
|------|-------------|
| db_password_secret_id | ID of the database password secret |
| db_password_secret_name | Full resource name of the database password secret |
| db_user_secret_id | ID of the database user secret |
| db_user_secret_name | Full resource name of the database user secret |
| db_name_secret_id | ID of the database name secret |
| db_name_secret_name | Full resource name of the database name secret |
| secret_ids | Map of all secret IDs |
| secret_names | Map of all secret full resource names |

## Security Best Practices

### Never Commit Secrets to Git

```bash
# Bad - Don't do this!
db_password = "mysecret123"

# Good - Use environment variables
db_password = var.db_password  # Set via TF_VAR_db_password env var

# Better - Use a secret management tool
# Store secrets in 1Password, Vault, etc. and fetch them during deployment
```

### Passing Secrets Safely

**Option 1: Environment Variables**
```bash
export TF_VAR_db_password="your-secret-password"
terragrunt apply
```

**Option 2: .tfvars file (not committed to git)**
```hcl
# terraform.tfvars (add to .gitignore!)
db_password = "your-secret-password"
```

**Option 3: Interactive Input**
```bash
terragrunt apply
# Terraform will prompt for db_password
```

## Accessing Secrets in Cloud Run

Secrets are accessed via environment variables that reference Secret Manager:

```yaml
# In Cloud Run configuration
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: dev-db-password
        key: latest
```

## Dependencies

- **iam**: Service accounts must exist before granting them access to secrets