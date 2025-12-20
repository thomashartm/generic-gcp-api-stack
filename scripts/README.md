# Setup Scripts

This directory contains helper scripts for setting up and managing the GCP infrastructure.

## Available Scripts

### 1. setup-gcp-projects.sh

**Purpose**: Configure an existing GCP project with required APIs and Terraform state bucket.

**What it does**:
- Verifies your GCP project exists and has billing enabled
- Enables all required GCP APIs for the infrastructure stack
- Creates Terraform state bucket with versioning (if it doesn't exist)
  - Bucket name: `gs://{project-id}-terraform-state`
  - Environment-specific prefixes (e.g., `dev/`, `staging/`, `prod/`)
- Sets lifecycle policies on state bucket (keeps last 10 versions)

**Interactive prompts**:
1. Enter your GCP project ID
2. Enter environment name (e.g., dev, staging, prod)
3. Confirmation before making changes

**Prerequisites**:
- gcloud CLI installed and authenticated
- Existing GCP project with billing enabled
- Appropriate IAM permissions on the project

**Usage**:
```bash
./scripts/setup-gcp-projects.sh
```

**Example flow**:
```
Enter your GCP project ID: my-company-prod
Enter environment name: prod
Ready to configure project 'my-company-prod' for environment 'prod'
Do you want to continue? (y/n) y
```

**APIs enabled**:
- Compute Engine API
- Cloud Run API
- Cloud SQL Admin API
- VPC Access API
- Secret Manager API
- Artifact Registry API
- Pub/Sub API
- Cloud Resource Manager API
- IAM API
- Service Networking API

---

### 2. validate-setup.sh

**Purpose**: Validates that your GCP project and resources are properly configured.

**What it checks**:
- gcloud CLI installation and authentication
- Terraform and Terragrunt installation
- GCP project exists and is accessible
- Billing is enabled on the project
- Required APIs are enabled
- Terraform state bucket exists with versioning
- IAM permissions
- Region availability

**Usage**:
```bash
./scripts/validate-setup.sh <project-id>
```

**Example**:
```bash
./scripts/validate-setup.sh my-company-dev
```

**Exit codes**:
- `0` - All validations passed
- `1` - Some validations failed

**Example output**:
```
Total checks: 15
Passed: 13
Warnings: 2
Failed: 0

✓ All validations passed! You're ready to proceed with Terraform deployment.
```

---

## Workflow

### Initial Setup

**Prerequisites**: You must have an existing GCP project created (via GCP Console or `gcloud projects create`).

1. **Authenticate with GCP**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Run setup script for your project**:
   ```bash
   ./scripts/setup-gcp-projects.sh
   ```

   You'll be prompted for:
   - Your GCP project ID (e.g., `my-company-dev`)
   - Environment name (e.g., `dev`)

3. **Validate setup**:
   ```bash
   ./scripts/validate-setup.sh my-company-dev
   ```

4. **Proceed with Terraform**:
   ```bash
   cd infra/stacks/dev
   terragrunt run-all init
   terragrunt run-all plan
   ```

### Setting Up Additional Environments

To add staging or production environments:

1. **Create a new GCP project** (via GCP Console or gcloud):
   ```bash
   gcloud projects create my-company-staging
   ```

2. **Run setup script for the new project**:
   ```bash
   ./scripts/setup-gcp-projects.sh
   ```

   Enter the new project ID and environment name when prompted.

3. **Validate the new environment**:
   ```bash
   ./scripts/validate-setup.sh my-company-staging
   ```

4. **Deploy to new environment**:
   ```bash
   cd infra/stacks/staging
   terragrunt run-all apply
   ```

### Before Each Deployment

It's good practice to validate before deploying:

```bash
./scripts/validate-setup.sh my-company-dev && cd infra/stacks/dev && terragrunt run-all plan
```

---

## Troubleshooting

### "Project not found"

**Solution**:
1. Verify the project ID is correct: `gcloud projects list`
2. Ensure you have access to the project
3. If the project doesn't exist, create it first:
   ```bash
   gcloud projects create <project-id>
   ```

### "Billing not enabled"

**Solution**:
1. Go to [GCP Console](https://console.cloud.google.com/billing)
2. Link a billing account to your project
3. Re-run the setup script

### "Permission denied" errors

**Solution**:
1. Ensure you have appropriate IAM roles on the project:
   - `roles/editor` or `roles/owner` (to enable APIs and create resources)
2. Check your permissions: `gcloud projects get-iam-policy <project-id>`
3. Contact your GCP admin if you need additional permissions

### "API not enabled" warnings

**Solution**:
Run the setup script again, or manually enable APIs:
```bash
gcloud services enable <api-name> --project=<project-id>
```

### State bucket already exists

**Solution**:
This is normal if you've run the setup script before. The script will detect the existing bucket and skip creation. If you need to create a bucket with a different name, you can:
1. Manually create it: `gsutil mb -p <project-id> -l europe-west6 gs://<bucket-name>`
2. Update Terragrunt configurations to use the new bucket name

---

## Manual Setup (Alternative)

If you prefer to set up manually instead of using the scripts:

### 1. Create GCP Project (if you don't have one)

```bash
# Create project
gcloud projects create my-company-dev

# Link billing
gcloud billing projects link my-company-dev --billing-account=<BILLING_ACCOUNT_ID>
```

### 2. Enable Required APIs

```bash
PROJECT_ID="my-company-dev"  # Replace with your project ID

gcloud services enable \
  compute.googleapis.com \
  run.googleapis.com \
  sqladmin.googleapis.com \
  vpcaccess.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  pubsub.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  cloudapis.googleapis.com \
  servicenetworking.googleapis.com \
  --project=$PROJECT_ID
```

### 3. Create Terraform State Bucket

```bash
PROJECT_ID="my-company-dev"  # Replace with your project ID
ENVIRONMENT="dev"             # Replace with your environment name

# Create bucket
gsutil mb -p $PROJECT_ID -l europe-west6 gs://${PROJECT_ID}-terraform-state

# Enable versioning
gsutil versioning set on gs://${PROJECT_ID}-terraform-state

# Set lifecycle policy (keep last 10 versions)
cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "numNewerVersions": 10
        }
      }
    ]
  }
}
EOF
gsutil lifecycle set /tmp/lifecycle.json gs://${PROJECT_ID}-terraform-state
rm /tmp/lifecycle.json

# Create environment prefix
echo "Terraform state for ${ENVIRONMENT} environment" | \
  gsutil cp - gs://${PROJECT_ID}-terraform-state/${ENVIRONMENT}/.terragrunt-bucket-setup
```

---

## Security Notes

- Never commit GCP service account keys to this repository
- The scripts do not create or download any service account keys
- Terraform will use Application Default Credentials (ADC)
- For CI/CD, use Workload Identity Federation instead of service account keys

---

## Next Steps

After successful setup:

1. Validate your setup: `./scripts/validate-setup.sh <your-project-id>`
2. Review [PLAN.md](../PLAN.md) for the complete implementation plan
3. Review [CLAUDE.md](../CLAUDE.md) for operational commands
4. Configure Terragrunt in `infra/terragrunt.hcl`:
   - Set bucket name: `<project-id>-terraform-state`
   - Set prefix for environment: `<environment>/`
   - Set project ID: `<project-id>`
5. Start creating Terraform modules in `infra/modules/`
