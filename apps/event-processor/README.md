# Event Processor

NestJS-based Event Processor for handling Google Cloud Pub/Sub messages in Cloud Run.

## Features

- **Pub/Sub Push Subscription Handler**: Processes messages from Pub/Sub push subscriptions
- **Base64 Message Decoding**: Automatically decodes and parses Pub/Sub message data
- **Event Routing**: Routes different event types to appropriate handlers
- **Health Check**: Database connectivity check at `/health`
- **TypeORM Integration**: PostgreSQL database support
- **Docker Ready**: Multi-stage build for production
- **Cloud Run Optimized**: Configured for GCP Cloud Run deployment

## Prerequisites

- Node.js 20+
- PostgreSQL 15+
- Docker
- gcloud CLI (for deployment)

## Local Development

### 1. Install Dependencies

```bash
npm install
```

### 2. Set Up Environment Variables

Create a `.env` file:

```env
NODE_ENV=development
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=api_dev
```

### 3. Start Local Database

```bash
docker run -d \
  --name postgres-dev \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=api_dev \
  -p 5432:5432 \
  postgres:15-alpine
```

### 4. Run Application

```bash
# Development mode with watch
npm run start:dev

# Debug mode
npm run start:debug

# Production mode
npm run build
npm run start:prod
```

## API Endpoints

### Event Processing
- `POST /events` - Pub/Sub push subscription endpoint
  - Accepts Pub/Sub push format messages
  - Decodes base64 message data
  - Routes events to appropriate handlers
  - Returns 200 on success, 400 for invalid messages, 500 for processing errors

### Health Check
- `GET /health` - Database connectivity check
  - Returns 200 if database is accessible
  - Returns 503 if database is down

## Pub/Sub Message Format

### Expected Input (Pub/Sub Push Format)

```json
{
  "message": {
    "data": "eyJldmVudCI6ICJ0ZXN0IiwgImRhdGEiOiAiaGVsbG8ifQ==",
    "messageId": "12345",
    "publishTime": "2024-01-01T00:00:00Z",
    "attributes": {
      "key": "value"
    }
  },
  "subscription": "projects/PROJECT/subscriptions/SUBSCRIPTION"
}
```

### Decoded Data Format

The `data` field is base64-encoded JSON. After decoding:

```json
{
  "event": "test",
  "data": "hello",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Supported Event Types

- `user.created` - User creation events
- `order.placed` - Order placement events
- `test` - Test events for verification

## Testing Locally

### Simulate Pub/Sub Message

```bash
# Create base64 encoded test message
echo '{"event":"test","data":"hello"}' | base64

# Send to local endpoint
curl -X POST http://localhost:3000/events \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "eyJldmVudCI6InRlc3QiLCJkYXRhIjoiaGVsbG8ifQ==",
      "messageId": "test-123",
      "publishTime": "2024-01-01T00:00:00Z"
    },
    "subscription": "projects/test/subscriptions/test"
  }'
```

### Test Health Endpoint

```bash
curl http://localhost:3000/health
```

## Docker

### Build Image

```bash
# Using Makefile (recommended)
make build

# Or with custom version
make build VERSION=v1.0.0

# Or using docker directly
docker build -t europe-west6-docker.pkg.dev/generic-infra-demo/api/event-processor:latest .
```

### Run Container Locally

```bash
# Using Makefile
make run-local

# Or using docker directly
docker run -p 3000:3000 \
  -e DB_HOST=host.docker.internal \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=api_dev \
  europe-west6-docker.pkg.dev/generic-infra-demo/api/event-processor:latest
```

## Deployment to GCP

### 1. Authenticate Docker

```bash
gcloud auth configure-docker europe-west6-docker.pkg.dev
```

### 2. Build and Push Image

```bash
# Using Makefile
make build-and-push

# Or with custom version
make build-and-push VERSION=v1.0.0
```

### 3. Deploy to Cloud Run

```bash
cd ../../infra/stacks/dev/event-processor
terragrunt apply
```

### 4. Configure Pub/Sub

```bash
cd ../pubsub
terragrunt apply
```

### 5. Verify Deployment

```bash
# Test Pub/Sub integration
gcloud pubsub topics publish dev-events-topic \
  --message='{"event": "test", "data": "hello"}' \
  --project=generic-infra-demo

# Check logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=event-processor" \
  --limit=10 \
  --project=generic-infra-demo \
  --format=json
```

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `NODE_ENV` | Environment (development/production) | development | No |
| `PORT` | Server port | 3000 | No |
| `DB_HOST` | Database host | localhost | Yes |
| `DB_PORT` | Database port | 5432 | No |
| `DB_USER` | Database username | postgres | Yes (from Secret Manager in Cloud Run) |
| `DB_PASSWORD` | Database password | postgres | Yes (from Secret Manager in Cloud Run) |
| `DB_NAME` | Database name | api_dev | Yes (from Secret Manager in Cloud Run) |
| `DB_POOL_SIZE` | Connection pool size | 10 | No |

## Project Structure

```
src/
├── main.ts                 # Application entry point
├── app.module.ts           # Root module
├── config/
│   ├── database.config.ts  # TypeORM configuration
│   └── app.config.ts       # Application configuration
├── health/
│   ├── health.module.ts    # Health check module
│   ├── health.controller.ts
│   └── health.service.ts
└── events/
    ├── events.module.ts    # Event processing module
    ├── events.controller.ts # POST /events endpoint
    ├── events.service.ts   # Event processing logic
    └── dto/
        └── pubsub-message.dto.ts # Pub/Sub message validation
```

## Event Processing Flow

1. **Receive Message**: Pub/Sub pushes message to POST /events
2. **Validate**: Validate message structure with DTO
3. **Decode**: Decode base64 data to JSON
4. **Route**: Route to appropriate handler based on event type
5. **Process**: Execute event-specific logic
6. **Respond**: Return 200 on success (acknowledges message)

## Error Handling

- **400 Bad Request**: Invalid message format (message won't be retried)
- **500 Internal Server Error**: Processing failure (message will be retried)
- **Dead Letter Queue**: After 5 failed retries, message goes to dead letter topic

## Monitoring

### Cloud Logging

```bash
# View all logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=event-processor" \
  --limit=50 \
  --project=generic-infra-demo

# View only errors
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=event-processor AND severity>=ERROR" \
  --limit=20 \
  --project=generic-infra-demo

# Follow logs in real-time
gcloud alpha run services logs tail event-processor \
  --project=generic-infra-demo \
  --region=europe-west6
```

### Key Metrics

Monitor these metrics in Cloud Console:
- Message processing time
- Error rate
- Pub/Sub subscription backlog
- Container instance count
- Database connection pool usage

## Troubleshooting

### Messages Not Being Received

1. Verify Pub/Sub push subscription is configured correctly
2. Check Cloud Run service URL in subscription
3. Verify IAM permissions (Pub/Sub → Cloud Run invoker)
4. Check Cloud Run logs for errors

### Database Connection Fails

1. Verify VPC connector is attached to Cloud Run
2. Check database credentials in Secret Manager
3. Verify database is accessible via private IP
4. Check security group rules

### Message Processing Fails

1. Check event format matches expected structure
2. Review error logs for specific failure reasons
3. Test with sample message locally first
4. Verify event handlers are implemented

## Extending Event Handlers

To add a new event type:

1. Add case to switch statement in `events.service.ts`:
```typescript
case 'your.event.type':
  return this.handleYourEvent(event.data);
```

2. Implement handler method:
```typescript
private async handleYourEvent(data: any): Promise<any> {
  this.logger.log(`Your event: ${JSON.stringify(data)}`);
  // Your processing logic here
  return { status: 'processed', eventType: 'your.event.type' };
}
```

## Testing

```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Test coverage
npm run test:cov
```

## License

MIT
