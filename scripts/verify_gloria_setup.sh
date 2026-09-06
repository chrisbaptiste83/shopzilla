#!/usr/bin/env bash
# ==============================================================================
# Shopzilla: Gloria's AWS, Stripe & Tailscale Environment Verifier
# ==============================================================================
# Run this script to verify that Gloria's AWS infrastructure, Stripe account,
# Secrets Manager entries, and Tailscale mesh are properly configured.
#
# Usage:
#   bash scripts/verify_gloria_setup.sh
#   STRIPE_SECRET_KEY=sk_... bash scripts/verify_gloria_setup.sh
# ==============================================================================

set -uo pipefail

REGION="${AWS_REGION:-us-east-2}"
BUCKET_NAME="${S3_BUCKET_NAME:-glorias-embroidery-prod-assets-na}"
ECR_REPO_NAME="shopzilla"
ROLE_NAME="ecsTaskExecutionRole"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass_count=0
warn_count=0
fail_count=0

pass() {
  echo -e "  [${GREEN}PASS${NC}] $1"
  ((pass_count++))
}

warn() {
  echo -e "  [${YELLOW}WARN${NC}] $1"
  ((warn_count++))
}

fail() {
  echo -e "  [${RED}FAIL${NC}] $1"
  ((fail_count++))
}

info() {
  echo -e "  [${BLUE}INFO${NC}] $1"
}

echo "================================================================="
echo "Shopzilla Environment Verification Audit"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Target Region: ${REGION}"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. AWS CLI & Caller Identity
# ------------------------------------------------------------------------------
echo -e "\n1. AWS Identity & Access"
if ! command -v aws >/dev/null 2>&1; then
  fail "AWS CLI is not installed or not in PATH."
else
  CALLER_JSON=$(aws sts get-caller-identity 2>/dev/null || true)
  if [ -z "$CALLER_JSON" ]; then
    fail "Unable to authenticate with AWS. Run 'aws configure' or check credentials."
  else
    ACCOUNT_ID=$(echo "$CALLER_JSON" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
    ARN=$(echo "$CALLER_JSON" | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)
    info "Active AWS Account: ${ACCOUNT_ID}"
    info "Caller ARN:         ${ARN}"

    if [[ "$ARN" == *":root" ]]; then
      warn "Running as AWS ROOT account. Least-privilege best practice requires using an IAM user (e.g. gloria-admin)."
    else
      pass "Operating as IAM identity: ${ARN}"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 2. S3 Bucket
# ------------------------------------------------------------------------------
echo -e "\n2. S3 Assets Bucket (${BUCKET_NAME})"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  pass "Bucket exists and caller has access."

  # Check encryption
  ENC=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" 2>/dev/null || true)
  if echo "$ENC" | grep -q "AES256"; then
    pass "Default SSE-S3 (AES256) encryption enabled."
  else
    warn "Default AES-256 encryption not detected."
  fi

  # Check public access block
  PAB=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" 2>/dev/null || true)
  if echo "$PAB" | grep -q '"BlockPublicAcls": true'; then
    pass "Public ACLs blocked (enforcing bucket-policy-based access)."
  else
    warn "Public ACL block not strictly configured."
  fi
else
  fail "S3 bucket '${BUCKET_NAME}' does not exist or access denied."
fi

# ------------------------------------------------------------------------------
# 3. ECR Repository
# ------------------------------------------------------------------------------
echo -e "\n3. ECR Container Repository (${ECR_REPO_NAME})"
ECR_CHECK=$(aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" 2>/dev/null || true)
if echo "$ECR_CHECK" | grep -q "$ECR_REPO_NAME"; then
  pass "ECR repository '${ECR_REPO_NAME}' exists in ${REGION}."
  if echo "$ECR_CHECK" | grep -q '"scanOnPush": true'; then
    pass "Vulnerability scan-on-push enabled."
  else
    warn "Vulnerability scan-on-push not enabled on repository."
  fi
else
  fail "ECR repository '${ECR_REPO_NAME}' not found in ${REGION}."
fi

# ------------------------------------------------------------------------------
# 4. IAM ECS Execution Role
# ------------------------------------------------------------------------------
echo -e "\n4. IAM ECS Execution Role (${ROLE_NAME})"
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  pass "Role '${ROLE_NAME}' exists."

  # Check AWS managed policy
  ATTACHED=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" 2>/dev/null || true)
  if echo "$ATTACHED" | grep -q "AmazonECSTaskExecutionRolePolicy"; then
    pass "AmazonECSTaskExecutionRolePolicy attached."
  else
    fail "AmazonECSTaskExecutionRolePolicy NOT attached."
  fi

  # Check inline policy
  INLINE=$(aws iam list-role-policies --role-name "$ROLE_NAME" 2>/dev/null || true)
  if echo "$INLINE" | grep -q "ShopzillaSecretsRead"; then
    pass "Inline policy 'ShopzillaSecretsRead' attached."
  else
    fail "Inline policy 'ShopzillaSecretsRead' NOT found on role."
  fi
else
  fail "Role '${ROLE_NAME}' does not exist."
fi

# ------------------------------------------------------------------------------
# 5. AWS Secrets Manager
# ------------------------------------------------------------------------------
echo -e "\n5. AWS Secrets Manager Secrets"
SECRETS=(
  "shopzilla/rails-master-key"
  "shopzilla/database-url"
  "shopzilla/stripe-secret-key"
  "shopzilla/stripe-webhook-secret"
)

for sec in "${SECRETS[@]}"; do
  if aws secretsmanager describe-secret --secret-id "$sec" --region "$REGION" >/dev/null 2>&1; then
    pass "Secret '${sec}' exists."
  else
    fail "Secret '${sec}' MISSING in ${REGION}."
  fi
done

# ------------------------------------------------------------------------------
# 6. Stripe API Connection
# ------------------------------------------------------------------------------
echo -e "\n6. Stripe Merchant Integration"
STRIPE_KEY="${STRIPE_SECRET_KEY:-}"
if [ -z "$STRIPE_KEY" ]; then
  # Try reading from Secrets Manager if caller has access
  SEC_VAL=$(aws secretsmanager get-secret-value --secret-id "shopzilla/stripe-secret-key" --region "$REGION" --query "SecretString" --output text 2>/dev/null || true)
  if [ -n "$SEC_VAL" ] && [[ "$SEC_VAL" == sk_* ]]; then
    STRIPE_KEY="$SEC_VAL"
    info "Retrieved Stripe key from AWS Secrets Manager for verification."
  fi
fi

if [ -n "$STRIPE_KEY" ]; then
  BAL_RESP=$(curl -s -H "Authorization: Bearer ${STRIPE_KEY}" https://api.stripe.com/v1/balance 2>/dev/null || true) # gitleaks:allow
  if echo "$BAL_RESP" | grep -q '"object": "balance"'; then
    IS_LIVE=$(echo "$BAL_RESP" | grep -o '"livemode": [^,]*' | cut -d':' -f2 | tr -d ' ')
    pass "Stripe API authenticated successfully."
    info "Stripe livemode: ${IS_LIVE}"
    if [ "$IS_LIVE" == "true" ]; then
      pass "Stripe account is in LIVE mode."
    else
      info "Stripe account is in TEST mode."
    fi
  else
    ERR_MSG=$(echo "$BAL_RESP" | grep -o '"message": "[^"]*' | cut -d'"' -f4)
    fail "Stripe authentication failed: ${ERR_MSG:-unknown error}"
  fi
else
  warn "STRIPE_SECRET_KEY not supplied; skipping direct Stripe balance ping."
fi

# ------------------------------------------------------------------------------
# 7. Tailscale Mesh Network
# ------------------------------------------------------------------------------
echo -e "\n7. Tailscale Mesh Network"
if ! command -v tailscale >/dev/null 2>&1; then
  warn "Tailscale CLI not found in PATH."
else
  TS_STATUS=$(tailscale status 2>/dev/null || true)
  if [ -n "$TS_STATUS" ]; then
    TS_IP=$(tailscale ip -4 2>/dev/null || true)
    pass "Tailscale daemon is active. Local Tailscale IP: ${TS_IP}"
  else
    warn "Tailscale is not running or logged in."
  fi
fi

# ------------------------------------------------------------------------------
# 8. Catalog Exchange Staging
# ------------------------------------------------------------------------------
echo -e "\n8. Catalog Exchange Directory"
EXCHANGE_DIR="/Users/Shared/ShopzillaCatalog/10-exchange/ready"
if [ -d "$EXCHANGE_DIR" ]; then
  pass "Exchange root directory exists: ${EXCHANGE_DIR}"
  BATCH_COUNT=$(find "$EXCHANGE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  info "Staged batches found: ${BATCH_COUNT}"
  for b in "$EXCHANGE_DIR"/*; do
    if [ -d "$b" ]; then
      b_name=$(basename "$b")
      if [ -f "$b/checksums.sha256" ] && [ -f "$b/manifest.json" ]; then
        pass "Batch '${b_name}' has manifest.json and checksums.sha256."
      else
        warn "Batch '${b_name}' is missing manifest or checksums."
      fi
    fi
  done
else
  warn "Exchange root directory '${EXCHANGE_DIR}' not yet initialized."
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo -e "\n================================================================="
echo "Verification Summary"
echo -e "  ${GREEN}Passed:${NC}   ${pass_count}"
echo -e "  ${YELLOW}Warnings:${NC} ${warn_count}"
echo -e "  ${RED}Failures:${NC} ${fail_count}"
echo "================================================================="

if [ "$fail_count" -eq 0 ]; then
  echo -e "${GREEN}All required components verified! System is ready for deployment.${NC}\n"
  exit 0
else
  echo -e "${RED}One or more checks failed. Review the errors above before deploying.${NC}\n"
  exit 1
fi
