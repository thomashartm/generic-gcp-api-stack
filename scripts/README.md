# Setup Scripts

This directory contains helper scripts for setting up and managing the GCP infrastructure.

## Available Scripts

### 1. setup-gcp-projects.sh

**Purpose**: Automated setup of GCP projects, APIs, and Terraform state buckets.

**What it does**:
- Creates GCP project(s) - you choose: dev only, dev+staging, or all three
- Links billing account to each project
- Enables all required GCP APIs
- Creates shared GCS bucket for Terraform state with versioning
  - Bucket: `gs://generic-demo-terraform-state` (in dev project)
  - Environment prefixes: `dev/`, `staging/`, `prod/`
- Sets lifecycle policies on state bucket

**Interactive prompts**:
1. Choose which environments to set up (dev only recommended for first run)
2. Select billing account (if multiple available)
3. Confirmation before creating resources

**Prerequisites**:
- gcloud CLI installed and authenticated
- Active GCP billing account
- Permissions to create projects (requires organization admin or billing account user)

**Usage**:
```bash
./scripts/setup-gcp-projects.sh
```

**Projects that can be created**:
- `generic-demo-dev` - Development environment (recommended to start)
- `generic-demo-staging` - Staging environment (optional, can add later)
- `generic-demo-prod` - Production environment (optional, can add later)

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

**Purpose**: Validates that all prerequisites and GCP resources are properly configured.

**Smart detection**: Automatically detects which projects exist (dev, staging, prod) and validates only those.

**What it checks**:
- gcloud CLI installation and authentication
- Terraform and Terragrunt installation
- GCP projects that exist
- Billing is enabled
- Required APIs are enabled
- Terraform state buckets exist with versioning
- IAM permissions
- Region availability

**Usage**:
```bash
./scripts/validate-setup.sh
```

**Exit codes**:
- `0` - All validations passed
- `1` - Some validations failed

**Example output**:
```
Total checks: 45
Passed: 43
Warnings: 2
Failed: 0

✓ All validations passed! You're ready to proceed with Terraform deployment.
```

---

## Workflow

### Initial Setup (Dev Only - Recommended)

1. **Authenticate with GCP**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Run setup script and choose option 1 (Dev only)**:
   ```bash
   ./scripts/setup-gcp-projects.sh
   # Select: 1) Dev only (recommended to start)
   ```

3. **Validate setup**:
   ```bash
   ./scripts/validate-setup.sh
   ```

4. **Proceed with Terraform**:
   ```bash
   cd infra/stacks/dev
   terragrunt run-all init
   terragrunt run-all plan
   ```

### Adding Staging/Prod Later

When you're ready to expand to other environments:

1. **Re-run setup script and choose option 2 or 3**:
   ```bash
   ./scripts/setup-gcp-projects.sh
   # Select: 2) Dev + Staging  OR  3) Dev + Staging + Prod
   # The script will skip dev (already exists) and create the new ones
   ```

2. **Validate new environments**:
   ```bash
   ./scripts/validate-setup.sh
   ```

3. **Deploy to new environments**:
   ```bash
   cd infra/stacks/staging
   terragrunt run-all apply
   ```

### Before Each Deployment

It's good practice to run the validation script before deploying infrastructure:

```bash
./scripts/validate-setup.sh && cd infra/stacks/dev && terragrunt run-all plan
```

---

## Troubleshooting

### "No billing accounts found"

**Solution**:
1. Go to [GCP Billing](https://console.cloud.google.com/billing)
2. Create or activate a billing account
3. Re-run the setup script

### "Permission denied" errors

**Solution**:
1. Ensure you have the following roles:
   - `roles/resourcemanager.projectCreator` (to create projects)
   - `roles/billing.user` (to link billing)
2. If using an organization, contact your GCP admin

### "API not enabled" warnings

**Solution**:
Run the setup script again, or manually enable APIs:
```bash
gcloud services enable <api-name> --project=<project-id>
```

### State bucket already exists

**Solution**:
GCS bucket names are globally unique. If `generic-demo-terraform-state` is taken:
1. Change `PROJECT_PREFIX` in the script to make it unique (e.g., `my-company-demo`)
2. Or manually create a bucket with a different name
3. Update Terragrunt configurations to use the new bucket name

The bucket will be: `gs://${PROJECT_PREFIX}-terraform-state`

---

## Manual Setup (Alternative)

If you prefer to set up manually instead of using the scripts:

### 1. Create Projects

```bash
# Dev
gcloud projects create generic-demo-dev
gcloud billing projects link generic-demo-dev --billing-account=<BILLING_ACCOUNT_ID>

# Staging
gcloud projects create generic-demo-staging
gcloud billing projects link generic-demo-staging --billing-account=<BILLING_ACCOUNT_ID>

# Prod
gcloud projects create generic-demo-prod
gcloud billing projects link generic-demo-prod --billing-account=<BILLING_ACCOUNT_ID>
```

### 2. Enable APIs

```bash
# For each project
for project in generic-demo-dev generic-demo-staging generic-demo-prod; do
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
    servicenetworking.googleapis.com \
    --project=$project
done
```

### 3. Create Shared State Bucket

```bash
# Create shared bucket in dev project
gsutil mb -p generic-demo-dev -l europe-west6 gs://generic-demo-terraform-state

# Enable versioning
gsutil versioning set on gs://generic-demo-terraform-state

# Set lifecycle policy
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
gsutil lifecycle set /tmp/lifecycle.json gs://generic-demo-terraform-state
rm /tmp/lifecycle.json

# Create environment prefixes (optional)
for env in dev staging prod; do
  echo "Terraform state for ${env} environment" | \
    gsutil cp - gs://generic-demo-terraform-state/${env}/.terragrunt-bucket-setup
done
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

1. Review [PLAN.md](../PLAN.md) for the complete implementation plan
2. Review [CLAUDE.md](../CLAUDE.md) for operational commands
3. Start creating Terraform modules in `infra/modules/`
4. Configure Terragrunt in `infra/stacks/`
