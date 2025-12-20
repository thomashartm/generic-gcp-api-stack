# Monitoring Module

This module creates monitoring dashboards, alerts, and uptime checks for the infrastructure.

## Resources Created

- **Notification Channels**: Email notifications for alerts
- **Uptime Check**: HTTP health check for the API
- **Dashboard**: Monitoring dashboard with key metrics
- **Alert Policies**:
  - High API error rate
  - High API latency (P95)
  - CloudSQL high CPU utilization
  - CloudSQL high disk usage
  - API uptime check failure
  - Pub/Sub old unacked messages

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_id       = "my-project-dev"
  environment      = "dev"
  api_service_name = dependency.cloud_run_api.outputs.service_name
  api_url          = "https://api.example.com"

  # Notification emails
  notification_emails = [
    "devops@example.com",
    "oncall@example.com"
  ]

  # Enable alerts
  enable_alerts = true

  # Alert thresholds
  error_rate_threshold               = 5      # 5 errors/second
  latency_threshold_ms               = 1000   # 1000ms (1 second)
  cloudsql_cpu_threshold             = 0.8    # 80%
  cloudsql_disk_threshold            = 0.85   # 85%
  pubsub_old_message_threshold_sec   = 600    # 10 minutes
}
```

## Environment-Specific Configurations

### Dev Environment
```hcl
enable_alerts                     = false  # Don't alert for dev
notification_emails               = ["dev-team@example.com"]
error_rate_threshold              = 10
latency_threshold_ms              = 2000
uptime_check_period               = "300s"
```

### Staging Environment
```hcl
enable_alerts                     = true
notification_emails               = ["devops@example.com"]
error_rate_threshold              = 5
latency_threshold_ms              = 1000
uptime_check_period               = "300s"
```

### Production Environment
```hcl
enable_alerts                     = true
notification_emails               = [
  "oncall@example.com",
  "devops@example.com"
]
error_rate_threshold              = 1
latency_threshold_ms              = 500
cloudsql_cpu_threshold            = 0.7
cloudsql_disk_threshold           = 0.8
pubsub_old_message_threshold_sec  = 300
uptime_check_period               = "60s"
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| environment | Environment name | string | - | yes |
| api_service_name | API Cloud Run service name | string | - | yes |
| api_url | API URL for uptime checks | string | "" | no |
| notification_emails | Email addresses for alerts | list(string) | [] | no |
| enable_alerts | Enable alert policies | bool | true | no |
| uptime_check_period | Uptime check period | string | 300s | no |
| health_check_path | Health check endpoint path | string | /health | no |
| error_rate_threshold | Error rate threshold (errors/sec) | number | 5 | no |
| latency_threshold_ms | Latency threshold (ms) | number | 1000 | no |
| cloudsql_cpu_threshold | CloudSQL CPU threshold (0-1) | number | 0.8 | no |
| cloudsql_disk_threshold | CloudSQL disk threshold (0-1) | number | 0.85 | no |

## Outputs

| Name | Description |
|------|-------------|
| dashboard_id | ID of the monitoring dashboard |
| uptime_check_id | ID of the uptime check |
| notification_channel_ids | Map of notification channel IDs |
| alert_policy_ids | Map of alert policy IDs |

## Dashboard

The module creates a comprehensive dashboard with the following widgets:

1. **API Request Count**: Total requests per second
2. **API Latency**: P50, P95, and P99 latencies
3. **API Instance Count**: Number of running Cloud Run instances
4. **CloudSQL CPU Utilization**: Database CPU usage
5. **CloudSQL Memory Utilization**: Database memory usage
6. **Pub/Sub Unacked Messages**: Number of undelivered messages

Access the dashboard:
```
https://console.cloud.google.com/monitoring/dashboards?project=PROJECT_ID
```

## Alerts

### High API Error Rate
Triggers when error rate exceeds threshold for 5 minutes.

**Investigation steps:**
1. Check Cloud Run logs for error details
2. Review recent deployments
3. Check database connectivity
4. Review Cloud Armor logs for blocked requests

### High API Latency
Triggers when P95 latency exceeds threshold for 5 minutes.

**Investigation steps:**
1. Check Cloud Run instance count (scaling issue?)
2. Review database query performance
3. Check for slow external API calls
4. Review application performance metrics

### CloudSQL High CPU/Disk
Triggers when database resources exceed threshold for 5 minutes.

**Mitigation:**
1. Scale up database instance (increase CPU/memory)
2. Optimize slow queries
3. Add read replicas for read-heavy workloads
4. Increase disk size if needed

### API Uptime Check Failure
Triggers when health check fails.

**Investigation steps:**
1. Check if service is running
2. Review Cloud Run logs
3. Check database connectivity
4. Verify load balancer configuration

### Pub/Sub Old Unacked Messages
Triggers when messages aren't being processed.

**Investigation steps:**
1. Check Event Processor Cloud Run service
2. Review event processor logs for errors
3. Check subscription configuration
4. Review dead letter queue

## Uptime Checks

Uptime checks run from multiple global locations and verify:
- Service responds to HTTP requests
- Response code is 2xx
- Response body contains expected content (default: "ok")

## Notification Channels

### Email Notifications
Email alerts include:
- Alert name and description
- Time triggered
- Current metric value vs. threshold
- Link to dashboard
- Investigation documentation

### Additional Notification Channels

You can add other notification channels manually or via Terraform:

**Slack:**
```hcl
resource "google_monitoring_notification_channel" "slack" {
  display_name = "Slack #alerts"
  type         = "slack"
  labels = {
    channel_name = "#alerts"
  }
  sensitive_labels {
    auth_token = var.slack_token
  }
}
```

**PagerDuty:**
```hcl
resource "google_monitoring_notification_channel" "pagerduty" {
  display_name = "PagerDuty"
  type         = "pagerduty"
  sensitive_labels {
    service_key = var.pagerduty_key
  }
}
```

## Cloud Logging Queries

### API Errors
```
resource.type="cloud_run_revision"
resource.labels.service_name="api-service"
severity>=ERROR
```

### Slow Queries
```
resource.type="cloudsql_database"
log_name="projects/PROJECT_ID/logs/cloudsql.googleapis.com%2Fpostgres.log"
jsonPayload.message=~"duration:.*ms"
jsonPayload.message=~"duration: [1-9][0-9]{3,}"
```

### Cloud Armor Blocks
```
resource.type="http_load_balancer"
jsonPayload.enforcedSecurityPolicy.name!=""
```

## Best Practices

1. **Set appropriate thresholds** for each environment
2. **Test alerts** by intentionally triggering them in dev/staging
3. **Document runbooks** for each alert type
4. **Review and adjust** thresholds based on actual traffic patterns
5. **Use different notification channels** for different severity levels
6. **Monitor alert fatigue** and adjust thresholds to reduce noise
7. **Set up escalation policies** for production (PagerDuty, etc.)

## Dependencies

- **cloud-run**: API service must exist for metrics
- **cloud-sql**: Database must exist for database metrics
- **pubsub**: Pub/Sub resources must exist for Pub/Sub metrics