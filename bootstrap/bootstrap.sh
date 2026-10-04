#!/usr/bin/env bash
#
# One-time (and safe to re-run) setup of the OpenTofu state backend:
# an S3 bucket for state files and a DynamoDB table for state locking.
#
# Deliberately plain AWS CLI, not OpenTofu — see IaC.md's Toolchain section
# for why. Every step checks whether its resource already exists first, so
# running this twice is always safe.
#
# Usage:
#   ./bootstrap.sh --bucket-name conflow-tofu-state --region us-east-1 [--table-name conflow-tofu-locks] [--profile conflow-tofu-deployer]
#
# Requires: the AWS CLI, configured with credentials for the dedicated
# deployer IAM user described in prerequisites.md (never the root user).

set -euo pipefail

TABLE_NAME="conflow-tofu-locks"
PROFILE=""
BUCKET_NAME=""
REGION=""

usage() {
  echo "Usage: $0 --bucket-name <name> --region <aws-region> [--table-name <name>] [--profile <aws-profile>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket-name) BUCKET_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --table-name) TABLE_NAME="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

[[ -z "$BUCKET_NAME" ]] && { echo "Error: --bucket-name is required"; usage; }
[[ -z "$REGION" ]] && { echo "Error: --region is required"; usage; }

AWS=(aws --region "$REGION")
[[ -n "$PROFILE" ]] && AWS+=(--profile "$PROFILE")

echo "== OpenTofu state backend bootstrap =="
echo "Region:  $REGION"
echo "Bucket:  $BUCKET_NAME"
echo "Table:   $TABLE_NAME"
echo

# --- S3 bucket for state ---------------------------------------------------

if "${AWS[@]}" s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "[s3] bucket $BUCKET_NAME already exists — skipping create"
else
  echo "[s3] creating bucket $BUCKET_NAME"
  if [[ "$REGION" == "us-east-1" ]]; then
    # us-east-1 is the one region that rejects an explicit LocationConstraint.
    "${AWS[@]}" s3api create-bucket --bucket "$BUCKET_NAME"
  else
    "${AWS[@]}" s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
fi

echo "[s3] enabling versioning (state history + recovery from a bad apply)"
"${AWS[@]}" s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "[s3] enabling default encryption (SSE-S3)"
"${AWS[@]}" s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "[s3] blocking all public access"
"${AWS[@]}" s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "[s3] tagging bucket"
"${AWS[@]}" s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging 'TagSet=[{Key=product,Value=conflow},{Key=purpose,Value=opentofu-state-backend}]'

# --- DynamoDB lock table -----------------------------------------------------

if "${AWS[@]}" dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
  echo "[dynamodb] table $TABLE_NAME already exists — skipping create"
else
  echo "[dynamodb] creating lock table $TABLE_NAME"
  "${AWS[@]}" dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=product,Value=conflow Key=purpose,Value=opentofu-state-lock

  echo "[dynamodb] waiting for table to become active"
  "${AWS[@]}" dynamodb wait table-exists --table-name "$TABLE_NAME"
fi

echo
echo "Done. Put these in each environment's backend.tf:"
echo "  bucket         = \"$BUCKET_NAME\""
echo "  dynamodb_table = \"$TABLE_NAME\""
echo "  region         = \"$REGION\""
