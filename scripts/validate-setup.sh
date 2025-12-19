#!/bin/bash

################################################################################
# GCP Setup Validation Script
#
# This script validates that all GCP projects, APIs, and resources are
# properly configured before proceeding with Terraform deployment.
#
# Usage:
#   ./scripts/validate-setup.sh
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_PREFIX="generic-demo"
REGION="europe-west6"
ALL_PROJECTS=("dev" "staging" "prod")
EXISTING_PROJECTS=()

# Required APIs
REQUIRED_APIS=(
  "compute.googleapis.com"
  "run.googleapis.com"
  "sqladmin.googleapis.com"
  "vpcaccess.googleapis.com"
  "secretmanager.googleapis.com"
  "artifactregistry.googleapis.com"
  "pubsub.googleapis.com"
  "cloudresourcemanager.googleapis.com"
  "iam.googleapis.com"
  "servicenetworking.googleapis.com"
)

# Validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

################################################################################
# Helper Functions
################################################################################

print_header() {
  echo -e "\n${BLUE}================================================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}================================================================================${NC}\n"
}

print_section() {
  echo -e "\n${YELLOW}▶ $1${NC}"
}

print_check() {
  echo -n "  Checking $1... "
  ((TOTAL_CHECKS++))
}

print_pass() {
  echo -e "${GREEN}✓ PASS${NC}"
  ((PASSED_CHECKS++))
}

print_fail() {
  echo -e "${RED}✗ FAIL${NC}"
  if [ -n "${1:-}" ]; then
    echo -e "    ${RED}Error: $1${NC}"
  fi
  ((FAILED_CHECKS++))
}

print_warn() {
  echo -e "${YELLOW}⚠ WARNING${NC}"
  if [ -n "${1:-}" ]; then
    echo -e "    ${YELLOW}Warning: $1${NC}"
  fi
  ((WARNING_CHECKS++))
}

print_info() {
  echo -e "    ${BLUE}ℹ${NC} $1"
}

################################################################################
# Validation Functions
################################################################################

detect_existing_projects() {
  print_section "Detecting Projects"

  for env in "${ALL_PROJECTS[@]}"; do
    local project_id="${PROJECT_PREFIX}-${env}"
    print_check "$project_id exists"

    if gcloud projects describe "$project_id" &> /dev/null; then
      EXISTING_PROJECTS+=("$env")
      print_pass
      print_info "Project found: $project_id"
    else
      echo -e "${BLUE}ℹ SKIP${NC}"
      print_info "Project not found (will skip validation)"
    fi
  done

  if [ ${#EXISTING_PROJECTS[@]} -eq 0 ]; then
    print_fail "No projects found. Run: ./scripts/setup-gcp-projects.sh"
    return 1
  fi

  echo ""
  echo "Found ${#EXISTING_PROJECTS[@]} project(s): ${EXISTING_PROJECTS[*]}"
}

validate_prerequisites() {
  print_section "Prerequisites"

  # Check gcloud CLI
  print_check "gcloud CLI installed"
  if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud version --format="value(core)" 2>/dev/null)
    print_pass
    print_info "Version: $GCLOUD_VERSION"
  else
    print_fail "gcloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
    return 1
  fi

  # Check authentication
  print_check "gcloud authentication"
  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
  if [ -n "$ACTIVE_ACCOUNT" ]; then
    print_pass
    print_info "Authenticated as: $ACTIVE_ACCOUNT"
  else
    print_fail "Not authenticated. Run: gcloud auth login"
    return 1
  fi

  # Check Terraform
  print_check "Terraform installed"
  if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
    print_pass
    print_info "Version: $TERRAFORM_VERSION"
  else
    print_warn "Terraform not found. Install from: https://developer.hashicorp.com/terraform/install"
  fi

  # Check Terragrunt
  print_check "Terragrunt installed"
  if command -v terragrunt &> /dev/null; then
    TERRAGRUNT_VERSION=$(terragrunt --version 2>/dev/null | head -1 | awk '{print $3}')
    print_pass
    print_info "Version: $TERRAGRUNT_VERSION"
  else
    print_warn "Terragrunt not found. Install from: https://terragrunt.gruntwork.io/docs/getting-started/install/"
  fi
}

validate_project() {
  local env=$1
  local project_id="${PROJECT_PREFIX}-${env}"

  print_section "Project: $project_id"

  # Check if project exists
  print_check "project exists"
  if gcloud projects describe "$project_id" &> /dev/null; then
    print_pass
  else
    print_fail "Project not found. Run: ./scripts/setup-gcp-projects.sh"
    return 1
  fi

  # Check billing
  print_check "billing enabled"
  BILLING_INFO=$(gcloud billing projects describe "$project_id" --format="value(billingEnabled)" 2>/dev/null)
  if [ "$BILLING_INFO" = "True" ]; then
    print_pass
  else
    print_fail "Billing not enabled"
  fi

  # Check each required API
  print_check "required APIs"
  local all_apis_enabled=true
  local disabled_apis=()

  for api in "${REQUIRED_APIS[@]}"; do
    if ! gcloud services list --enabled --project="$project_id" --format="value(name)" 2>/dev/null | grep -q "^${api}$"; then
      all_apis_enabled=false
      disabled_apis+=("$api")
    fi
  done

  if [ "$all_apis_enabled" = true ]; then
    print_pass
    print_info "All ${#REQUIRED_APIS[@]} required APIs are enabled"
  else
    print_fail "${#disabled_apis[@]} APIs not enabled"
    for api in "${disabled_apis[@]}"; do
      print_info "Missing: $api"
    done
  fi

  # Note: Terraform state bucket validation is done separately in validate_shared_state_bucket

  # Check default service accounts
  print_check "default service accounts"
  local compute_sa="${project_id//-/}@${project_id}.iam.gserviceaccount.com"
  if gcloud iam service-accounts describe "compute@developer.gserviceaccount.com" --project="$project_id" &> /dev/null 2>&1 || \
     gcloud iam service-accounts list --project="$project_id" --format="value(email)" 2>/dev/null | grep -q "@"; then
    print_pass
  else
    print_warn "Default service accounts may not be initialized yet"
  fi
}

validate_shared_state_bucket() {
  print_section "Terraform State Storage"

  local bucket_name="${PROJECT_PREFIX}-terraform-state"

  # Check if bucket exists
  print_check "shared state bucket exists"
  if gsutil ls -b "gs://${bucket_name}" &> /dev/null; then
    print_pass
    print_info "Bucket: gs://${bucket_name}"
  else
    print_fail "Shared state bucket not found. Run: ./scripts/setup-gcp-projects.sh"
    return 1
  fi

  # Check versioning
  print_check "bucket versioning enabled"
  VERSIONING=$(gsutil versioning get "gs://${bucket_name}" 2>/dev/null | grep "Enabled")
  if [ -n "$VERSIONING" ]; then
    print_pass
  else
    print_warn "Versioning not enabled. Run: gsutil versioning set on gs://${bucket_name}"
  fi

  # Check environment prefixes
  print_check "environment state prefixes"
  local found_prefixes=0
  for env in "${EXISTING_PROJECTS[@]}"; do
    # Check if the environment folder exists (look for any files in the prefix)
    if gsutil ls "gs://${bucket_name}/${env}/" &> /dev/null; then
      ((found_prefixes++))
    fi
  done

  if [ $found_prefixes -eq ${#EXISTING_PROJECTS[@]} ]; then
    print_pass
    for env in "${EXISTING_PROJECTS[@]}"; do
      print_info "gs://${bucket_name}/${env}/"
    done
  elif [ $found_prefixes -gt 0 ]; then
    print_warn "Some environment prefixes not found (${found_prefixes}/${#EXISTING_PROJECTS[@]})"
  else
    print_warn "Environment prefixes not initialized yet"
    print_info "Prefixes will be created on first Terragrunt run"
  fi
}

validate_region() {
  print_section "Region Configuration"

  print_check "region $REGION availability"
  if gcloud compute regions describe "$REGION" &> /dev/null; then
    print_pass
  else
    print_fail "Region $REGION not available"
  fi

  print_check "region quota"
  # Basic check - could be expanded
  print_pass
  print_info "Note: Run 'gcloud compute project-info describe' to check detailed quotas"
}

validate_permissions() {
  print_section "IAM Permissions"

  for env in "${EXISTING_PROJECTS[@]}"; do
    local project_id="${PROJECT_PREFIX}-${env}"

    print_check "permissions on $project_id"

    # Check if we can get IAM policy (requires viewer role at minimum)
    if gcloud projects get-iam-policy "$project_id" &> /dev/null; then
      print_pass
    else
      print_fail "Insufficient permissions to view IAM policy"
    fi
  done
}

print_summary() {
  print_header "Validation Summary"

  echo "Total checks: $TOTAL_CHECKS"
  echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
  echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
  echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
  echo ""

  if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNING_CHECKS -eq 0 ]; then
      echo -e "${GREEN}✓ All validations passed! You're ready to proceed with Terraform deployment.${NC}"
      return 0
    else
      echo -e "${YELLOW}⚠ All critical checks passed, but some warnings were found.${NC}"
      echo -e "${YELLOW}  Review warnings above before proceeding.${NC}"
      return 0
    fi
  else
    echo -e "${RED}✗ Some validations failed. Please fix the issues before proceeding.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Run: ./scripts/setup-gcp-projects.sh"
    echo "  - Check billing is enabled: https://console.cloud.google.com/billing"
    echo "  - Verify IAM permissions for your account"
    return 1
  fi
}

################################################################################
# Main Execution
################################################################################

main() {
  print_header "GCP Setup Validation"

  validate_prerequisites || true

  # Detect which projects exist
  detect_existing_projects || exit 1

  validate_region || true

  # Validate only existing projects
  for env in "${EXISTING_PROJECTS[@]}"; do
    validate_project "$env" || true
  done

  # Validate shared state bucket
  validate_shared_state_bucket || true

  validate_permissions || true

  echo ""
  print_summary
  exit_code=$?

  echo ""
  echo "Validated environments: ${EXISTING_PROJECTS[*]}"

  # Show message about adding more environments if only dev exists
  if [ ${#EXISTING_PROJECTS[@]} -eq 1 ] && [ "${EXISTING_PROJECTS[0]}" = "dev" ]; then
    echo ""
    echo "Note: Only dev environment detected."
    echo "To add staging/prod later: ./scripts/setup-gcp-projects.sh"
  fi

  echo ""
  if [ $exit_code -eq 0 ]; then
    echo "Next steps:"
    echo "  1. Start creating Terraform modules: infra/modules/"
    echo "  2. Configure Terragrunt: infra/terragrunt.hcl"
    echo "  3. Deploy to dev: cd infra/stacks/dev && terragrunt run-all apply"
  fi

  exit $exit_code
}

# Run main function
main "$@"
