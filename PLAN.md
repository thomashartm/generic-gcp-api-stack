aStart# GCP Terraform Stack Implementation Plan

## Overview
Build a production-ready, multi-environment GCP infrastructure stack for a TypeScript NestJS API application using Terraform modules and Terragrunt for environment management.

## User Decisions
- **GCP Projects**: Separate projects for dev, staging, prod (stronger isolation)
- **Region**: europe-west6 (Zurich, Switzerland)
- **Domain**: User has domain (will be provided during implementation)
- **CI/CD**: Not included in this infrastructure stack (handled separately)

## Architecture Summary

```
Internet → Cloud Armor (WAF) → HTTPS Load Balancer → Cloud Run API
                                                            ↓
                                                       Pub/Sub Topic
                                                            ↓
                                                   Cloud Run Event Processor
                                                            ↓
                                              CloudSQL PostgreSQL (Private IP)
```

### Key Components
1. **Cloud Run** - Primary NestJS API service + Event processor service
2. **CloudSQL PostgreSQL** - Managed database with private IP access
3. **Global HTTPS Load Balancer** - SSL termination and routing
4. **Cloud Armor** - WAF protection with OWASP rules
5. **Pub/Sub** - Event queue for asynchronous processing
6. **VPC Network** - Private connectivity for Cloud Run → CloudSQL
7. **Secret Manager** - Database credentials and API keys
8. **Artifact Registry** - Docker image storage
9. **Cloud Monitoring** - Dashboards, alerts, logging

## Directory Structure

```
infra/
├── modules/                          # Reusable Terraform modules
│   ├── networking/                   # VPC, subnets, VPC connectors
│   ├── cloud-sql/                    # CloudSQL PostgreSQL
│   ├── secret-manager/               # Secret Manager secrets
│   ├── iam/                          # Service accounts and IAM
│   ├── artifact-registry/            # Docker registry
│   ├── cloud-run/                    # Cloud Run service
│   ├── pubsub/                       # Pub/Sub topics/subscriptions
│   ├── load-balancer/                # HTTPS LB + Cloud Armor
│   └── monitoring/                   # Dashboards, alerts, uptime checks
│
├── stacks/                           # Environment-specific configurations
│   ├── dev/
│   │   ├── terragrunt.hcl           # Dev environment config
│   │   ├── networking/terragrunt.hcl
│   │   ├── database/terragrunt.hcl
│   │   ├── api-service/terragrunt.hcl
│   │   ├── event-processor/terragrunt.hcl
│   │   ├── load-balancer/terragrunt.hcl
│   │   ├── pubsub/terragrunt.hcl
│   │   └── monitoring/terragrunt.hcl
│   ├── staging/                      # Same structure as dev
│   └── prod/                         # Same structure as dev
│
├── terragrunt.hcl                    # Root Terragrunt config
└── common.hcl                        # Shared configuration
```

## Terraform Modules Implementation

### 1. networking
**Path**: `infra/modules/networking/`

**Creates**:
- VPC network (one per environment)
- Serverless VPC Access connector (for Cloud Run → CloudSQL)
- Firewall rules (allow PostgreSQL from VPC connector, deny all else)
- Cloud NAT (for outbound internet access)

**Key Outputs**: `vpc_id`, `vpc_connector_id`, `subnet_ids`

---

### 2. iam
**Path**: `infra/modules/iam/`

**Creates**:
- Service account for API Cloud Run (roles: cloudsql.client, pubsub.publisher, secretmanager.secretAccessor)
- Service account for Event Processor Cloud Run (roles: cloudsql.client, pubsub.subscriber, secretmanager.secretAccessor)
- Project IAM bindings

**Key Outputs**: `service_account_emails` (map of SA name → email)

---

### 3. artifact-registry
**Path**: `infra/modules/artifact-registry/`

**Creates**:
- Docker Artifact Registry repository
- IAM bindings for Cloud Run to pull images

**Key Outputs**: `repository_id`, `repository_url`

---

### 4. secret-manager
**Path**: `infra/modules/secret-manager/`

**Creates**:
- Secrets for database credentials (user, password)
- IAM bindings for service accounts to access secrets

**Key Outputs**: `secret_ids` (map of secret name → secret ID)

---

### 5. cloud-sql
**Path**: `infra/modules/cloud-sql/`

**Creates**:
- CloudSQL PostgreSQL instance with private IP
- Database and user
- Automated backups
- HA configuration (regional for staging/prod, zonal for dev)

**Key Inputs**: `availability_type` (ZONAL/REGIONAL), `tier`, `disk_size`

**Key Outputs**: `instance_connection_name`, `private_ip_address`, `database_name`

---

### 6. pubsub
**Path**: `infra/modules/pubsub/`

**Creates**:
- Pub/Sub topic for events
- Push subscription to Event Processor Cloud Run
- Dead-letter topic for failed messages
- IAM bindings for publishers/subscribers

**Key Outputs**: `topic_id`, `subscription_ids`

---

### 7. cloud-run
**Path**: `infra/modules/cloud-run/`

**Creates**:
- Cloud Run service (reusable for both API and Event Processor)
- VPC connector attachment
- Environment variables and secret references
- IAM bindings for invoker permissions
- Auto-scaling configuration

**Key Inputs**:
- `service_name`, `image_url`
- `vpc_connector_id`, `service_account_email`
- `env_vars`, `secrets`
- `min_instances`, `max_instances`
- `ingress` (INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER for API)

**Key Outputs**: `service_url`, `service_name`

---

### 8. load-balancer
**Path**: `infra/modules/load-balancer/`

**Creates**:
- Global static IP address
- Managed SSL certificate (for user's domain)
- Backend service with Network Endpoint Group pointing to Cloud Run
- URL map and routing rules
- HTTPS proxy
- Global forwarding rule
- Cloud Armor security policy with OWASP rules

**Key Inputs**: `domains` (list), `cloud_run_service_name`

**Key Outputs**: `load_balancer_ip`, `ssl_certificate_id`, `armor_policy_id`

---

### 9. monitoring
**Path**: `infra/modules/monitoring/`

**Creates**:
- Monitoring dashboards (API metrics, database metrics, Pub/Sub metrics)
- Uptime checks for API endpoints
- Alert policies (error rate, latency, CloudSQL CPU/disk)
- Notification channels (email for dev/staging, consider PagerDuty for prod)

**Key Inputs**: `monitored_resources`, `alert_configs`, `uptime_check_urls`

**Key Outputs**: `dashboard_ids`, `alert_policy_ids`

---

## Terragrunt Stack Organization

### Root Configuration (`infra/terragrunt.hcl`)
- Remote state backend (GCS bucket: `generic-demo-terraform-state`)
- State organized by environment prefix (dev/, staging/, prod/)
- Provider configuration
- Global inputs (organization ID, billing account)

### Environment Configuration (`infra/stacks/{env}/terragrunt.hcl`)
- Environment-specific inputs:
  - `project_id` (different for dev/staging/prod)
  - `region` = "europe-west6"
  - `environment` = "dev" | "staging" | "prod"
- Include root config
- Set locals for environment name

### Component Configuration Example (`infra/stacks/dev/database/terragrunt.hcl`)
```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/cloud-sql"
}

dependency "networking" {
  config_path = "../networking"
}

dependency "secret_manager" {
  config_path = "../secret-manager"
}

inputs = {
  project_id        = "my-project-dev"
  region            = "europe-west6"
  environment       = "dev"
  database_version  = "POSTGRES_15"
  tier              = "db-f1-micro"              # Dev: smallest tier
  disk_size         = 10
  availability_type = "ZONAL"                     # Dev: no HA
  network_id        = dependency.networking.outputs.vpc_id
}
```

## Module Dependencies & Deployment Order

**Phase 1: Foundation**
1. `iam` - No dependencies
2. `artifact-registry` - Depends on: iam
3. `networking` - No dependencies

**Phase 2: Data Layer**
4. `secret-manager` - Depends on: iam
5. `cloud-sql` - Depends on: networking, secret-manager

**Phase 3: Compute & Messaging**
6. `pubsub` - Depends on: iam
7. `cloud-run` (API) - Depends on: networking, iam, artifact-registry, cloud-sql, secret-manager, pubsub
8. `cloud-run` (Event Processor) - Depends on: networking, iam, artifact-registry, cloud-sql, secret-manager, pubsub

**Phase 4: Routing & Security**
9. `load-balancer` - Depends on: cloud-run (API)

**Phase 5: Observability**
10. `monitoring` - Depends on: cloud-run, cloud-sql, load-balancer

## Environment-Specific Configurations

### Dev Environment
- CloudSQL: `db-f1-micro`, ZONAL (no HA), 10GB disk
- Cloud Run API: min 0, max 3 instances
- Cloud Run Event Processor: min 0, max 2 instances
- Cloud Armor: Basic rules only
- Monitoring: Email alerts only

### Staging Environment
- CloudSQL: `db-custom-1-4096`, REGIONAL (HA), 50GB disk
- Cloud Run API: min 1, max 10 instances
- Cloud Run Event Processor: min 0, max 5 instances
- Cloud Armor: Production-like rules
- Monitoring: Full dashboards and email alerts

### Prod Environment
- CloudSQL: `db-custom-4-16384`, REGIONAL (HA), 100GB disk, automated backups
- Cloud Run API: min 2, max 50 instances
- Cloud Run Event Processor: min 1, max 20 instances
- Cloud Armor: Strict OWASP rules, rate limiting (100 req/min per IP)
- Monitoring: Comprehensive dashboards, critical alerts (consider PagerDuty)

## Implementation Steps

### Step 0: Repository Documentation Setup
**Create documentation files in repository root**:

1. **PLAN.md** - Copy this plan to `/Users/thomas/projects/generic-gcp-api-stack/PLAN.md`
   - Full implementation plan for reference
   - Keep synced with any major architecture changes

2. **CLAUDE.md** - Create `/Users/thomas/projects/generic-gcp-api-stack/CLAUDE.md`
   - Quick reference guide for working with this infrastructure
   - Include common commands, deployment workflows
   - Document environment-specific details
   - Add troubleshooting tips

### Step 1: Project Setup
1. Create GCP project(s): Start with `generic-demo-dev` (add staging/prod later)
2. Enable required APIs:
   - Compute Engine API
   - Cloud Run API
   - Cloud SQL Admin API
   - VPC Access API
   - Secret Manager API
   - Artifact Registry API
   - Pub/Sub API
   - Cloud Armor API
3. Create shared GCS bucket for Terraform state: `gs://generic-demo-terraform-state`
   - Located in dev project
   - Environment prefixes: `dev/`, `staging/`, `prod/`
   - Versioning enabled

### Step 2: Create Terraform Modules
Create all 9 modules in `infra/modules/`:
- Each module has: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- Follow consistent naming conventions
- Add input validation where appropriate
- Document all variables and outputs

### Step 3: Create Terragrunt Configurations
1. Create root `infra/terragrunt.hcl`
2. Create `infra/common.hcl` with shared locals
3. Create environment configs in `infra/stacks/{env}/`
4. Create component configs with dependency blocks

### Step 4: Deploy to Dev
```bash
cd infra/stacks/dev
terragrunt run-all plan   # Review all changes
terragrunt run-all apply  # Deploy everything
```

### Step 5: Validate Dev Environment
- Test API health endpoint via load balancer
- Test Cloud Run → CloudSQL connectivity
- Test event publishing to Pub/Sub
- Test event processor receiving messages
- Validate Cloud Armor blocking test attacks

### Step 6: Deploy to Staging & Prod
Repeat deployment process for staging and prod with environment-specific configurations.

## Critical Files to Create

**Root Configuration**:
- `infra/terragrunt.hcl` - Remote state, provider config
- `infra/common.hcl` - Shared locals and functions

**Modules** (9 modules × 4 files each = 36 files):
- `infra/modules/{module}/main.tf`
- `infra/modules/{module}/variables.tf`
- `infra/modules/{module}/outputs.tf`
- `infra/modules/{module}/README.md`

**Stack Configurations** (3 environments × 8 components each):
- `infra/stacks/dev/terragrunt.hcl` (+ staging, prod)
- `infra/stacks/{env}/networking/terragrunt.hcl`
- `infra/stacks/{env}/database/terragrunt.hcl`
- `infra/stacks/{env}/api-service/terragrunt.hcl`
- `infra/stacks/{env}/event-processor/terragrunt.hcl`
- `infra/stacks/{env}/load-balancer/terragrunt.hcl`
- `infra/stacks/{env}/pubsub/terragrunt.hcl`
- `infra/stacks/{env}/monitoring/terragrunt.hcl`

**Documentation**:
- `PLAN.md` - This complete implementation plan (repository root)
- `CLAUDE.md` - Quick reference guide (repository root)
- `infra/README.md` - Overall infrastructure documentation
- `.gitignore` - Ignore `.terraform/`, `*.tfstate`, etc.

### CLAUDE.md Contents

The `CLAUDE.md` file should include:

**Project Overview**:
- Brief description of the infrastructure stack
- Architecture diagram (ASCII or reference to diagram)
- Technology stack (Terraform, Terragrunt, GCP services)

**Quick Start**:
- Prerequisites (gcloud CLI, Terraform, Terragrunt installed)
- Authentication setup (`gcloud auth application-default login`)
- Initial deployment commands

**Common Commands**:
```bash
# Plan all changes for dev environment
cd infra/stacks/dev
terragrunt run-all plan

# Apply all changes for dev environment
terragrunt run-all apply

# Deploy specific component
cd infra/stacks/dev/api-service
terragrunt apply

# Destroy environment (careful!)
cd infra/stacks/dev
terragrunt run-all destroy
```

**Environment Details**:
- Project IDs for each environment
- Region: europe-west6
- Links to GCP Console dashboards

**Deployment Workflow**:
1. Build Docker image and push to Artifact Registry
2. Update image tag in Terragrunt config
3. Run `terragrunt apply` for the Cloud Run component
4. Verify deployment via monitoring dashboard

**Troubleshooting**:
- Common errors and solutions
- How to access Cloud Run logs
- How to connect to CloudSQL for debugging
- How to manually trigger Pub/Sub messages

**Useful Links**:
- GCP Console links for each environment
- Monitoring dashboards
- Cloud Logging queries
- Artifact Registry URLs

## Security Considerations

1. **CloudSQL**: Private IP only, no public IP
2. **Service Accounts**: Least-privilege IAM roles
3. **Secrets**: Store in Secret Manager, reference in Cloud Run env vars
4. **Cloud Armor**: Enable OWASP Top 10 rules, rate limiting
5. **Network**: VPC firewall rules restrict traffic
6. **SSL/TLS**: Managed certificates, TLS 1.2+ enforced
7. **Cloud Run Ingress**: API restricted to load balancer traffic only

## Post-Deployment Tasks

1. **DNS Configuration**: Point domain to load balancer IP
2. **SSL Certificate**: Wait for managed certificate provisioning (can take 15-60 min)
3. **Application Deployment**: Build and push Docker images to Artifact Registry
4. **Database Schema**: Run initial migration scripts
5. **Testing**: Smoke tests, integration tests, load tests
6. **Documentation**: Update runbooks with environment-specific details

## Notes

- All resources will be tagged with `environment` label for cost tracking
- Terraform state stored in GCS with versioning enabled
- CloudSQL automated backups retained for 7 days (dev), 30 days (prod)
- Cloud Run logs automatically sent to Cloud Logging
- Budget alerts recommended for cost monitoring
