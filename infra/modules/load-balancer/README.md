# Load Balancer Module

This module creates a Global HTTPS Load Balancer with Cloud Armor WAF for Cloud Run services.

## Resources Created

- **Global Static IP**: External IP address for the load balancer
- **Managed SSL Certificate**: Automatic SSL/TLS certificate for domains
- **Network Endpoint Group (NEG)**: Serverless NEG for Cloud Run
- **Backend Service**: Routes traffic to Cloud Run
- **URL Map**: Request routing configuration
- **HTTPS Proxy**: Terminates SSL/TLS
- **HTTP Proxy**: Redirects HTTP to HTTPS (optional)
- **Forwarding Rules**: HTTPS (443) and HTTP (80) rules
- **Cloud Armor Security Policy**: WAF with OWASP rules and rate limiting

## Usage

```hcl
module "load_balancer" {
  source = "../../modules/load-balancer"

  project_id             = "my-project-dev"
  environment            = "dev"
  region                 = "europe-west6"
  cloud_run_service_name = dependency.cloud_run_api.outputs.service_name

  # Domains for SSL certificate
  domains = ["api.example.com", "www.api.example.com"]

  # Cloud Armor WAF
  enable_cloud_armor  = true
  enable_owasp_rules  = true
  rate_limit_threshold = 100  # 100 requests per minute

  # CDN (optional)
  enable_cdn = false

  # Logging
  enable_logging      = true
  logging_sample_rate = 1.0  # Log all requests
}
```

## Environment-Specific Configurations

### Dev Environment
```hcl
domains             = []  # Use IP only, no domain
enable_cloud_armor  = true
enable_owasp_rules  = false  # Basic rules only
rate_limit_threshold = 1000
enable_cdn          = false
```

### Staging Environment
```hcl
domains             = ["staging-api.example.com"]
enable_cloud_armor  = true
enable_owasp_rules  = true
rate_limit_threshold = 500
enable_cdn          = false
```

### Production Environment
```hcl
domains                     = ["api.example.com", "www.api.example.com"]
enable_cloud_armor          = true
enable_owasp_rules          = true
enable_adaptive_protection  = true  # DDoS protection
rate_limit_threshold        = 100
enable_cdn                  = true  # Enable CDN
blocked_countries           = ["CN", "RU"]  # Block specific countries
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| region | GCP region | string | europe-west6 | no |
| environment | Environment name | string | - | yes |
| cloud_run_service_name | Cloud Run service name | string | - | yes |
| domains | Domains for SSL cert | list(string) | [] | no |
| backend_timeout_sec | Backend timeout | number | 30 | no |
| enable_cdn | Enable Cloud CDN | bool | false | no |
| enable_cloud_armor | Enable Cloud Armor | bool | true | no |
| enable_owasp_rules | Enable OWASP rules | bool | true | no |
| rate_limit_threshold | Rate limit (req/interval) | number | 100 | no |
| rate_limit_interval_sec | Rate limit interval | number | 60 | no |
| blocked_countries | Country codes to block | list(string) | [] | no |

## Outputs

| Name | Description |
|------|-------------|
| load_balancer_ip | Global IP address |
| ssl_certificate_id | SSL certificate ID |
| ssl_certificate_status | SSL certificate status |
| backend_service_id | Backend service ID |
| security_policy_id | Cloud Armor policy ID |

## DNS Configuration

After deployment, configure DNS to point to the load balancer IP:

```bash
# Get the IP address
terraform output load_balancer_ip

# Create DNS A record
# example.com -> <load-balancer-ip>
```

## SSL Certificate Provisioning

Managed SSL certificates can take 15-60 minutes to provision. Requirements:
1. DNS records must point to the load balancer IP
2. Domains must be publicly accessible
3. HTTP challenge must succeed

Check status:
```bash
gcloud compute ssl-certificates list --project=my-project-dev

# Wait for status: ACTIVE
```

## Cloud Armor Features

### OWASP Top 10 Protection

When `enable_owasp_rules = true`, the following protections are enabled:
- SQL injection (SQLi)
- Cross-site scripting (XSS)
- Local file inclusion (LFI)
- Remote file inclusion (RFI)
- Remote code execution (RCE)
- Method enforcement
- Scanner detection
- Protocol attacks
- PHP injection
- Session fixation

### Rate Limiting

Protects against brute force and DDoS attacks:
```hcl
rate_limit_threshold        = 100   # 100 requests per minute
rate_limit_interval_sec     = 60    # Per minute
rate_limit_ban_duration_sec = 600   # Ban for 10 minutes
```

### Geographic Blocking

Block traffic from specific countries:
```hcl
blocked_countries = ["CN", "RU", "KP"]
```

### Custom Rules

Add custom Cloud Armor rules:
```hcl
custom_rules = [
  {
    priority    = 5000
    action      = "deny(403)"
    expression  = "request.path.matches('/admin/.*')"
    description = "Block admin paths"
  },
  {
    priority    = 5001
    action      = "allow"
    expression  = "inIpRange(origin.ip, '10.0.0.0/8')"
    description = "Allow internal network"
  }
]
```

### Adaptive Protection (DDoS)

Enable for production environments:
```hcl
enable_adaptive_protection = true
```

This uses machine learning to detect and mitigate Layer 7 DDoS attacks.

## Cloud CDN

Enable CDN to cache static content at edge locations:
```hcl
enable_cdn      = true
cdn_default_ttl = 3600   # 1 hour
cdn_max_ttl     = 86400  # 24 hours
```

CDN is recommended for:
- Static assets (images, CSS, JS)
- API responses with `Cache-Control` headers
- High-traffic public APIs

## Monitoring Cloud Armor

View blocked requests in Cloud Logging:
```
resource.type="http_load_balancer"
jsonPayload.enforcedSecurityPolicy.name!=""
```

Key metrics:
- Blocked request count
- Security policy actions
- Rate limiting triggers

## Troubleshooting

### SSL Certificate Not Provisioning

1. Verify DNS points to load balancer IP
2. Ensure domain is publicly accessible
3. Wait 15-60 minutes
4. Check certificate status:
   ```bash
   gcloud compute ssl-certificates describe CERT_NAME --project=PROJECT_ID
   ```

### 404 Errors

1. Verify Cloud Run service exists and is healthy
2. Check NEG configuration
3. Ensure Cloud Run allows traffic from load balancer

### 502/503 Errors

1. Check Cloud Run service health
2. Verify backend timeout settings
3. Check Cloud Run logs for errors

### Cloud Armor Blocking Legitimate Traffic

1. Review Cloud Armor logs
2. Adjust rate limits or OWASP sensitivity
3. Add allow rules for specific IPs/paths

## Security Best Practices

1. **Always enable Cloud Armor** in production
2. **Enable OWASP rules** to protect against common attacks
3. **Set appropriate rate limits** based on expected traffic
4. **Enable request logging** for security analysis
5. **Use managed SSL certificates** (automatic renewal)
6. **Block unnecessary geographic regions** if applicable
7. **Enable adaptive protection** for DDoS mitigation in prod

## Dependencies

- **cloud-run** (API service): Cloud Run service must exist