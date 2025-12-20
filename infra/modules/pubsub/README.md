# Pub/Sub Module

This module creates Pub/Sub topics and subscriptions for asynchronous event processing.

## Resources Created

- **Events Topic**: Main topic for publishing events
- **Events Subscription**: Push subscription to Event Processor Cloud Run
- **Dead Letter Topic**: Topic for messages that failed processing
- **Dead Letter Subscription**: Pull subscription for inspecting failed messages
- **IAM Bindings**: Permissions for publishers, subscribers, and Cloud Run

## Architecture

```
API Service → Pub/Sub Topic → Push Subscription → Event Processor Cloud Run
                                       ↓ (after 5 failed attempts)
                                Dead Letter Topic → Pull Subscription
```

## Usage

```hcl
module "pubsub" {
  source = "../../modules/pubsub"

  project_id  = "my-project-dev"
  environment = "dev"
  region      = "europe-west6"

  # Event Processor Cloud Run details
  event_processor_url             = "https://event-processor-xyz.run.app"
  event_processor_service_name    = "event-processor"
  event_processor_service_account = "dev-event-processor-sa@my-project-dev.iam.gserviceaccount.com"

  # Publishers (API service)
  publisher_service_accounts = [
    "serviceAccount:dev-api-sa@my-project-dev.iam.gserviceaccount.com"
  ]

  # Configuration
  ack_deadline_seconds  = 60
  max_delivery_attempts = 5
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| region | GCP region | string | europe-west6 | no |
| environment | Environment name | string | - | yes |
| event_processor_url | Event Processor URL | string | "" | no |
| event_processor_service_name | Event Processor service name | string | "" | no |
| event_processor_service_account | Event Processor SA email | string | - | yes |
| publisher_service_accounts | Publisher SA emails | list(string) | [] | no |
| message_retention_duration | Topic retention | string | 86400s | no |
| ack_deadline_seconds | Ack deadline | number | 60 | no |
| max_delivery_attempts | Max delivery attempts | number | 5 | no |

## Outputs

| Name | Description |
|------|-------------|
| topic_id | ID of the Pub/Sub topic |
| topic_name | Name of the topic |
| subscription_id | ID of the subscription |
| subscription_name | Name of the subscription |
| dead_letter_topic_id | ID of dead letter topic |
| dead_letter_subscription_id | ID of dead letter subscription |

## Publishing Messages

### From NestJS Application

```typescript
import { PubSub } from '@google-cloud/pubsub';

const pubsub = new PubSub();
const topic = pubsub.topic('dev-events-topic');

async function publishEvent(eventData: any) {
  const data = JSON.stringify(eventData);
  const messageId = await topic.publishMessage({ data: Buffer.from(data) });
  console.log(`Message ${messageId} published`);
}
```

### From gcloud CLI (Testing)

```bash
gcloud pubsub topics publish dev-events-topic \
  --message='{"type":"user.created","userId":"123"}' \
  --project=my-project-dev
```

## Receiving Messages

### Event Processor Cloud Run

The Event Processor receives messages via HTTP POST requests:

```typescript
// NestJS controller
@Post('/events')
async handleEvent(@Body() message: PubSubMessage) {
  // message.data contains base64-encoded event data
  const eventData = JSON.parse(
    Buffer.from(message.data, 'base64').toString()
  );

  // Process event
  await this.processEvent(eventData);

  // Return 200 to acknowledge
  return { success: true };
}
```

## Dead Letter Queue

Messages that fail processing after 5 attempts are sent to the dead letter topic.

### Inspecting Failed Messages

```bash
# Pull messages from dead letter subscription
gcloud pubsub subscriptions pull dev-events-dead-letter-subscription \
  --limit=10 \
  --project=my-project-dev

# Acknowledge messages after inspection
gcloud pubsub subscriptions pull dev-events-dead-letter-subscription \
  --auto-ack \
  --limit=10 \
  --project=my-project-dev
```

### Replaying Failed Messages

```bash
# Get message from dead letter queue
MESSAGE=$(gcloud pubsub subscriptions pull dev-events-dead-letter-subscription \
  --limit=1 --format=json)

# Extract data
DATA=$(echo $MESSAGE | jq -r '.[0].message.data')

# Republish to main topic
gcloud pubsub topics publish dev-events-topic \
  --message="$DATA" \
  --project=my-project-dev
```

## Monitoring

Key metrics to monitor:
- **Unacknowledged messages**: Messages waiting to be processed
- **Oldest unacknowledged message age**: Lag in processing
- **Dead letter topic message count**: Failed message rate
- **Subscription throughput**: Messages per second

## Retry Behavior

1. Message published to topic
2. Pushed to Event Processor via HTTP POST
3. If processing fails (non-200 response):
   - Retry with exponential backoff (10s to 10min)
   - Maximum 5 attempts
4. After 5 failed attempts:
   - Message sent to dead letter topic
   - Available for manual inspection and replay

## Best Practices

1. **Idempotency**: Event processor should handle duplicate messages
2. **Fast Acknowledgement**: Acknowledge within `ack_deadline_seconds`
3. **Error Handling**: Return 200 only if processing succeeded
4. **Dead Letter Monitoring**: Alert on messages in dead letter queue
5. **Message Ordering**: Pub/Sub doesn't guarantee order; design accordingly

## Dependencies

- **iam**: Service accounts must exist
- **cloud-run** (event-processor): Event Processor service must exist for push subscription