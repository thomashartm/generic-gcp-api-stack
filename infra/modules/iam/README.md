# IAM Module

This module creates service accounts and IAM bindings for Cloud Run services.

## Resources Created

### Service Accounts
- **API Service Account**: Used by the API Cloud Run service
- **Event Processor Service Account**: Used by the Event Processor Cloud Run service

### IAM Bindings (API Service Account)
- `roles/cloudsql.client` - Connect to CloudSQL
- `roles/pubsub.publisher` - Publish messages to Pub/Sub
- `roles/secretmanager.secretAccessor` - Read secrets
- `roles/cloudtrace.agent` - Write traces
- `roles/logging.logWriter` - Write logs
- `roles/monitoring.metricWriter` - Write custom metrics

### IAM Bindings (Event Processor Service Account)
- `roles/cloudsql.client` - Connect to CloudSQL
- `roles/pubsub.subscriber` - Subscribe to Pub/Sub messages
- `roles/secretmanager.secretAccessor` - Read secrets
- `roles/cloudtrace.agent` - Write traces
- `roles/logging.logWriter` - Write logs
- `roles/monitoring.metricWriter` - Write custom metrics

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id  = "my-project-dev"
  environment = "dev"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| environment | Environment name (dev, staging, prod) | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| api_service_account_email | Email of the API service account |
| api_service_account_id | ID of the API service account |
| event_processor_service_account_email | Email of the Event Processor service account |
| event_processor_service_account_id | ID of the Event Processor service account |
| service_account_emails | Map of service account names to emails |

## Security Considerations

- Service accounts follow the principle of least privilege
- Each service has only the permissions it needs
- No service account has admin or owner roles
- Secrets are accessed via Secret Manager, not environment variables

## Dependencies

None - this module can be deployed first.