# Load Balancer Module
# Creates Global HTTPS Load Balancer with Cloud Armor WAF

# Global static IP address
resource "google_compute_global_address" "default" {
  name    = "${var.environment}-lb-ip"
  project = var.project_id
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "default" {
  count = length(var.domains) > 0 ? 1 : 0

  name    = "${var.environment}-ssl-cert"
  project = var.project_id

  managed {
    domains = var.domains
  }
}

# Serverless NEG for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.environment}-cloud-run-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# Backend service
resource "google_compute_backend_service" "default" {
  name                  = "${var.environment}-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = var.backend_timeout_sec
  enable_cdn            = var.enable_cdn
  project               = var.project_id
  security_policy       = var.enable_cloud_armor ? google_compute_security_policy.policy[0].id : null

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

  log_config {
    enable      = var.enable_logging
    sample_rate = var.logging_sample_rate
  }

  # Cloud CDN configuration
  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode                   = "CACHE_ALL_STATIC"
      default_ttl                  = var.cdn_default_ttl
      max_ttl                      = var.cdn_max_ttl
      client_ttl                   = var.cdn_client_ttl
      negative_caching             = var.cdn_negative_caching
      serve_while_stale            = var.cdn_serve_while_stale
    }
  }

  # IAP configuration (if enabled)
  dynamic "iap" {
    for_each = var.enable_iap ? [1] : []
    content {
      oauth2_client_id     = var.iap_oauth2_client_id
      oauth2_client_secret = var.iap_oauth2_client_secret
      enabled              = false
    }
  }
}

# URL map
resource "google_compute_url_map" "default" {
  name            = "${var.environment}-url-map"
  default_service = google_compute_backend_service.default.id
  project         = var.project_id

  # Custom path matchers (if needed)
  dynamic "host_rule" {
    for_each = var.path_matchers
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = var.path_matchers
    content {
      name            = path_matcher.key
      default_service = google_compute_backend_service.default.id

      dynamic "path_rule" {
        for_each = path_matcher.value.path_rules
        content {
          paths   = path_rule.value.paths
          service = google_compute_backend_service.default.id
        }
      }
    }
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "default" {
  count = length(var.domains) > 0 ? 1 : 0

  name             = "${var.environment}-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
  project          = var.project_id
}

# HTTP proxy (redirect to HTTPS)
resource "google_compute_target_http_proxy" "default" {
  count = var.enable_http_redirect ? 1 : 0

  name    = "${var.environment}-http-proxy"
  url_map = google_compute_url_map.default.id
  project = var.project_id
}

# Global forwarding rule (HTTPS)
resource "google_compute_global_forwarding_rule" "https" {
  count = length(var.domains) > 0 ? 1 : 0

  name                  = "${var.environment}-https-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default[0].id
  ip_address            = google_compute_global_address.default.id
  project               = var.project_id
}

# Global forwarding rule (HTTP redirect)
resource "google_compute_global_forwarding_rule" "http" {
  count = var.enable_http_redirect ? 1 : 0

  name                  = "${var.environment}-http-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default[0].id
  ip_address            = google_compute_global_address.default.id
  project               = var.project_id
}

# Cloud Armor Security Policy
resource "google_compute_security_policy" "policy" {
  count = var.enable_cloud_armor ? 1 : 0

  name    = "${var.environment}-security-policy"
  project = var.project_id

  # Default rule - allow by default, specific rules can deny
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule - allow all"
  }

  # Rate limiting rule
  dynamic "rule" {
    for_each = var.rate_limit_threshold > 0 ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = 1000
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        enforce_on_key = "IP"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = var.rate_limit_interval_sec
        }
        ban_duration_sec = var.rate_limit_ban_duration_sec
      }
      description = "Rate limit rule"
    }
  }

  # Block specific countries (if specified)
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = 2000
      match {
        expr {
          expression = "origin.region_code in [${join(",", formatlist("'%s'", var.blocked_countries))}]"
        }
      }
      description = "Block specific countries"
    }
  }

  # OWASP ModSecurity Core Rule Set
  dynamic "rule" {
    for_each = var.enable_owasp_rules ? [
      {
        priority    = 3001
        expression  = "evaluatePreconfiguredExpr('sqli-stable')"
        description = "SQL injection protection"
      },
      {
        priority    = 3002
        expression  = "evaluatePreconfiguredExpr('xss-stable')"
        description = "XSS protection"
      },
      {
        priority    = 3003
        expression  = "evaluatePreconfiguredExpr('lfi-stable')"
        description = "Local file inclusion protection"
      },
      {
        priority    = 3004
        expression  = "evaluatePreconfiguredExpr('rfi-stable')"
        description = "Remote file inclusion protection"
      },
      {
        priority    = 3005
        expression  = "evaluatePreconfiguredExpr('rce-stable')"
        description = "Remote code execution protection"
      },
      {
        priority    = 3006
        expression  = "evaluatePreconfiguredExpr('methodenforcement-stable')"
        description = "Method enforcement"
      },
      {
        priority    = 3007
        expression  = "evaluatePreconfiguredExpr('scannerdetection-stable')"
        description = "Scanner detection"
      },
      {
        priority    = 3008
        expression  = "evaluatePreconfiguredExpr('protocolattack-stable')"
        description = "Protocol attack protection"
      },
      {
        priority    = 3009
        expression  = "evaluatePreconfiguredExpr('php-stable')"
        description = "PHP injection protection"
      },
      {
        priority    = 3010
        expression  = "evaluatePreconfiguredExpr('sessionfixation-stable')"
        description = "Session fixation protection"
      }
    ] : []
    content {
      action   = "deny(403)"
      priority = rule.value.priority
      match {
        expr {
          expression = rule.value.expression
        }
      }
      description = rule.value.description
    }
  }

  # Custom rules
  dynamic "rule" {
    for_each = var.custom_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  # Adaptive protection (DDoS)
  dynamic "adaptive_protection_config" {
    for_each = var.enable_adaptive_protection ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable = true
      }
    }
  }
}