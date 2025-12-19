#!/bin/bash

################################################################################
# GCP Project Setup Script
#
# This script creates GCP projects for dev, staging, and prod environments,
# enables required APIs, and sets up Terraform state buckets.
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Billing account ID available
# - Organization ID (if using GCP organization)
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

# Project configuration
PROJECT_PREFIX="generic-demo"
REGION="europe-west6"
PROJECTS=("dev")  # Start with dev only, add staging/prod later

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
  print_success "Authenticated with gcloud"

  # Get billing account
  print_info "Fetching billing accounts..."
  BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" 2>/dev/null)

  if [ -z "$BILLING_ACCOUNTS" ]; then
    print_error "No billing accounts found. Please set up billing at: https://console.cloud.google.com/billing"
    exit 1
  fi

  # If multiple billing accounts, let user choose
  BILLING_ACCOUNT_COUNT=$(echo "$BILLING_ACCOUNTS" | wc -l | xargs)

  if [ "$BILLING_ACCOUNT_COUNT" -eq 1 ]; then
    BILLING_ACCOUNT_ID=$BILLING_ACCOUNTS
    print_success "Using billing account: $BILLING_ACCOUNT_ID"
  else
    print_info "Multiple billing accounts found:"
    gcloud billing accounts list
    echo ""
    read -p "Enter billing account ID to use: " BILLING_ACCOUNT_ID
  fi

  echo ""
}

create_project() {
  local env=$1
  local project_id="${PROJECT_PREFIX}-${env}"

  print_info "Checking if project '$project_id' exists..."

  # Check if project already exists
  if gcloud projects describe "$project_id" &> /dev/null; then
    print_success "Project '$project_id' already exists, skipping creation"
    return 0
  fi

  print_info "Creating project: $project_id"

  # Create project
  if gcloud projects create "$project_id" --name="$project_id" 2>&1; then
    print_success "Project '$project_id' created"
  else
    print_error "Failed to create project '$project_id'"
    return 1
  fi

  # Link billing account
  print_info "Linking billing account to $project_id"
  if gcloud billing projects link "$project_id" --billing-account="$BILLING_ACCOUNT_ID" 2>&1; then
    print_success "Billing account linked to $project_id"
  else
    print_error "Failed to link billing account to $project_id"
    return 1
  fi
}

enable_apis() {
  local project_id=$1

  print_info "Enabling required APIs for $project_id"

  for api in "${REQUIRED_APIS[@]}"; do
    echo -n "  Enabling $api... "
    if gcloud services enable "$api" --project="$project_id" 2>&1 > /dev/null; then
      echo -e "${GREEN}✓${NC}"
    else
      echo -e "${RED}✗${NC}"
      print_error "Failed to enable $api"
    fi
  done

  print_success "APIs enabled for $project_id"
}

create_shared_state_bucket() {
  local bucket_name="${PROJECT_PREFIX}-terraform-state"
  local bucket_project="${PROJECT_PREFIX}-dev"  # Create in dev project

  print_info "Creating shared Terraform state bucket: $bucket_name"

  # Check if bucket already exists
  if gsutil ls -b "gs://${bucket_name}" &> /dev/null; then
    print_success "Bucket '$bucket_name' already exists, skipping creation"
    return 0
  fi

  # Ensure dev project exists
  if ! gcloud projects describe "$bucket_project" &> /dev/null; then
    print_error "Dev project '$bucket_project' must be created first"
    return 1
  fi

  # Create bucket in dev project
  print_info "Creating bucket in project: $bucket_project"
  if gsutil mb -p "$bucket_project" -l "$REGION" "gs://${bucket_name}" 2>&1; then
    print_success "Bucket '$bucket_name' created"
  else
    print_error "Failed to create bucket '$bucket_name'"
    return 1
  fi

  # Enable versioning
  print_info "Enabling versioning on $bucket_name"
  if gsutil versioning set on "gs://${bucket_name}" 2>&1; then
    print_success "Versioning enabled on $bucket_name"
  else
    print_error "Failed to enable versioning"
  fi

  # Set lifecycle policy to keep last 10 versions
  print_info "Setting lifecycle policy on $bucket_name"
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
    print_success "Lifecycle policy set on $bucket_name"
  else
    print_error "Failed to set lifecycle policy"
  fi

  rm /tmp/lifecycle.json

  # Create environment folders (optional, but helps with visibility)
  print_info "Creating environment prefixes in bucket"
  for env in "${PROJECTS[@]}"; do
    # Create a placeholder file to establish the folder
    echo "Terraform state for ${env} environment" | gsutil cp - "gs://${bucket_name}/${env}/.terragrunt-bucket-setup" 2>&1 > /dev/null || true
  done
  print_success "Environment prefixes created: ${PROJECTS[*]}"
}

setup_project() {
  local env=$1
  local project_id="${PROJECT_PREFIX}-${env}"

  print_header "Setting up $env environment (Project: $project_id)"

  create_project "$env"
  enable_apis "$project_id"

  print_success "Setup complete for $project_id\n"
}

################################################################################
# Main Execution
################################################################################

main() {
  print_header "GCP Project Setup - Development First Approach"

  echo "This script will set up your GCP infrastructure."
  echo ""
  echo "What it does:"
  echo "  1. Create GCP project(s)"
  echo "  2. Enable required APIs"
  echo "  3. Create Terraform state bucket with versioning"
  echo ""
  echo "Recommended: Start with DEV environment only, add staging/prod later."
  echo ""

  # Ask which environments to set up
  echo "Which environments do you want to set up?"
  echo "  1) Dev only (recommended to start)"
  echo "  2) Dev + Staging"
  echo "  3) Dev + Staging + Prod"
  echo ""
  read -p "Enter choice (1-3): " -n 1 -r choice
  echo ""
  echo ""

  case $choice in
    1)
      PROJECTS=("dev")
      print_info "Setting up DEV environment only"
      ;;
    2)
      PROJECTS=("dev" "staging")
      print_info "Setting up DEV and STAGING environments"
      ;;
    3)
      PROJECTS=("dev" "staging" "prod")
      print_info "Setting up DEV, STAGING, and PROD environments"
      ;;
    *)
      print_error "Invalid choice. Defaulting to DEV only."
      PROJECTS=("dev")
      ;;
  esac

  echo ""
  echo "Projects to be created:"
  for env in "${PROJECTS[@]}"; do
    echo "  - ${PROJECT_PREFIX}-${env}"
  done
  echo ""

  read -p "Do you want to continue? (y/n) " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled"
    exit 0
  fi

  check_prerequisites

  # Setup each environment
  for env in "${PROJECTS[@]}"; do
    setup_project "$env"
  done

  # Create shared state bucket (only once, in dev project)
  print_header "Setting up Shared Terraform State Storage"
  create_shared_state_bucket

  print_header "Setup Summary"

  echo "All projects have been set up successfully!"
  echo ""
  echo "Projects created:"
  for env in "${PROJECTS[@]}"; do
    project_id="${PROJECT_PREFIX}-${env}"
    echo "  - $project_id"
  done
  echo ""

  local bucket_name="${PROJECT_PREFIX}-terraform-state"
  echo "Terraform state storage:"
  echo "  Bucket: gs://${bucket_name}"
  echo "  Location: ${REGION} (in ${PROJECT_PREFIX}-dev project)"
  echo ""
  echo "  Environment state prefixes:"
  for env in "${PROJECTS[@]}"; do
    echo "    - gs://${bucket_name}/${env}/"
  done
  echo ""

  # Show how to add more environments later
  if [ ${#PROJECTS[@]} -eq 1 ] && [ "${PROJECTS[0]}" = "dev" ]; then
    echo "To add staging or prod later:"
    echo "  1. Re-run this script and select option 2 or 3"
    echo "  2. New environment folders will be added to the same state bucket"
    echo ""
  fi

  echo "Next steps:"
  echo "  1. Validate setup: ./scripts/validate-setup.sh"
  echo "  2. Review created projects in GCP Console"
  echo "  3. Start creating Terraform modules in infra/modules/"
  echo "  4. Configure Terragrunt in infra/stacks/dev/"
  echo "     - Set bucket: ${bucket_name}"
  echo "     - Set prefix: dev/"
  echo ""
  print_success "GCP project setup complete!"
}

# Run main function
main "$@"
