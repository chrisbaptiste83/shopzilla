#!/usr/bin/env bash
# ==============================================================================
# Gloria's Embroidery - AWS Account Migration & Baseline Infrastructure Setup
# Target Account: glorias-embroidery-prod
# Region: us-east-2 (Ohio)
# ==============================================================================
set -euo pipefail

REGION="${AWS_REGION:-us-east-2}"
BUCKET_NAME="${GLORIA_S3_BUCKET:-glorias-embroidery-prod-assets-na}"
ECR_REPO="shopzilla"
ROLE_NAME="ecsTaskExecutionRole"

echo "================================================================="
echo "  Gloria's Embroidery — AWS Infrastructure Setup & Learning Lab  "
echo "================================================================="

# 1. Identity & Credential Pre-flight Check
echo "[1/6] Verifying active AWS Identity (Least Privilege & Identity check)..."
if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed. Please install it with 'brew install awscli' or official installer." >&2
  exit 1
fi

IDENTITY_JSON="$(aws sts get-caller-identity --output json 2>/dev/null || true)"
if [[ -z "$IDENTITY_JSON" ]]; then
  echo "ERROR: Unable to authenticate with AWS. Run 'aws configure' with gloria-admin credentials first." >&2
  exit 1
fi

ACCOUNT_ID="$(echo "$IDENTITY_JSON" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)"
CALLER_ARN="$(echo "$IDENTITY_JSON" | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)"

echo "  Active Account ID: $ACCOUNT_ID"
echo "  Active Identity ARN: $CALLER_ARN"

if [[ "$CALLER_ARN" == *":root" ]]; then
  echo "  [SECURITY WARNING] You are currently authenticated as the AWS ROOT user!"
  echo "  Best practice: Lock Root with hardware/app MFA, generate no access keys, and create an IAM Admin user (e.g. gloria-admin)."
  read -r -p "  Continue anyway for initial bootstrapping? (y/N) " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
else
  echo "  [PASS] Operating as IAM Identity (Proper separation of duties)."
fi

# 2. S3 Asset Bucket Creation & Data Classification
echo ""
echo "[2/6] Configuring S3 Storage ($BUCKET_NAME in $REGION)..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "  Bucket $BUCKET_NAME already exists and is accessible."
else
  echo "  Creating bucket $BUCKET_NAME..."
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
  echo "  Enforcing default AES-256 Server-Side Encryption (Encryption at rest)..."
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

  echo "  Configuring Public Access Block..."
  aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{"BlockPublicAcls": true, "IgnorePublicAcls": true, "BlockPublicPolicy": false, "RestrictPublicBuckets": false}'

  echo "  Applying scoped public-read policy strictly to 'products/*' prefix..."
  aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Sid\": \"PublicReadForProductImages\",
          \"Effect\": \"Allow\",
          \"Principal\": \"*\",
          \"Action\": \"s3:GetObject\",
          \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/products/*\"
        }
      ]
    }"
  echo "  [PASS] S3 bucket created with confidential 'downloads/*' isolated from public 'products/*'."
fi

# 3. Amazon ECR Private Container Registry
echo ""
echo "[3/6] Configuring Amazon ECR repository ($ECR_REPO)..."
if aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$REGION" >/dev/null 2>&1; then
  echo "  ECR repository $ECR_REPO already exists."
else
  echo "  Creating private ECR repository with scan-on-push vulnerability scanning..."
  aws ecr create-repository \
    --repository-name "$ECR_REPO" \
    --region "$REGION" \
    --image-scanning-configuration scanOnPush=true
  echo "  [PASS] ECR repository ready: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"
fi

# 4. IAM ECS Task Execution Role (Least Privilege)
echo ""
echo "[4/6] Verifying ECS Task Execution Role ($ROLE_NAME)..."
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "  Role $ROLE_NAME already exists."
else
  echo "  Creating $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "ecs-tasks.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }'

  echo "  Attaching AmazonECSTaskExecutionRolePolicy..."
  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
fi

echo "  Ensuring scoped Secrets Manager read policy on $ROLE_NAME..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "ShopzillaSecretsRead" \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": \"secretsmanager:GetSecretValue\",
      \"Resource\": \"arn:aws:secretsmanager:$REGION:$ACCOUNT_ID:secret:shopzilla/*\"
    }]
  }"
echo "  [PASS] Execution role configured."

# 5. AWS Secrets Manager Template Checklist
echo ""
echo "[5/6] Checking Secrets Manager entries..."
for secret in "shopzilla/rails-master-key" "shopzilla/database-url" "shopzilla/stripe-secret-key" "shopzilla/stripe-webhook-secret"; do
  if aws secretsmanager describe-secret --secret-id "$secret" --region "$REGION" >/dev/null 2>&1; then
    echo "  [OK] Secret '$secret' exists."
  else
    echo "  [TODO] Secret '$secret' is missing. Create it when ready using:"
    echo "         aws secretsmanager create-secret --name '$secret' --secret-string '...' --region $REGION"
  fi
done

# 6. SES Domain Verification Instructions
echo ""
echo "[6/6] AWS Simple Email Service (SES) Checklist:"
echo "  Domain: gloriasembroideryshop.com"
echo "  To verify domain with Easy DKIM:"
echo "    aws sesv2 create-email-identity --email-identity gloriasembroideryshop.com --region $REGION"
echo ""
echo "================================================================="
echo "  Setup verification complete for Account $ACCOUNT_ID ($REGION)  "
echo "================================================================="
