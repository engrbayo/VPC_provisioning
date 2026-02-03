#!/bin/bash
# Script to empty a versioned S3 bucket and run terraform destroy
# Usage: ./empty_s3_bucket.sh <bucket-name>

set -e

BUCKET="${1:-secure-vpc-flow-logs-20260202050033120800000002}"

echo "=================================================="
echo "Emptying S3 Bucket: $BUCKET"
echo "=================================================="

# Check if bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "❌ Error: Bucket '$BUCKET' not found or not accessible"
    exit 1
fi

echo ""
echo "🗑️  Deleting all object versions..."
VERSION_COUNT=0
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output text | \
while read -r key versionId; do
  [ -z "$key" ] && continue
  echo "   Deleting: $key (version: ${versionId:0:12}...)"
  aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$versionId" > /dev/null
  ((VERSION_COUNT++))
done

echo "✓ Deleted $VERSION_COUNT object versions"

echo ""
echo "🗑️  Deleting all delete markers..."
MARKER_COUNT=0
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
  --output text | \
while read -r key versionId; do
  [ -z "$key" ] && continue
  echo "   Deleting marker: $key (version: ${versionId:0:12}...)"
  aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$versionId" > /dev/null
  ((MARKER_COUNT++))
done

echo "✓ Deleted $MARKER_COUNT delete markers"

echo ""
echo "=================================================="
echo "✅ Bucket '$BUCKET' is now empty!"
echo "=================================================="
echo ""
echo "Running terraform destroy..."
echo ""

terraform destroy
