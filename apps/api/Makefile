# Makefile for API Service

PROJECT_ID ?= generic-infra-demo
REGION ?= europe-west6
REGISTRY = $(REGION)-docker.pkg.dev
IMAGE_NAME = nestjs-api
VERSION ?= latest
FULL_IMAGE = $(REGISTRY)/$(PROJECT_ID)/api/$(IMAGE_NAME):$(VERSION)

.PHONY: help build push build-and-push clean run-local test

help:
	@echo "Available targets:"
	@echo "  build           - Build Docker image"
	@echo "  push            - Push image to Artifact Registry"
	@echo "  build-and-push  - Build and push image"
	@echo "  run-local       - Run container locally"
	@echo "  clean           - Remove local Docker image"
	@echo "  test            - Run tests"
	@echo ""
	@echo "Environment variables:"
	@echo "  PROJECT_ID  - GCP project ID (default: generic-infra-demo)"
	@echo "  REGION      - GCP region (default: europe-west6)"
	@echo "  VERSION     - Image version tag (default: latest)"

build:
	@echo "Building Docker image: $(FULL_IMAGE)"
	docker build -t $(FULL_IMAGE) .

push:
	@echo "Pushing Docker image: $(FULL_IMAGE)"
	docker push $(FULL_IMAGE)

build-and-push: build push
	@echo "Successfully built and pushed $(FULL_IMAGE)"

run-local:
	@echo "Running container locally on port 3000"
	docker run -p 3000:3000 \
		-e NODE_ENV=development \
		-e DB_HOST=${DB_HOST:-localhost} \
		-e DB_USER=${DB_USER:-postgres} \
		-e DB_PASSWORD=${DB_PASSWORD:-postgres} \
		-e DB_NAME=${DB_NAME:-api_dev} \
		$(FULL_IMAGE)

clean:
	@echo "Removing Docker image: $(FULL_IMAGE)"
	docker rmi $(FULL_IMAGE) || true

test:
	npm run test
