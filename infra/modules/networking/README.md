# Networking Module

This module creates the VPC networking infrastructure required for the GCP API stack.

## Resources Created

- **VPC Network**: Private network for the environment
- **VPC Subnet**: Subnet for the VPC Access Connector
- **VPC Access Connector**: Allows Cloud Run to access VPC resources (CloudSQL)
- **Cloud Router**: Required for Cloud NAT
- **Cloud NAT**: Provides outbound internet access for VPC resources
- **Firewall Rules**:
  - Allow internal VPC traffic
  - Allow PostgreSQL (port 5432) from VPC connector
  - Deny all other inbound traffic

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  project_id  = "my-project-dev"
  environment = "dev"
  region      = "europe-west6"

  vpc_connector_cidr         = "10.8.0.0/28"
  vpc_connector_min_instances = 2
  vpc_connector_max_instances = 3
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| region | GCP region | string | europe-west6 | no |
| environment | Environment name | string | - | yes |
| vpc_connector_cidr | CIDR for VPC connector (must be /28) | string | 10.8.0.0/28 | no |
| vpc_connector_min_instances | Min VPC connector instances | number | 2 | no |
| vpc_connector_max_instances | Max VPC connector instances | number | 3 | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC network |
| vpc_name | Name of the VPC network |
| vpc_self_link | Self-link of the VPC network |
| vpc_connector_id | ID of the VPC Access Connector |
| vpc_connector_name | Name of the VPC Access Connector |
| vpc_connector_self_link | Self-link of the VPC connector |
| router_name | Name of the Cloud Router |
| nat_name | Name of the Cloud NAT |
| subnet_id | ID of the VPC connector subnet |

## Notes

- VPC connector CIDR must be /28 (16 IP addresses)
- VPC connector is required for Cloud Run to access CloudSQL via private IP
- Cloud NAT allows VPC resources to make outbound internet requests
- Firewall rules follow a whitelist approach (deny all by default)

## Dependencies

None - this module can be deployed first.