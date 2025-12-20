# Cloud Run Module
# Creates a Cloud Run service (reusable for API and Event Processor)

# Cloud Run Service
resource "google_cloud_run_v2_service" "service" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  ingress = var.ingress

  template {
    # Service account
    service_account = var.service_account_email

    # VPC connector for private CloudSQL access
    vpc_access {
      connector = var.vpc_connector_id
      egress    = var.vpc_egress
    }

    # Scaling configuration
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Container configuration
    containers {
      image = var.image_url

      # Resource limits
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = var.cpu_always_allocated
        startup_cpu_boost = var.startup_cpu_boost
      }

      # Environment variables
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = env.value.version
            }
          }
        }
      }

      # Health check port
      ports {
        container_port = var.container_port
      }

      # Startup probe
      dynamic "startup_probe" {
        for_each = var.startup_probe_path != "" ? [1] : []
        content {
          http_get {
            path = var.startup_probe_path
            port = var.container_port
          }
          initial_delay_seconds = var.startup_probe_initial_delay
          timeout_seconds       = var.startup_probe_timeout
          period_seconds        = var.startup_probe_period
          failure_threshold     = var.startup_probe_failure_threshold
        }
      }

      # Liveness probe
      dynamic "liveness_probe" {
        for_each = var.liveness_probe_path != "" ? [1] : []
        content {
          http_get {
            path = var.liveness_probe_path
            port = var.container_port
          }
          initial_delay_seconds = var.liveness_probe_initial_delay
          timeout_seconds       = var.liveness_probe_timeout
          period_seconds        = var.liveness_probe_period
          failure_threshold     = var.liveness_probe_failure_threshold
        }
      }
    }

    # Request timeout
    timeout = var.request_timeout

    # Max concurrent requests per instance
    max_instance_request_concurrency = var.max_concurrent_requests
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
    },
    var.labels
  )
}

# IAM bindings for invokers
resource "google_cloud_run_service_iam_member" "invokers" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = each.value
}

# Allow unauthenticated access (only for public APIs behind load balancer)
resource "google_cloud_run_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}