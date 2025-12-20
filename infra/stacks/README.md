# Infrastructure Stacks

This directory contains environment-specific Terragrunt configurations for dev, staging, and production.

## Directory Structure

```
stacks/
├── dev/                    # Development environment
├── staging/                # Staging environment (optional)
└── prod/                   # Production environment (optional)
```

## Getting Started

### Prerequisites

1. **GCP Projects**: Create GCP projects for each environment
   - Dev: `your-project-dev`
   - Staging: `your-project-staging` (optional)
   - Prod: `your-project-prod` (optional)

2. **Run Setup Script**: Enable APIs and create state buckets
   ```bash
   ./scripts/setup-gcp-projects.sh
   ```

3. **Update Project IDs**: Edit `terragrunt.hcl` in each environment directory
   - Update `project_id` with your actual project ID

4. **Configure Secrets**: Update database passwords in `secret-manager/terragrunt.hcl`
   - Use environment variables: `export TF_VAR_db_password="your-secure-password"`

5. **Update Image URLs**: Update container image URLs in Cloud Run configs
   - After building and pushing images to Artifact Registry

## Deploying Environments

### Dev Environment

```bash
cd dev
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```

### Staging Environment

```bash
cd staging
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```

### Production Environment

```bash
cd prod
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```

## Environment Differences

### Dev
- **Purpose**: Development and testing
- **Resources**: Minimal (scale to zero, smallest DB tier)
- **HA**: Disabled (ZONAL database)
- **Cloud Armor**: Basic protection
- **Alerts**: Disabled
- **Cost**: ~$10-30/month (when active)

### Staging
- **Purpose**: Pre-production validation
- **Resources**: Production-like
- **HA**: Enabled (REGIONAL database)
- **Cloud Armor**: Full OWASP rules
- **Alerts**: Enabled
- **Cost**: ~$100-200/month

### Production
- **Purpose**: Live production workloads
- **Resources**: High availability, always warm
- **HA**: Enabled with read replicas
- **Cloud Armor**: Full protection with DDoS
- **Alerts**: Critical alerts to PagerDuty
- **Cost**: Varies based on traffic

## Deployment Order

Components are deployed in order based on dependencies:

1. **Foundation** (parallel):
   - IAM
   - Networking
   - Artifact Registry

2. **Data Layer** (parallel):
   - Secret Manager
   - Database (depends on Networking)

3. **Services** (sequential):
   - Event Processor (depends on IAM, Networking, Database, Secrets)
   - API Service (depends on IAM, Networking, Database, Secrets)
   - Pub/Sub (depends on Event Processor)

4. **Routing** (sequential):
   - Load Balancer (depends on API Service)

5. **Observability** (sequential):
   - Monitoring (depends on all services)

Using `terragrunt run-all` handles this automatically.

## Creating Staging and Prod Environments

The dev environment is fully configured. To create staging and prod:

### Option 1: Copy and Modify Dev Configuration

```bash
# Create staging
cp -r dev staging
cd staging

# Update all terragrunt.hcl files:
# 1. Change project_id to staging project
# 2. Update resource sizes (see below)
# 3. Enable HA settings

# Create prod
cp -r dev prod
cd prod

# Update all terragrunt.hcl files for production settings
```

### Option 2: Use Provided Templates

Staging and prod configurations are included in this repository. Update:
1. Project IDs
2. Database passwords
3. Notification emails
4. Domains for SSL certificates

## Key Configuration Differences

### Database (`database/terragrunt.hcl`)

**Dev:**
```hcl
tier              = "db-f1-micro"
availability_type = "ZONAL"
disk_size         = 10
deletion_protection = false
```

**Staging:**
```hcl
tier              = "db-custom-1-4096"
availability_type = "REGIONAL"
disk_size         = 50
deletion_protection = true
```

**Prod:**
```hcl
tier              = "db-custom-4-16384"
availability_type = "REGIONAL"
disk_size         = 100
deletion_protection = true
read_replica_count = 1
```

### Cloud Run (`api-service/terragrunt.hcl`, `event-processor/terragrunt.hcl`)

**Dev:**
```hcl
min_instances = 0
max_instances = 3
cpu_limit     = "1"
memory_limit  = "512Mi"
```

**Staging:**
```hcl
min_instances = 1
max_instances = 10
cpu_limit     = "1"
memory_limit  = "1Gi"
```

**Prod:**
```hcl
min_instances        = 2
max_instances        = 50
cpu_limit            = "2"
memory_limit         = "2Gi"
cpu_always_allocated = true
```

### Load Balancer (`load-balancer/terragrunt.hcl`)

**Dev:**
```hcl
domains                    = []
enable_owasp_rules         = false
rate_limit_threshold       = 1000
enable_adaptive_protection = false
```

**Staging:**
```hcl
domains                    = ["staging-api.example.com"]
enable_owasp_rules         = true
rate_limit_threshold       = 500
enable_adaptive_protection = false
```

**Prod:**
```hcl
domains                    = ["api.example.com"]
enable_owasp_rules         = true
rate_limit_threshold       = 100
enable_adaptive_protection = true
blocked_countries          = ["CN", "RU"]
```

### Monitoring (`monitoring/terragrunt.hcl`)

**Dev:**
```hcl
enable_alerts            = false
error_rate_threshold     = 10
latency_threshold_ms     = 2000
```

**Staging:**
```hcl
enable_alerts            = true
notification_emails      = ["devops@example.com"]
error_rate_threshold     = 5
latency_threshold_ms     = 1000
```

**Prod:**
```hcl
enable_alerts                    = true
notification_emails              = ["oncall@example.com", "devops@example.com"]
error_rate_threshold             = 1
latency_threshold_ms             = 500
pubsub_old_message_threshold_sec = 300
```

## Common Tasks

### Deploy Specific Component

```bash
cd dev/database
terragrunt apply
```

### Update Cloud Run Image

```bash
# Option 1: Update terragrunt.hcl and apply
cd dev/api-service
# Edit terragrunt.hcl - update image_url
terragrunt apply

# Option 2: Use gcloud CLI directly
gcloud run services update api-service \
  --image=europe-west6-docker.pkg.dev/PROJECT/api/nestjs-api:v1.0.1 \
  --region=europe-west6 \
  --project=PROJECT_ID
```

### View Terraform State

```bash
cd dev/database
terragrunt state list
terragrunt state show google_sql_database_instance.postgres
```

### Destroy Environment

```bash
cd dev
terragrunt run-all destroy
```

## Troubleshooting

### Error: Project ID not found

Update `project_id` in `terragrunt.hcl` for the environment.

### Error: Image not found

Build and push Docker image to Artifact Registry first, then update `image_url` in Cloud Run configs.

### Error: Permission denied

Run `gcloud auth application-default login` to authenticate Terraform.

### Error: Remote state bucket not found

Run the setup script: `./scripts/setup-gcp-projects.sh`

## Best Practices

1. **Always deploy to dev first** before staging or prod
2. **Use environment variables** for secrets, never commit them
3. **Tag your infrastructure** changes with git tags
4. **Test changes** in dev before applying to prod
5. **Review Terraform plans** carefully before applying
6. **Keep environments in sync** (same Terraform/Terragrunt versions)
7. **Document changes** in commit messages
8. **Set up budget alerts** in GCP for cost monitoring

## Next Steps

After deploying infrastructure:

1. **Build and push application images** to Artifact Registry
2. **Update Cloud Run image URLs** and redeploy
3. **Configure DNS** to point to load balancer IP
4. **Wait for SSL certificates** to provision (15-60 minutes)
5. **Run database migrations** via Cloud SQL Proxy
6. **Test API endpoints** via load balancer
7. **Set up monitoring alerts** (add notification emails)
8. **Configure CI/CD** for automated deployments

For detailed instructions, see [SETUP.md](../../SETUP.md) and [CLAUDE.md](../../CLAUDE.md).