# GCP Infrastructure Setup Guide

This guide walks you through setting up the GCP infrastructure for the NestJS API stack from scratch.

## Overview

You'll set up GCP infrastructure starting with development, then optionally add staging and production:
- GCP project for dev (staging and prod optional for later)
- All required GCP APIs enabled
- Terraform state storage (GCS bucket)
- Terraform modules for infrastructure components
- Terragrunt configurations for environment management

**Recommended approach**: Start with dev environment only, validate it works, then add staging/prod.

**Estimated time**:
- Dev environment: 1-2 hours
- Adding staging/prod: 30 minutes each

---

## Prerequisites

Before starting, ensure you have:

### 1. Tools Installed

- **gcloud CLI** (v400+)
  ```bash
  # Install: https://cloud.google.com/sdk/docs/install
  gcloud version
  ```

- **Terraform** (v1.5+)
  ```bash
  # Install: https://developer.hashicorp.com/terraform/install
  terraform version
  ```

- **Terragrunt** (v0.50+)
  ```bash
  # Install: https://terragrunt.gruntwork.io/docs/getting-started/install/
  terragrunt --version
  ```

- **Git**
  ```bash
  git --version
  ```

### 2. GCP Account Setup

- Active Google Cloud account
- Billing account with payment method
- Permissions to create projects (requires `roles/resourcemanager.projectCreator` and `roles/billing.user`)

### 3. Authentication

```bash
# Login to GCP
gcloud auth login

# Set application default credentials for Terraform
gcloud auth application-default login

# Verify authentication
gcloud auth list
```

---

## Step 1: GCP Project Setup

### Prerequisites

Before running the setup script, you must have an existing GCP project. If you don't have one:

**Create a GCP Project** (choose one method):

**Via GCP Console**:
1. Go to [GCP Console - Create Project](https://console.cloud.google.com/projectcreate)
2. Enter a project name and project ID
3. Select a billing account
4. Click "Create"

**Via gcloud CLI**:
```bash
# Create project
gcloud projects create my-company-dev

# Link billing account
gcloud billing projects link my-company-dev --billing-account=<YOUR_BILLING_ACCOUNT_ID>

# To find your billing account ID:
gcloud billing accounts list
```

### Option A: Automated Setup (Recommended)

Use the provided setup script to configure your existing project:

```bash
# Run the setup script
./scripts/setup-gcp-projects.sh
```

The script will prompt you for:
1. **GCP Project ID** - Your existing project ID (e.g., `my-company-dev`)
2. **Environment name** - The environment name (e.g., `dev`, `staging`, `prod`)

**Recommended**: Start with a dev environment. You can add staging and prod later with additional projects.

The script will:
1. Check prerequisites (gcloud CLI, authentication)
2. Verify your project exists and has billing enabled
3. Enable all required APIs in the project
4. Create Terraform state bucket with versioning:
   - Bucket: `gs://{project-id}-terraform-state`
   - Environment prefix: `{environment}/`
   - Versioning and lifecycle policies enabled

**Expected duration**: 3-5 minutes per project

### Option B: Manual Setup

If you prefer manual setup, follow the instructions in [scripts/README.md](./scripts/README.md#manual-setup-alternative).

### Validate Setup

After setup completes, run the validation script:

```bash
# Replace with your actual project ID
./scripts/validate-setup.sh my-company-dev
```

Expected output:
```
Total checks: 15
Passed: 15
Warnings: 0
Failed: 0

✓ All validations passed! You're ready to proceed with Terraform deployment.
```

### Adding Staging/Prod Later

When you're ready to add staging or production environments:

1. **Create a new GCP project** (via Console or gcloud):
   ```bash
   gcloud projects create my-company-staging
   gcloud billing projects link my-company-staging --billing-account=<BILLING_ACCOUNT_ID>
   ```

2. **Run the setup script** for the new project:
   ```bash
   ./scripts/setup-gcp-projects.sh
   # Enter the new project ID and environment name when prompted
   ```

3. **Validate** the new environment:
   ```bash
   ./scripts/validate-setup.sh my-company-staging
   ```

---

## Step 2: Understand the Architecture

Before proceeding, review the architecture:

1. **Read [PLAN.md](./PLAN.md)**
   - Complete technical architecture
   - Module specifications
   - Environment configurations

2. **Read [CLAUDE.md](./CLAUDE.md)**
   - Quick reference guide
   - Common commands
   - Deployment workflows

**Key architectural decisions**:
- Separate GCP projects per environment (strong isolation)
- Region: europe-west6 (Zurich, Switzerland)
- Terraform modules for reusability
- Terragrunt for environment management

---

## Step 3: Project Structure Setup

The infrastructure code will be organized as follows:

```
infra/
├── modules/              # Terraform modules (Step 4)
├── stacks/               # Environment configurations (Step 5)
├── terragrunt.hcl        # Root Terragrunt config (Step 5)
└── common.hcl            # Shared configuration (Step 5)
```

You don't need to create these directories now - they'll be created in the next steps.

---

## Step 4: Create Terraform Modules

Create reusable Terraform modules for each infrastructure component.

### Modules to Create

1. **networking** - VPC, subnets, VPC connectors
2. **iam** - Service accounts and IAM bindings
3. **artifact-registry** - Docker image registry
4. **secret-manager** - Secrets storage
5. **cloud-sql** - PostgreSQL database
6. **pubsub** - Event queue
7. **cloud-run** - Serverless containers
8. **load-balancer** - HTTPS LB + Cloud Armor
9. **monitoring** - Dashboards and alerts

### Module Structure

Each module should have:
```
infra/modules/{module-name}/
├── main.tf          # Main resource definitions
├── variables.tf     # Input variables
├── outputs.tf       # Output values
└── README.md        # Module documentation
```

**Detailed specifications**: See [PLAN.md](./PLAN.md#terraform-modules-implementation)

---

## Step 5: Create Terragrunt Configurations

Configure Terragrunt for multi-environment management.

### Root Configuration

Create `infra/terragrunt.hcl`:

```hcl
# Remote state configuration
remote_state {
  backend = "gcs"
  config = {
    bucket         = "${get_env("TG_BUCKET_NAME", "PLACEHOLDER")}"
    prefix         = "${path_relative_to_include()}"
    project        = "${get_env("TG_PROJECT_ID", "PLACEHOLDER")}"
    location       = "europe-west6"
  }
}

# Generate provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
EOF
}

# Common inputs
inputs = {
  region = "europe-west6"
}
```

### Environment Configurations

Create configurations for each environment in `infra/stacks/{env}/`.

**Detailed specifications**: See [PLAN.md](./PLAN.md#terragrunt-stack-organization)

---

## Step 6: Deploy Infrastructure

### 6.1 Deploy to Dev Environment

```bash
cd infra/stacks/dev

# Initialize Terragrunt
terragrunt run-all init

# Preview changes
terragrunt run-all plan

# Deploy all components
terragrunt run-all apply
```

**Expected duration**: 20-30 minutes

### 6.2 Validate Dev Deployment

```bash
# Check Cloud Run services
gcloud run services list --project=generic-demo-dev --region=europe-west6

# Check CloudSQL instance
gcloud sql instances list --project=generic-demo-dev

# Check Pub/Sub topics
gcloud pubsub topics list --project=generic-demo-dev

# Test API health endpoint (after deploying application)
curl https://<load-balancer-ip>/health
```

### 6.3 Deploy to Staging and Prod

Once dev is validated:

```bash
# Staging
cd infra/stacks/staging
terragrunt run-all apply

# Prod
cd infra/stacks/prod
terragrunt run-all apply
```

---

## Step 7: Application Deployment

### 7.1 Build Docker Images

```bash
# Authenticate Docker with Artifact Registry
gcloud auth configure-docker europe-west6-docker.pkg.dev

# Build API image
docker build -t europe-west6-docker.pkg.dev/generic-demo-dev/api/nestjs-api:v1.0.0 ./apps/api

# Push to registry
docker push europe-west6-docker.pkg.dev/generic-demo-dev/api/nestjs-api:v1.0.0
```

### 7.2 Deploy to Cloud Run

Update the image URL in Terragrunt config and apply:

```bash
cd infra/stacks/dev/api-service
# Edit terragrunt.hcl to set image_url
terragrunt apply
```

Or use gcloud CLI directly:

```bash
gcloud run services update api-service \
  --image=europe-west6-docker.pkg.dev/generic-demo-dev/api/nestjs-api:v1.0.0 \
  --region=europe-west6 \
  --project=generic-demo-dev
```

### 7.3 Run Database Migrations

```bash
# Connect to CloudSQL via proxy
cloud_sql_proxy -instances=generic-demo-dev:europe-west6:<instance-name>=tcp:5432 &

# Run migrations
cd apps/api
npm run migration:run
```

---

## Step 8: Post-Deployment Configuration

### 8.1 Configure DNS

Point your domain to the load balancer IP:

```bash
# Get load balancer IP
gcloud compute addresses list --global --project=generic-demo-dev

# Create DNS A record
# example.com -> <load-balancer-ip>
```

### 8.2 Wait for SSL Certificate

Managed SSL certificates can take 15-60 minutes to provision. Monitor status:

```bash
gcloud compute ssl-certificates list --project=generic-demo-dev
```

### 8.3 Configure Monitoring Alerts

Update notification channels in the monitoring module:

```bash
cd infra/stacks/dev/monitoring
# Edit terragrunt.hcl to add email/Slack/PagerDuty
terragrunt apply
```

### 8.4 Set Up Budget Alerts

```bash
# Set up budget alerts in GCP Console
# https://console.cloud.google.com/billing/budgets
```

---

## Common Issues & Troubleshooting

### Issue: "Project already exists"

If projects already exist from a previous setup:

```bash
# Option 1: Use existing projects (skip project creation)
./scripts/validate-setup.sh

# Option 2: Delete and recreate
gcloud projects delete generic-demo-dev
gcloud projects delete generic-demo-staging
gcloud projects delete generic-demo-prod
# Then run setup script again
```

### Issue: "API not enabled"

Enable missing APIs manually:

```bash
gcloud services enable <api-name> --project=<project-id>
```

### Issue: Terraform state locked

If Terraform state is locked (usually from interrupted run):

```bash
# View locks
gsutil ls -L gs://generic-demo-dev-terraform-state/**/.terraform.lock.info

# Break lock (use with caution!)
terragrunt force-unlock <lock-id>
```

### Issue: CloudSQL connection timeout

Verify VPC connector:

```bash
gcloud compute networks vpc-access connectors list \
  --region=europe-west6 \
  --project=generic-demo-dev
```

### Issue: Cloud Run deployment fails

Check logs:

```bash
gcloud logging read "resource.type=cloud_run_revision AND severity=ERROR" \
  --limit=50 \
  --project=generic-demo-dev
```

**More troubleshooting**: See [CLAUDE.md#troubleshooting](./CLAUDE.md#troubleshooting)

---

## Next Steps

After successful setup:

1. **Deploy your application code**
   - Build and push Docker images
   - Update Terragrunt configs with image URLs
   - Deploy via `terragrunt apply`

2. **Set up CI/CD pipeline**
   - Configure Cloud Build or GitHub Actions
   - Automate builds and deployments

3. **Monitor and optimize**
   - Review Cloud Monitoring dashboards
   - Set up alerting policies
   - Optimize resource allocation based on usage

4. **Security hardening**
   - Review Cloud Armor rules
   - Enable VPC Service Controls (optional)
   - Implement least-privilege IAM policies

5. **Documentation**
   - Document environment-specific configurations
   - Create runbooks for common operations
   - Update team wiki/docs

---

## Cleanup (Development/Testing)

To tear down infrastructure:

```bash
# Destroy dev environment
cd infra/stacks/dev
terragrunt run-all destroy

# Delete GCP projects (complete cleanup)
gcloud projects delete generic-demo-dev
gcloud projects delete generic-demo-staging
gcloud projects delete generic-demo-prod

# Delete shared state bucket
gsutil -m rm -r gs://generic-demo-terraform-state
```

**WARNING**: This permanently deletes all resources and data. Use with caution!

---

## Additional Resources

- [PLAN.md](./PLAN.md) - Complete implementation plan
- [CLAUDE.md](./CLAUDE.md) - Operational reference guide
- [scripts/README.md](./scripts/README.md) - Setup scripts documentation
- [GCP Documentation](https://cloud.google.com/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)

---

## Getting Help

If you encounter issues:

1. Run validation script: `./scripts/validate-setup.sh`
2. Check [CLAUDE.md](./CLAUDE.md) troubleshooting section
3. Review GCP Console logs and monitoring
4. Check Terraform/Terragrunt error messages carefully
5. Consult GCP documentation for service-specific issues

---

**Last Updated**: December 2024
