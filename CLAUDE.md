# GCP API Stack - Quick Reference Guide

## Project Overview

This repository contains a production-ready, multi-environment GCP infrastructure stack for hosting a NestJS API application with event processing capabilities.

### Architecture

```
Internet → Cloud Armor (WAF) → HTTPS Load Balancer → Cloud Run API
                                                            ↓
                                                       Pub/Sub Topic
                                                            ↓
                                                   Cloud Run Event Processor
                                                            ↓
                                              CloudSQL PostgreSQL (Private IP)
```

### Technology Stack
- **IaC**: Terraform (modules) + Terragrunt (environment management)
- **Compute**: Google Cloud Run (serverless containers)
- **Database**: CloudSQL PostgreSQL (managed database)
- **Networking**: VPC, Cloud Load Balancer, Cloud Armor WAF
- **Messaging**: Cloud Pub/Sub
- **Storage**: Artifact Registry (Docker images), Secret Manager (credentials)
- **Monitoring**: Cloud Monitoring, Cloud Logging, Cloud Trace

### Environments
- **Dev**: europe-west6, minimal resources, no HA
- **Staging**: europe-west6, production-like, with HA
- **Prod**: europe-west6, full HA, auto-scaling, strict security

---

## Prerequisites

Before working with this infrastructure, ensure you have:

1. **gcloud CLI** installed and configured
   ```bash
   # Install: https://cloud.google.com/sdk/docs/install
   gcloud version
   ```

2. **Terraform** (v1.5+)
   ```bash
   # Install: https://developer.hashicorp.com/terraform/install
   terraform version
   ```

3. **Terragrunt** (v0.50+)
   ```bash
   # Install: https://terragrunt.gruntwork.io/docs/getting-started/install/
   terragrunt --version
   ```

4. **GCP Authentication**
   ```bash
   # Login to GCP
   gcloud auth login

   # Set application default credentials for Terraform
   gcloud auth application-default login

   # Set your active project
   gcloud config set project <your-project-id>
   ```

---

## Quick Start

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd generic-gcp-api-stack
   ```

2. **Update GCP project IDs**
   Edit `infra/stacks/{env}/terragrunt.hcl` for each environment and set your project IDs.

3. **Initialize Terraform state backend**
   Ensure GCS buckets for Terraform state exist (created manually or via setup script).

4. **Deploy infrastructure**
   ```bash
   # Deploy dev environment
   cd infra/stacks/dev
   terragrunt run-all init
   terragrunt run-all plan
   terragrunt run-all apply
   ```

---

## Common Commands

### Infrastructure Management

#### Plan changes (preview)
```bash
# Plan all components in dev environment
cd infra/stacks/dev
terragrunt run-all plan

# Plan specific component
cd infra/stacks/dev/api-service
terragrunt plan
```

#### Apply changes (deploy)
```bash
# Apply all components in dev environment
cd infra/stacks/dev
terragrunt run-all apply

# Apply specific component
cd infra/stacks/dev/database
terragrunt apply

# Auto-approve (skip confirmation)
terragrunt apply --terragrunt-non-interactive
```

#### Destroy resources
```bash
# Destroy entire dev environment (CAREFUL!)
cd infra/stacks/dev
terragrunt run-all destroy

# Destroy specific component
cd infra/stacks/dev/monitoring
terragrunt destroy
```

#### Refresh state
```bash
# Refresh Terraform state with real infrastructure
cd infra/stacks/dev
terragrunt run-all refresh
```

### Application Deployment

#### Build and push Docker image
```bash
# Authenticate Docker with Artifact Registry
gcloud auth configure-docker europe-west6-docker.pkg.dev

# Build image
docker build -t europe-west6-docker.pkg.dev/<project-id>/api/nestjs-api:v1.0.0 ./apps/api

# Push image
docker push europe-west6-docker.pkg.dev/<project-id>/api/nestjs-api:v1.0.0
```

#### Update Cloud Run service with new image
```bash
# Option 1: Update Terragrunt config and apply
# Edit infra/stacks/dev/api-service/terragrunt.hcl
# Change image_url to new version
cd infra/stacks/dev/api-service
terragrunt apply

# Option 2: Use gcloud CLI directly (quick update)
gcloud run services update api-service \
  --image=europe-west6-docker.pkg.dev/<project-id>/api/nestjs-api:v1.0.0 \
  --region=europe-west6 \
  --project=<project-id>
```

### Database Management

#### Connect to CloudSQL
```bash
# Connect via Cloud SQL Proxy
cloud_sql_proxy -instances=<project-id>:europe-west6:<instance-name>=tcp:5432

# In another terminal, connect with psql
psql "host=127.0.0.1 port=5432 dbname=<database-name> user=<db-user>"
```

#### Run database migrations
```bash
# From your application directory
cd apps/api
npm run migration:run
```

### Monitoring & Debugging

#### View Cloud Run logs
```bash
# View logs for API service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=api-service" \
  --limit=50 \
  --project=<project-id> \
  --format=json

# Follow logs in real-time
gcloud alpha run services logs tail api-service \
  --project=<project-id> \
  --region=europe-west6
```

#### View CloudSQL logs
```bash
# View database logs
gcloud logging read "resource.type=cloudsql_database" \
  --limit=50 \
  --project=<project-id>
```

#### Test Pub/Sub manually
```bash
# Publish test message
gcloud pubsub topics publish events-topic \
  --message='{"event": "test", "data": "hello"}' \
  --project=<project-id>

# Pull messages from subscription (if using pull)
gcloud pubsub subscriptions pull events-subscription \
  --auto-ack \
  --limit=10 \
  --project=<project-id>
```

---

## Environment Details

### Dev Environment
- **Project ID**: `generic-demo-dev`
- **Region**: europe-west6
- **State Path**: `gs://generic-demo-terraform-state/dev/`
- **CloudSQL**: db-f1-micro, ZONAL, 10GB
- **Cloud Run**: 0-3 instances (scales to zero)
- **Purpose**: Development and testing

### Staging Environment (Optional)
- **Project ID**: `generic-demo-staging`
- **Region**: europe-west6
- **State Path**: `gs://generic-demo-terraform-state/staging/`
- **CloudSQL**: db-custom-1-4096, REGIONAL (HA), 50GB
- **Cloud Run**: 1-10 instances
- **Purpose**: Pre-production validation

### Prod Environment (Optional)
- **Project ID**: `generic-demo-prod`
- **Region**: europe-west6
- **State Path**: `gs://generic-demo-terraform-state/prod/`
- **CloudSQL**: db-custom-4-16384, REGIONAL (HA), 100GB
- **Cloud Run**: 2-50 instances (always warm)
- **Purpose**: Production workloads

### Terraform State Storage
- **Bucket**: `gs://generic-demo-terraform-state` (in dev project)
- **Structure**:
  - `dev/` - Development environment state
  - `staging/` - Staging environment state
  - `prod/` - Production environment state

---

## Deployment Workflow

### Standard Deployment Process

1. **Make code changes** in `apps/api` or `apps/event-processor`

2. **Test locally**
   ```bash
   cd apps/api
   npm install
   npm run test
   npm run build
   ```

3. **Build Docker image**
   ```bash
   docker build -t europe-west6-docker.pkg.dev/<project-id>/api/nestjs-api:v1.0.1 ./apps/api
   ```

4. **Push to Artifact Registry**
   ```bash
   docker push europe-west6-docker.pkg.dev/<project-id>/api/nestjs-api:v1.0.1
   ```

5. **Update infrastructure config**
   ```bash
   # Edit infra/stacks/dev/api-service/terragrunt.hcl
   # Update image_url to v1.0.1
   ```

6. **Deploy via Terragrunt**
   ```bash
   cd infra/stacks/dev/api-service
   terragrunt apply
   ```

7. **Verify deployment**
   ```bash
   # Check service health
   curl https://<load-balancer-ip>/health

   # View logs
   gcloud alpha run services logs tail api-service --project=<project-id> --region=europe-west6
   ```

8. **Promote to staging/prod**
   ```bash
   # Repeat steps 5-7 for staging and prod environments
   ```

---

## Troubleshooting

### Common Errors

#### Error: "Permission denied" when deploying
**Solution**: Ensure your gcloud credentials have the necessary IAM roles.
```bash
# Re-authenticate
gcloud auth application-default login

# Verify active account
gcloud auth list

# Verify project
gcloud config get-value project
```

#### Error: Cloud Run service fails to start
**Possible causes**:
1. Database connection issues (check VPC connector)
2. Missing environment variables or secrets
3. Image build errors

**Debugging**:
```bash
# Check Cloud Run service details
gcloud run services describe api-service --region=europe-west6 --project=<project-id>

# View logs for startup errors
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=api-service AND severity=ERROR" \
  --limit=20 \
  --project=<project-id>
```

#### Error: CloudSQL connection timeout
**Solution**: Verify VPC connector is properly configured.
```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors list \
  --region=europe-west6 \
  --project=<project-id>

# Ensure CloudSQL has private IP
gcloud sql instances describe <instance-name> \
  --project=<project-id> | grep ipAddress
```

#### Error: Pub/Sub messages not being received
**Debugging**:
```bash
# Check subscription status
gcloud pubsub subscriptions describe events-subscription --project=<project-id>

# Check undelivered messages
gcloud pubsub subscriptions pull events-subscription --limit=1 --project=<project-id>

# Check event processor logs
gcloud alpha run services logs tail event-processor --project=<project-id> --region=europe-west6
```

### Terragrunt Issues

#### Error: "Remote state not initialized"
```bash
# Initialize backend
cd infra/stacks/dev
terragrunt run-all init
```

#### Error: Dependency cycle detected
**Solution**: Review `dependency` blocks in terragrunt.hcl files. Ensure no circular dependencies.

#### Error: "No such file or directory" for module source
**Solution**: Verify `source` path in terragrunt.hcl points to correct module directory.

---

## Useful Links

### GCP Console Links

**Dev Environment**:
- [Cloud Run Services](https://console.cloud.google.com/run?project=<update-me>-dev)
- [CloudSQL Instances](https://console.cloud.google.com/sql/instances?project=<update-me>-dev)
- [Pub/Sub Topics](https://console.cloud.google.com/cloudpubsub/topic/list?project=<update-me>-dev)
- [Load Balancers](https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=<update-me>-dev)
- [Monitoring Dashboards](https://console.cloud.google.com/monitoring/dashboards?project=<update-me>-dev)
- [Logs Explorer](https://console.cloud.google.com/logs?project=<update-me>-dev)

**Staging Environment**:
- [Cloud Run Services](https://console.cloud.google.com/run?project=<update-me>-staging)
- [Monitoring Dashboards](https://console.cloud.google.com/monitoring/dashboards?project=<update-me>-staging)

**Prod Environment**:
- [Cloud Run Services](https://console.cloud.google.com/run?project=<update-me>-prod)
- [Monitoring Dashboards](https://console.cloud.google.com/monitoring/dashboards?project=<update-me>-prod)
- [Alert Policies](https://console.cloud.google.com/monitoring/alerting/policies?project=<update-me>-prod)

### Documentation
- [PLAN.md](./PLAN.md) - Complete implementation plan
- [Terraform Modules](./infra/modules/) - Module-specific READMEs
- [GCP Cloud Run Docs](https://cloud.google.com/run/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)

---

## Useful Cloud Logging Queries

### Application Errors
```
resource.type="cloud_run_revision"
resource.labels.service_name="api-service"
severity>=ERROR
```

### Slow Database Queries
```
resource.type="cloudsql_database"
log_name="projects/<project-id>/logs/cloudsql.googleapis.com%2Fpostgres.log"
jsonPayload.message=~"duration:.*ms"
```

### Cloud Armor Blocked Requests
```
resource.type="http_load_balancer"
jsonPayload.enforcedSecurityPolicy.name!=""
```

### Pub/Sub Delivery Failures
```
resource.type="pubsub_subscription"
severity>=ERROR
```

---

## Tips & Best Practices

1. **Always test in dev first**: Deploy changes to dev, validate, then promote to staging and prod.

2. **Use Terragrunt run-all carefully**: It deploys all components in parallel. For granular control, apply components individually.

3. **Monitor costs**: Set up budget alerts in GCP Console for each project.

4. **Tag resources**: All resources are tagged with `environment` label. Use this for cost allocation.

5. **Backup before major changes**: Take CloudSQL snapshots before schema migrations.

6. **Keep secrets in Secret Manager**: Never commit credentials to git.

7. **Review Cloud Armor logs**: Regularly check for blocked malicious traffic.

8. **Set up alerting**: Configure notification channels (email, Slack, PagerDuty) for production alerts.

9. **Use Cloud Build for CI/CD**: Integrate Cloud Build or GitHub Actions for automated deployments.

10. **Document environment changes**: Update this file when adding new components or changing configurations.

---

## Getting Help

For questions or issues:
1. Check [PLAN.md](./PLAN.md) for detailed architecture information
2. Review module READMEs in `infra/modules/`
3. Consult GCP documentation for service-specific issues
4. Check Terraform/Terragrunt documentation for IaC issues

---

**Last Updated**: [Update after significant changes]
