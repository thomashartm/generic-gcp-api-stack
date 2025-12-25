# API Service

NestJS-based REST API service for GCP Cloud Run deployment.

## Features

- **Multiple Demo Endpoints**: GET/POST at `/`, `/hello`, and `/api/greet`
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

### Root Endpoints
- `GET /` - Returns hello world message
- `POST /` - Returns hello world with request data

### Hello Endpoints
- `GET /hello` - Returns hello world
- `POST /hello` - Returns hello world with request data

### API Endpoints
- `GET /api/greet` - Returns greeting with timestamp

### Health Check
- `GET /health` - Database connectivity check
  - Returns 200 if database is accessible
  - Returns 503 if database is down

## Testing

```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Test coverage
npm run test:cov
```

## Docker

### Build Image

```bash
# Using Makefile (recommended)
make build

# Or with custom version
make build VERSION=v1.0.0

# Or using docker directly
docker build -t europe-west6-docker.pkg.dev/generic-infra-demo/api/nestjs-api:latest .
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
  europe-west6-docker.pkg.dev/generic-infra-demo/api/nestjs-api:latest
```

### Test Endpoints

```bash
# Health check
curl http://localhost:3000/health

# Root endpoint
curl http://localhost:3000/

# POST with data
curl -X POST http://localhost:3000/ \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Hello endpoint
curl http://localhost:3000/hello

# API greet endpoint
curl http://localhost:3000/api/greet
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
cd ../../infra/stacks/dev/api-service
terragrunt apply
```

### 4. Verify Deployment

```bash
# Get load balancer IP
cd ../load-balancer
terragrunt output load_balancer_ip

# Test health endpoint
curl https://<load-balancer-ip>/health

# Test API endpoints
curl https://<load-balancer-ip>/
curl https://<load-balancer-ip>/hello
curl https://<load-balancer-ip>/api/greet
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
| `CORS_ENABLED` | Enable CORS | true | No |

## Project Structure

```
src/
├── main.ts                 # Application entry point
├── app.module.ts           # Root module
├── app.controller.ts       # Root endpoints (GET /, POST /)
├── app.service.ts          # Root service
├── config/
│   ├── database.config.ts  # TypeORM configuration
│   └── app.config.ts       # Application configuration
├── health/
│   ├── health.module.ts    # Health check module
│   ├── health.controller.ts
│   └── health.service.ts
├── hello/
│   ├── hello.module.ts     # Hello endpoints module
│   ├── hello.controller.ts
│   └── hello.service.ts
└── api/
    ├── api.module.ts       # API endpoints module
    ├── api.controller.ts
    └── api.service.ts
```

## Troubleshooting

### Database Connection Fails

Check environment variables and database connectivity:
```bash
# Verify database is running
docker ps | grep postgres

# Check connection from host
psql -h localhost -U postgres -d api_dev
```

### Build Fails

Clear npm cache and reinstall:
```bash
rm -rf node_modules package-lock.json
npm install
```

### Docker Build Fails

Check .dockerignore and ensure node_modules is excluded:
```bash
cat .dockerignore | grep node_modules
```

### Health Check Fails in Cloud Run

Verify:
1. Database is accessible via VPC connector
2. Secret Manager values are correct
3. Service account has necessary permissions
4. Check Cloud Run logs for errors

## Monitoring

### Cloud Logging

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=api-service" \
  --limit=50 \
  --project=generic-infra-demo

# Follow logs
gcloud alpha run services logs tail api-service \
  --project=generic-infra-demo \
  --region=europe-west6
```

### Metrics

Access Cloud Run metrics in GCP Console:
- Request count
- Request latency
- Container instance count
- Error rate

## License

MIT
