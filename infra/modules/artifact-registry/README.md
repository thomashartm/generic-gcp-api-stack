# Artifact Registry Module

This module creates a Docker Artifact Registry repository for storing container images.

## Resources Created

- **Artifact Registry Repository**: Docker repository for container images
- **IAM Bindings**:
  - Reader role for service accounts (allows pulling images)
  - Writer role for CI/CD (allows pushing images)

## Usage

```hcl
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id  = "my-project-dev"
  environment = "dev"
  region      = "europe-west6"

  repository_id = "api"

  # Service accounts that can pull images (Cloud Run services)
  reader_service_accounts = [
    "serviceAccount:dev-api-sa@my-project-dev.iam.gserviceaccount.com",
    "serviceAccount:dev-event-processor-sa@my-project-dev.iam.gserviceaccount.com"
  ]

  # Members that can push images (CI/CD, developers)
  writer_members = [
    "serviceAccount:github-actions@my-project-dev.iam.gserviceaccount.com"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| region | GCP region | string | europe-west6 | no |
| environment | Environment name | string | - | yes |
| repository_id | Repository ID | string | api | no |
| reader_service_accounts | Service accounts that can pull images | list(string) | [] | no |
| writer_members | Members that can push images | list(string) | [] | no |
| labels | Additional labels | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| repository_id | ID of the repository |
| repository_name | Name of the repository |
| repository_url | Full URL for docker push/pull |
| location | Location of the repository |

## Pushing Images

After creating the repository, authenticate Docker:

```bash
gcloud auth configure-docker europe-west6-docker.pkg.dev
```

Tag and push images:

```bash
# Tag image
docker tag my-app:latest europe-west6-docker.pkg.dev/my-project-dev/api/my-app:v1.0.0

# Push image
docker push europe-west6-docker.pkg.dev/my-project-dev/api/my-app:v1.0.0
```

## Dependencies

- **iam**: Service accounts must exist before adding them as readers