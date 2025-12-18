#!/bin/bash
# fetch-work-item.sh
# Fetches work item details from Azure DevOps REST API
#
# Usage: ./fetch-work-item.sh <work-item-id> <access-token> <output-file>

set -e

WORK_ITEM_ID="$1"
ACCESS_TOKEN="$2"
OUTPUT_FILE="$3"

# Defaults from environment or fallback
ORG="${AZURE_DEVOPS_ORG:-jasonpaffES}"
PROJECT="${AZURE_DEVOPS_PROJECT:-Head Shakers}"

# URL encode the project name
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

if [ -z "$WORK_ITEM_ID" ] || [ -z "$ACCESS_TOKEN" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <work-item-id> <access-token> <output-file>"
  exit 1
fi

echo "Fetching work item #$WORK_ITEM_ID from $ORG/$PROJECT..."

# Fetch work item with all fields
API_URL="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/wit/workitems/$WORK_ITEM_ID?api-version=7.0"

HTTP_STATUS=$(curl -s -w "%{http_code}" -o "$OUTPUT_FILE" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "$API_URL")

if [ "$HTTP_STATUS" != "200" ]; then
  echo "Error: Failed to fetch work item. HTTP Status: $HTTP_STATUS"
  cat "$OUTPUT_FILE"
  exit 1
fi

# Validate JSON
if ! jq empty "$OUTPUT_FILE" 2>/dev/null; then
  echo "Error: Invalid JSON response"
  cat "$OUTPUT_FILE"
  exit 1
fi

# Display summary
TITLE=$(jq -r '.fields["System.Title"]' "$OUTPUT_FILE")
STATE=$(jq -r '.fields["System.State"]' "$OUTPUT_FILE")
TYPE=$(jq -r '.fields["System.WorkItemType"]' "$OUTPUT_FILE")

echo "----------------------------------------"
echo "Work Item: #$WORK_ITEM_ID"
echo "Type: $TYPE"
echo "Title: $TITLE"
echo "State: $STATE"
echo "----------------------------------------"
echo "Saved to: $OUTPUT_FILE"
