# Cloud SQL Module

This module creates a CloudSQL PostgreSQL instance with private IP access and automated backups.

## Resources Created

- **CloudSQL PostgreSQL Instance**: Managed PostgreSQL database
- **Private VPC Connection**: Allows access via VPC (no public IP)
- **Database**: Application database
- **Database User**: Application database user
- **Read Replicas**: Optional read replicas for scaling reads

## Usage

```hcl
module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id  = "my-project-dev"
  environment = "dev"
  region      = "europe-west6"
  network_id  = dependency.networking.outputs.vpc_id

  # Database configuration
  database_version = "POSTGRES_15"
  tier             = "db-f1-micro"
  availability_type = "ZONAL"
  disk_size        = 10
  disk_type        = "PD_SSD"

  # Database credentials
  db_name     = "appdb"
  db_user     = "appuser"
  db_password = var.db_password  # Pass from secret management

  # Backups
  point_in_time_recovery_enabled = true
  retained_backups               = 7

  # Deletion protection
  deletion_protection = true
}
```

## Environment-Specific Configurations

### Dev Environment
```hcl
tier              = "db-f1-micro"
availability_type = "ZONAL"
disk_size         = 10
retained_backups  = 7
deletion_protection = false  # Allow easier cleanup
```

### Staging Environment
```hcl
tier              = "db-custom-1-4096"
availability_type = "REGIONAL"  # High availability
disk_size         = 50
retained_backups  = 14
deletion_protection = true
```

### Production Environment
```hcl
tier              = "db-custom-4-16384"
availability_type = "REGIONAL"  # High availability
disk_size         = 100
retained_backups  = 30
deletion_protection = true
read_replica_count = 1  # Add read replicas
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| region | GCP region | string | europe-west6 | no |
| environment | Environment name | string | - | yes |
| network_id | VPC network ID | string | - | yes |
| database_version | PostgreSQL version | string | POSTGRES_15 | no |
| tier | Machine type | string | db-f1-micro | no |
| availability_type | ZONAL or REGIONAL | string | ZONAL | no |
| disk_type | PD_SSD or PD_HDD | string | PD_SSD | no |
| disk_size | Disk size in GB | number | 10 | no |
| disk_autoresize | Enable auto-resize | bool | true | no |
| db_name | Database name | string | appdb | no |
| db_user | Database username | string | appuser | no |
| db_password | Database password | string (sensitive) | - | yes |
| backup_start_time | Backup start time (HH:MM) | string | 03:00 | no |
| point_in_time_recovery_enabled | Enable PITR | bool | true | no |
| retained_backups | Backups to retain | number | 7 | no |
| deletion_protection | Prevent deletion | bool | true | no |
| read_replica_count | Number of read replicas | number | 0 | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | Name of the instance |
| instance_connection_name | Connection string |
| private_ip_address | Private IP address |
| database_name | Database name |
| database_user | Database username |
| read_replica_connection_names | Read replica connections |

## Connecting to the Database

### From Cloud Run (Private IP)

Cloud Run connects via the VPC connector:

```typescript
const connectionString = `postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}`;
// DB_HOST = private IP address from outputs
```

### From Local Development (Cloud SQL Proxy)

```bash
# Install Cloud SQL Proxy
# https://cloud.google.com/sql/docs/postgres/sql-proxy

# Run proxy
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:5432

# Connect with psql
psql "host=127.0.0.1 port=5432 dbname=appdb user=appuser"
```

## Backup and Recovery

### Automated Backups
- Daily backups at configured time (default: 03:00 UTC)
- Point-in-time recovery enabled (allows restore to any second)
- Configurable retention period

### Manual Backup
```bash
gcloud sql backups create \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID
```

### Restore from Backup
```bash
gcloud sql backups restore BACKUP_ID \
  --backup-instance=SOURCE_INSTANCE \
  --backup-project=PROJECT_ID \
  --instance=TARGET_INSTANCE
```

## High Availability

For production, use:
- `availability_type = "REGIONAL"` - Creates standby replica in another zone
- Automatic failover in case of zone failure
- ~30 seconds downtime during failover

## Read Replicas

To scale read traffic:
```hcl
read_replica_count = 1
```

Applications should:
- Send writes to primary instance
- Send reads to replica instances
- Handle replica lag (typically < 1 second)

## Monitoring

Key metrics to monitor:
- CPU utilization
- Memory utilization
- Disk utilization
- Connection count
- Replication lag (if using replicas)

## Dependencies

- **networking**: VPC network must exist for private IP configuration