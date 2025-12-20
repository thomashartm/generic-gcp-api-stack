# Artifact Registry Module
# Creates Docker repository for container images

# Docker Artifact Registry Repository
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Docker repository for ${var.environment} environment"
  format        = "DOCKER"
  project       = var.project_id

  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
    },
    var.labels
  )
}

# IAM binding to allow service accounts to pull images
resource "google_artifact_registry_repository_iam_member" "readers" {
  for_each = toset(var.reader_service_accounts)

  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

# IAM binding to allow pushing images (for CI/CD)
resource "google_artifact_registry_repository_iam_member" "writers" {
  for_each = toset(var.writer_members)

  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = each.value
}