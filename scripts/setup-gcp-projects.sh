#!/bin/bash

################################################################################
# GCP Project Setup Script
#
# This script sets up an existing GCP project by enabling required APIs
# and creating the Terraform state bucket.
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Existing GCP project with billing enabled
#
# Usage:
#   ./scripts/setup-gcp-projects.sh
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGION="europe-west6"
PROJECT_ID=""
ENVIRONMENT=""

# Required APIs
REQUIRED_APIS=(
  "compute.googleapis.com"              # Compute Engine API
  "run.googleapis.com"                  # Cloud Run API
  "sqladmin.googleapis.com"             # Cloud SQL Admin API
  "vpcaccess.googleapis.com"            # VPC Access API
  "secretmanager.googleapis.com"        # Secret Manager API
  "artifactregistry.googleapis.com"     # Artifact Registry API
  "pubsub.googleapis.com"               # Pub/Sub API
  "cloudresourcemanager.googleapis.com" # Resource Manager API
  "iam.googleapis.com"                  # IAM API
  "cloudapis.googleapis.com"            # Google Cloud APIs
  "servicenetworking.googleapis.com"    # Service Networking API
)

################################################################################
# Helper Functions
################################################################################

print_header() {
  echo -e "\n${GREEN}================================================================================${NC}"
  echo -e "${GREEN}$1${NC}"
  echo -e "${GREEN}================================================================================${NC}\n"
}

print_info() {
  echo -e "${YELLOW}ℹ ${NC}$1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

check_prerequisites() {
  print_header "Checking Prerequisites"

  # Check if gcloud is installed
  if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
  fi
  print_success "gcloud CLI is installed"

  # Check if authenticated
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    print_error "Not authenticated with gcloud. Run: gcloud auth login"
    exit 1
  fi

  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  print_success "Authenticated with gcloud as: $ACTIVE_ACCOUNT"

  echo ""
}

get_project_info() {
  print_header "GCP Project Information"

  # Prompt for project ID
  echo ""
  read -rp "Enter your GCP project ID: " PROJECT_ID
  echo ""

  # Verify project exists
  print_info "Verifying project '$PROJECT_ID' exists..."

  if ! gcloud projects describe "$PROJECT_ID" &> /dev/null; then
    print_error "Project '$PROJECT_ID' not found or you don't have access to it"
    print_info "Please verify the project ID and ensure you have the necessary permissions"
    exit 1
  fi

  print_success "Project '$PROJECT_ID' found"

  # Check if billing is enabled
  print_info "Checking if billing is enabled..."
  BILLING_INFO=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "unknown")

  if [ "$BILLING_INFO" = "True" ]; then
    print_success "Billing is enabled for $PROJECT_ID"
  else
    print_warn "Could not verify billing status. Please ensure billing is enabled."
    read -rp "Continue anyway? (y/n) " -n 1
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_info "Setup cancelled"
      exit 0
    fi
  fi

  # Prompt for environment name
  echo ""
  print_info "This environment name will be used as a prefix in the Terraform state bucket"
  read -rp "Enter environment name (e.g., dev, staging, prod): " ENVIRONMENT
  echo ""

  print_success "Configuration:"
  print_info "  Project ID: $PROJECT_ID"
  print_info "  Environment: $ENVIRONMENT"
  print_info "  Region: $REGION"

  echo ""
}

enable_apis() {
  print_header "Enabling Required APIs"

  print_info "Enabling required APIs for $PROJECT_ID"
  echo ""

  for api in "${REQUIRED_APIS[@]}"; do
    echo -n "  Enabling $api... "
    if gcloud services enable "$api" --project="$PROJECT_ID" 2>&1 > /dev/null; then
      echo -e "${GREEN}✓${NC}"
    else
      echo -e "${RED}✗${NC}"
      print_error "Failed to enable $api"
    fi
  done

  echo ""
  print_success "All required APIs have been enabled for $PROJECT_ID"
  echo ""
}

create_state_bucket() {
  print_header "Setting Up Terraform State Storage"

  # Use a bucket name based on project ID
  local bucket_name="${PROJECT_ID}-terraform-state"

  print_info "Terraform state bucket: gs://${bucket_name}"
  echo ""

  # Check if bucket already exists
  if gsutil ls -b "gs://${bucket_name}" &> /dev/null; then
    print_success "Bucket 'gs://${bucket_name}' already exists"

    # Check if environment prefix exists
    if gsutil ls "gs://${bucket_name}/${ENVIRONMENT}/" &> /dev/null; then
      print_success "Environment prefix '${ENVIRONMENT}/' already exists in bucket"
    else
      print_info "Creating environment prefix '${ENVIRONMENT}/' in bucket"
      echo "Terraform state for ${ENVIRONMENT} environment" | gsutil cp - "gs://${bucket_name}/${ENVIRONMENT}/.terragrunt-bucket-setup" 2>&1 > /dev/null || true
      print_success "Environment prefix '${ENVIRONMENT}/' created"
    fi

    echo ""
    return 0
  fi

  # Create bucket
  print_info "Creating bucket 'gs://${bucket_name}' in project: $PROJECT_ID"
  if gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${bucket_name}" 2>&1; then
    print_success "Bucket 'gs://${bucket_name}' created"
  else
    print_error "Failed to create bucket 'gs://${bucket_name}'"
    return 1
  fi

  # Enable versioning
  print_info "Enabling versioning on bucket"
  if gsutil versioning set on "gs://${bucket_name}" 2>&1; then
    print_success "Versioning enabled"
  else
    print_error "Failed to enable versioning"
  fi

  # Set lifecycle policy to keep last 10 versions
  print_info "Setting lifecycle policy (keep last 10 versions)"
  cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "numNewerVersions": 10
        }
      }
    ]
  }
}
EOF

  if gsutil lifecycle set /tmp/lifecycle.json "gs://${bucket_name}" 2>&1; then
    print_success "Lifecycle policy configured"
  else
    print_error "Failed to set lifecycle policy"
  fi

  rm /tmp/lifecycle.json

  # Create environment prefix
  print_info "Creating environment prefix '${ENVIRONMENT}/'"
  echo "Terraform state for ${ENVIRONMENT} environment" | gsutil cp - "gs://${bucket_name}/${ENVIRONMENT}/.terragrunt-bucket-setup" 2>&1 > /dev/null || true
  print_success "Environment prefix '${ENVIRONMENT}/' created"

  echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
  print_header "GCP Project Setup Script"

  echo "This script will configure your existing GCP project for Terraform infrastructure."
  echo ""
  echo "What it does:"
  echo "  1. Verify your GCP project exists and has billing enabled"
  echo "  2. Enable required APIs for the infrastructure stack"
  echo "  3. Create Terraform state bucket with versioning (if it doesn't exist)"
  echo ""

  # Check prerequisites
  check_prerequisites

  # Get project information
  get_project_info

  # Confirmation
  echo ""
  print_info "Ready to configure project '$PROJECT_ID' for environment '$ENVIRONMENT'"
  echo ""
  read -rp "Do you want to continue? (y/n) " -n 1
  echo ""
  echo ""

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled"
    exit 0
  fi

  # Enable APIs
  enable_apis

  # Create state bucket
  create_state_bucket

  # Summary
  print_header "Setup Complete!"

  local bucket_name="${PROJECT_ID}-terraform-state"

  echo "Configuration summary:"
  echo ""
  echo "  Project ID:  $PROJECT_ID"
  echo "  Environment: $ENVIRONMENT"
  echo "  Region:      $REGION"
  echo ""
  echo "Terraform state storage:"
  echo "  Bucket: gs://${bucket_name}"
  echo "  Prefix: ${ENVIRONMENT}/"
  echo "  Location: ${REGION}"
  echo ""
  echo "Next steps:"
  echo "  1. Validate setup: ./scripts/validate-setup.sh $PROJECT_ID"
  echo "  2. Review project in GCP Console: https://console.cloud.google.com/home/dashboard?project=$PROJECT_ID"
  echo "  3. Configure Terragrunt in infra/terragrunt.hcl:"
  echo "     - Set bucket: ${bucket_name}"
  echo "     - Set prefix: ${ENVIRONMENT}/"
  echo "     - Set project: ${PROJECT_ID}"
  echo "  4. Start creating Terraform modules in infra/modules/"
  echo ""

  if [ "$ENVIRONMENT" = "dev" ]; then
    echo "To add staging or prod environments later:"
    echo "  - Re-run this script with a different environment name"
    echo "  - Use the same bucket name but different prefixes (staging/, prod/)"
    echo ""
  fi

  print_success "GCP project setup complete!"
}

# Run main function
main "$@"
