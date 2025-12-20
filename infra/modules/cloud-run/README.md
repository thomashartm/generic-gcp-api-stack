# Cloud Run Module

This module creates a Cloud Run service with VPC connectivity, auto-scaling, and configurable resources.

## Resources Created

- **Cloud Run Service**: Serverless container service
- **IAM Bindings**: Permissions for invoking the service

## Usage

### API Service Example

```hcl
module "api_service" {
  source = "../../modules/cloud-run"

  project_id  = "my-project-dev"
  environment = "dev"
  region      = "europe-west6"

  service_name          = "api-service"
  image_url             = "europe-west6-docker.pkg.dev/my-project-dev/api/nestjs-api:v1.0.0"
  service_account_email = dependency.iam.outputs.api_service_account_email
  vpc_connector_id      = dependency.networking.outputs.vpc_connector_id

  # Scaling
  min_instances = 0
  max_instances = 10

  # Resources
  cpu_limit    = "1"
  memory_limit = "512Mi"

  # Security - only load balancer can invoke
  ingress                = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  allow_unauthenticated  = false

  # Environment variables
  env_vars = {
    NODE_ENV        = "production"
    PORT            = "3000"
    DB_HOST         = dependency.cloud_sql.outputs.private_ip_address
    PUBSUB_TOPIC    = dependency.pubsub.outputs.topic_name
  }

  # Secrets from Secret Manager
  secrets = {
    DB_PASSWORD = {
      secret_name = dependency.secret_manager.outputs.db_password_secret_id
      version     = "latest"
    }
    DB_USER = {
      secret_name = dependency.secret_manager.outputs.db_user_secret_id
      version     = "latest"
    }
  }
}
```

### Event Processor Example

```hcl
module "event_processor" {
  source = "../../modules/cloud-run"

  project_id  = "my-project-dev"
  environment = "dev"
  region      = "europe-west6"

  service_name          = "event-processor"
  image_url             = "europe-west6-docker.pkg.dev/my-project-dev/api/event-processor:v1.0.0"
  service_account_email = dependency.iam.outputs.event_processor_service_account_email
  vpc_connector_id      = dependency.networking.outputs.vpc_connector_id

  # Scaling
  min_instances = 0
  max_instances = 5

  # Security - only Pub/Sub can invoke
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_members = [
    "serviceAccount:service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
  ]

  # Environment and secrets
  env_vars = {
    NODE_ENV = "production"
    PORT     = "3000"
    DB_HOST  = dependency.cloud_sql.outputs.private_ip_address
  }

  secrets = {
    DB_PASSWORD = {
      secret_name = dependency.secret_manager.outputs.db_password_secret_id
      version     = "latest"
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| region | GCP region | string | europe-west6 | no |
| environment | Environment name | string | - | yes |
| service_name | Service name | string | - | yes |
| image_url | Container image URL | string | - | yes |
| service_account_email | Service account email | string | - | yes |
| vpc_connector_id | VPC connector ID | string | - | yes |
| vpc_egress | VPC egress setting | string | PRIVATE_RANGES_ONLY | no |
| min_instances | Minimum instances | number | 0 | no |
| max_instances | Maximum instances | number | 10 | no |
| cpu_limit | CPU limit | string | 1 | no |
| memory_limit | Memory limit | string | 512Mi | no |
| cpu_always_allocated | Always allocate CPU | bool | false | no |
| startup_cpu_boost | Enable startup CPU boost | bool | true | no |
| container_port | Container port | number | 3000 | no |
| env_vars | Environment variables | map(string) | {} | no |
| secrets | Secret environment variables | map(object) | {} | no |
| ingress | Ingress traffic setting | string | INGRESS_TRAFFIC_ALL | no |
| invoker_members | Allowed invokers | list(string) | [] | no |
| allow_unauthenticated | Allow public access | bool | false | no |
| request_timeout | Request timeout | string | 300s | no |
| max_concurrent_requests | Max concurrent requests | number | 80 | no |

## Outputs

| Name | Description |
|------|-------------|
| service_id | ID of the Cloud Run service |
| service_name | Name of the service |
| service_url | URL of the service |
| service_location | Location of the service |
| latest_revision_name | Latest revision name |

## Ingress Settings

- **INGRESS_TRAFFIC_ALL**: Public internet (use with authentication)
- **INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER**: Only from load balancer (recommended for API)
- **INGRESS_TRAFFIC_INTERNAL_ONLY**: Only from VPC and Cloud Run (recommended for event processor)

## Scaling Behavior

### Cold Starts
When `min_instances = 0`, the service scales to zero when idle. First request after idle triggers a cold start (~2-5 seconds).

### Warm Instances
Set `min_instances > 0` to keep instances warm and eliminate cold starts.

### Environment-Specific Recommendations

**Dev**:
```hcl
min_instances = 0  # Scale to zero to save costs
max_instances = 3
```

**Staging**:
```hcl
min_instances = 1  # Keep one instance warm
max_instances = 10
```

**Production**:
```hcl
min_instances = 2  # Keep instances warm and handle failover
max_instances = 50
cpu_always_allocated = true  # Faster response times
```

## Resource Configuration

### CPU Limits
- `"1"` (1 vCPU): Light workloads, up to ~100 req/s
- `"2"` (2 vCPU): Medium workloads, up to ~500 req/s
- `"4"` (4 vCPU): Heavy workloads, up to ~1000 req/s

### Memory Limits
- `"512Mi"`: Light workloads
- `"1Gi"`: Medium workloads
- `"2Gi"`: Heavy workloads, large in-memory caches

### CPU Allocation
- `cpu_always_allocated = false`: CPU only during request (cheaper)
- `cpu_always_allocated = true`: CPU always available (faster, recommended for prod)

## Health Checks

The module configures startup and liveness probes:

- **Startup Probe**: Checks if the service started successfully
- **Liveness Probe**: Checks if the service is healthy

Both probes use HTTP GET requests to `/health` by default.

### NestJS Health Check Example

```typescript
import { Controller, Get } from '@nestjs/common';
import { HealthCheck, HealthCheckService, TypeOrmHealthIndicator } from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
    ]);
  }
}
```

## Secrets from Secret Manager

Secrets are injected as environment variables:

```hcl
secrets = {
  DB_PASSWORD = {
    secret_name = "dev-db-password"
    version     = "latest"  # or specific version like "1"
  }
}
```

The application reads them as normal environment variables:
```typescript
const dbPassword = process.env.DB_PASSWORD;
```

## VPC Connectivity

The VPC connector allows Cloud Run to access:
- CloudSQL via private IP
- Other VPC resources

### VPC Egress Options
- `PRIVATE_RANGES_ONLY`: Only private IPs go through VPC (public traffic direct)
- `ALL_TRAFFIC`: All traffic goes through VPC (useful for Cloud NAT)

## Dependencies

- **networking**: VPC connector required
- **iam**: Service account required
- **secret-manager**: For secret environment variables
- **artifact-registry**: For container images