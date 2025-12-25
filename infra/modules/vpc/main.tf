###################################
# Networking Module: Creates VPC, VPC connector for Cloud Run, firewall rules, and Cloud NAT
###################################


# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet for VPC connector
resource "google_compute_subnetwork" "vpc_connector_subnet" {
  name          = "${var.environment}-vpc-connector-subnet"
  ip_cidr_range = var.vpc_connector_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  private_ip_google_access = true
}

# Serverless VPC Access Connector
# Allows Cloud Run to access resources on the VPC (like CloudSQL)
resource "google_vpc_access_connector" "connector" {
  name          = "${var.environment}-vpc-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.vpc_connector_cidr
  project       = var.project_id

  # Connector capacity
  min_instances = var.vpc_connector_min_instances
  max_instances = var.vpc_connector_max_instances

  depends_on = [google_compute_subnetwork.vpc_connector_subnet]
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.environment}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

# Cloud NAT for outbound internet access
resource "google_compute_router_nat" "nat" {
  name                               = "${var.environment}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.project_id

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rule: Allow internal VPC traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_connector_cidr]
  priority      = 1000
}

# Firewall rule: Allow PostgreSQL from VPC connector
resource "google_compute_firewall" "allow_postgres" {
  name    = "${var.environment}-allow-postgres"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = [var.vpc_connector_cidr]
  target_tags   = ["cloudsql"]
  priority      = 1000
}

# Firewall rule: Deny all other inbound traffic
resource "google_compute_firewall" "deny_all" {
  name    = "${var.environment}-deny-all"
  network = google_compute_network.vpc.name
  project = var.project_id

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  priority      = 65534
}