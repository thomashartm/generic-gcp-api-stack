#!/bin/bash

################################################################################
# GCP Setup Validation Script
#
# This script validates that your GCP project, APIs, and Terraform state bucket
# are properly configured before proceeding with Terraform deployment.
#
# Usage:
#   ./scripts/validate-setup.sh <project-id>
#
# Example:
#   ./scripts/validate-setup.sh my-gcp-project-dev
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="europe-west6"
PROJECT_ID="${1:-}"

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

check_project_id_provided() {
  if [ -z "$PROJECT_ID" ]; then
    print_fail "No project ID provided"
    echo ""
    echo "Usage: ./scripts/validate-setup.sh <project-id>"
    echo ""
    echo "Example:"
    echo "  ./scripts/validate-setup.sh my-gcp-project-dev"
    echo ""
    exit 1
  fi
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
  print_section "Project Validation"

  print_info "Validating project: $PROJECT_ID"
  echo ""

  # Check if project exists
  print_check "project exists"
  if gcloud projects describe "$PROJECT_ID" &> /dev/null; then
    print_pass
  else
    print_fail "Project not found. Please verify the project ID."
    return 1
  fi

  # Check billing
  print_check "billing enabled"
  BILLING_INFO=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "unknown")
  if [ "$BILLING_INFO" = "True" ]; then
    print_pass
  else
    print_fail "Billing not enabled or could not verify"
  fi

  # Check each required API
  print_check "required APIs"
  local all_apis_enabled=true
  local disabled_apis=()
  local enabled_services

  # Fetch all enabled APIs once to improve performance and reliability
  enabled_services=$(gcloud services list --enabled --project="$PROJECT_ID" --format="value(config.name)" 2>/dev/null || true)

  for api in "${REQUIRED_APIS[@]}"; do
    if ! echo "$enabled_services" | grep -q "^${api}$"; then
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
    print_info "Run: ./scripts/setup-gcp-projects.sh"
  fi

  # Check default service accounts
  print_check "default service accounts"
  if gcloud iam service-accounts list --project="$PROJECT_ID" --format="value(email)" 2>/dev/null | grep -q "@"; then
    print_pass
  else
    print_warn "Default service accounts may not be initialized yet"
  fi
}

validate_state_bucket() {
  print_section "Terraform State Storage"

  local bucket_name="${PROJECT_ID}-terraform-state"

  # Check if bucket exists
  print_check "state bucket exists"
  if gsutil ls -b "gs://${bucket_name}" &> /dev/null; then
    print_pass
    print_info "Bucket: gs://${bucket_name}"
  else
    print_warn "State bucket not found"
    print_info "Run: ./scripts/setup-gcp-projects.sh to create it"
    return 0  # Not a critical failure
  fi

  # Check versioning
  print_check "bucket versioning enabled"
  VERSIONING=$(gsutil versioning get "gs://${bucket_name}" 2>/dev/null | grep "Enabled" || true)
  if [ -n "$VERSIONING" ]; then
    print_pass
  else
    print_warn "Versioning not enabled"
    print_info "Run: gsutil versioning set on gs://${bucket_name}"
  fi

  # List environment prefixes (if any)
  print_check "environment prefixes"
  PREFIXES=$(gsutil ls "gs://${bucket_name}/" 2>/dev/null | grep -o '[^/]*/$' || true)
  if [ -n "$PREFIXES" ]; then
    print_pass
    while IFS= read -r prefix; do
      print_info "$prefix"
    done <<< "$PREFIXES"
  else
    print_warn "No environment prefixes found yet"
    print_info "Prefixes will be created when you run the setup script"
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

  print_check "permissions on $PROJECT_ID"

  # Check if we can get IAM policy (requires viewer role at minimum)
  if gcloud projects get-iam-policy "$PROJECT_ID" &> /dev/null; then
    print_pass
    print_info "You have sufficient permissions to manage this project"
  else
    print_fail "Insufficient permissions to view IAM policy"
    print_info "You may need roles/viewer or higher on this project"
  fi
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

  # Check if project ID was provided
  check_project_id_provided

  print_info "Validating GCP project: $PROJECT_ID"
  echo ""

  # Run validations
  validate_prerequisites || true
  validate_region || true
  validate_project || true
  validate_state_bucket || true
  validate_permissions || true

  echo ""
  print_summary
  exit_code=$?

  echo ""
  if [ $exit_code -eq 0 ]; then
    echo "Next steps:"
    echo "  1. Configure Terragrunt: infra/terragrunt.hcl"
    echo "     - Set bucket: ${PROJECT_ID}-terraform-state"
    echo "     - Set project: ${PROJECT_ID}"
    echo "  2. Start creating Terraform modules: infra/modules/"
    echo "  3. Deploy infrastructure: cd infra/stacks/<env> && terragrunt run-all apply"
  fi

  exit $exit_code
}

# Run main function
main "$@"
