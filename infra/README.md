# Infrastructure

This directory contains the Terraform modules and Terragrunt configurations for managing the GCP infrastructure stack.

## Directory Structure

```
infra/
├── modules/                    # Reusable Terraform modules
│   ├── networking/            # VPC, subnets, VPC connectors
│   ├── iam/                   # Service accounts and IAM
│   ├── artifact-registry/     # Docker registry
│   ├── secret-manager/        # Secret Manager secrets
│   ├── cloud-sql/             # CloudSQL PostgreSQL
│   ├── pubsub/                # Pub/Sub topics/subscriptions
│   ├── cloud-run/             # Cloud Run service
│   ├── load-balancer/         # HTTPS LB + Cloud Armor
│   └── monitoring/            # Dashboards, alerts, uptime checks
│
├── stacks/                    # Environment-specific configurations
│   ├── dev/                   # Development environment
│   ├── staging/               # Staging environment (optional)
│   └── prod/                  # Production environment (optional)
│
├── terragrunt.hcl             # Root Terragrunt config
├── common.hcl                 # Shared configuration
└── README.md                  # This file
```

## Getting Started

### Prerequisites

1. Install required tools:
   - Terraform v1.5+
   - Terragrunt v0.50+
   - gcloud CLI

2. Authenticate with GCP:
   ```bash
   gcloud auth application-default login
   ```

3. Set up GCP projects using the setup script:
   ```bash
   ./scripts/setup-gcp-projects.sh
   ```

### Deploying Infrastructure

Deploy to the dev environment:

```bash
cd stacks/dev
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```

## Modules

Each module is self-contained and reusable across environments. See individual module READMEs for details:

- [networking](modules/vpc/README.md)
- [iam](./modules/iam/README.md)
- [artifact-registry](./modules/artifact-registry/README.md)
- [secret-manager](./modules/secret-manager/README.md)
- [cloud-sql](./modules/cloud-sql/README.md)
- [pubsub](./modules/pubsub/README.md)
- [cloud-run](./modules/cloud-run/README.md)
- [load-balancer](./modules/load-balancer/README.md)
- [monitoring](./modules/monitoring/README.md)

## Terragrunt Configuration

### Root Configuration (`terragrunt.hcl`)

Defines:
- Remote state backend (GCS)
- Provider generation
- Common inputs

### Environment Configuration (`stacks/{env}/terragrunt.hcl`)

Each environment (dev, staging, prod) has its own configuration with:
- Project ID
- Environment-specific settings
- Resource sizing

### Component Configuration (`stacks/{env}/{component}/terragrunt.hcl`)

Each component references a module and defines:
- Dependencies on other components
- Component-specific inputs

## Deployment Order

Components must be deployed in the following order due to dependencies:

1. **Foundation**: iam, artifact-registry, networking
2. **Data Layer**: secret-manager, cloud-sql
3. **Compute & Messaging**: pubsub, cloud-run (API), cloud-run (Event Processor)
4. **Routing & Security**: load-balancer
5. **Observability**: monitoring

Using `terragrunt run-all` handles dependencies automatically.

## Common Commands

```bash
# Plan all changes in an environment
cd stacks/dev
terragrunt run-all plan

# Apply all changes
terragrunt run-all apply

# Deploy a specific component
cd stacks/dev/api-service
terragrunt apply

# Destroy an environment
cd stacks/dev
terragrunt run-all destroy
```

## For More Information

- See [PLAN.md](../PLAN.md) for the complete implementation plan
- See [CLAUDE.md](../CLAUDE.md) for quick reference and common operations
- See [SETUP.md](../SETUP.md) for setup instructions