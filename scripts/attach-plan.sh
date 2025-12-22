#!/bin/bash
# attach-plan.sh
# Attaches an implementation plan file to an Azure DevOps work item
#
# Usage: ./attach-plan.sh <work-item-id> <plan-file-path> <access-token>

set -e

WORK_ITEM_ID="$1"
PLAN_FILE="$2"
ACCESS_TOKEN="$3"

# Defaults from environment or fallback
ORG="${AZURE_DEVOPS_ORG:-jasonpaffES}"
PROJECT="${AZURE_DEVOPS_PROJECT:-Head Shakers}"

# URL encode the project name
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

if [ -z "$WORK_ITEM_ID" ] || [ -z "$PLAN_FILE" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Usage: $0 <work-item-id> <plan-file-path> <access-token>"
  exit 1
fi

if [ ! -f "$PLAN_FILE" ]; then
  echo "Error: Plan file not found: $PLAN_FILE"
  exit 1
fi

echo "Attaching plan to work item #$WORK_ITEM_ID..."

# Generate filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="implementation-plan-${TIMESTAMP}.md"

# Step 1: Upload the attachment
echo "Uploading attachment..."
UPLOAD_URL="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/wit/attachments?fileName=$FILENAME&api-version=7.0"

UPLOAD_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$PLAN_FILE" \
  "$UPLOAD_URL")

# Extract attachment URL from response
ATTACHMENT_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.url')

if [ -z "$ATTACHMENT_URL" ] || [ "$ATTACHMENT_URL" == "null" ]; then
  echo "Error: Failed to upload attachment"
  echo "$UPLOAD_RESPONSE"
  exit 1
fi

echo "Attachment uploaded: $ATTACHMENT_URL"

# Step 2: Link attachment to work item
echo "Linking attachment to work item..."
LINK_URL="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/wit/workitems/$WORK_ITEM_ID?api-version=7.0"

LINK_PAYLOAD=$(cat <<EOF
[
  {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "AttachedFile",
      "url": "$ATTACHMENT_URL",
      "attributes": {
        "name": "$FILENAME",
        "comment": "AI-generated implementation plan"
      }
    }
  }
]
EOF
)

HTTP_STATUS=$(curl -s -w "%{http_code}" -o /tmp/link-response.json \
  -X PATCH \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json-patch+json" \
  -d "$LINK_PAYLOAD" \
  "$LINK_URL")

if [ "$HTTP_STATUS" != "200" ]; then
  echo "Error: Failed to link attachment to work item. HTTP Status: $HTTP_STATUS"
  cat /tmp/link-response.json
  exit 1
fi

echo "----------------------------------------"
echo "Plan attached successfully!"
echo "Work Item: #$WORK_ITEM_ID"
echo "Filename: $FILENAME"
echo "----------------------------------------"

# Step 3: Add a comment about the plan
echo "Adding comment to work item..."
COMMENT_URL="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/wit/workitems/$WORK_ITEM_ID/comments?api-version=7.0-preview.3"

# Generate simple summary from plan
PLAN_TITLE=$(grep -m1 '^# ' "$PLAN_FILE" | sed 's/^# //' || echo "Implementation Plan")
PHASE_COUNT=$(grep -c '^## ' "$PLAN_FILE" || echo "0")
FILE_COUNT=$(grep -oE '\b[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|css|sql|json)\b' "$PLAN_FILE" | sort -u | wc -l | tr -d ' ')

COMMENT_PAYLOAD=$(cat <<EOF
{
  "text": "📋 **Implementation Plan Generated**\n\nAn AI-generated implementation plan has been attached to this work item.\n\n**Summary:**\n- **Title:** ${PLAN_TITLE}\n- **Phases:** ${PHASE_COUNT}\n- **Files:** ~${FILE_COUNT}\n\n**Next Steps:**\n1. Review the attached plan\n2. If approved, move this item to 'AI Implement' status\n3. If changes needed, update the acceptance criteria and re-run planning"
}
EOF
)

curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$COMMENT_PAYLOAD" \
  "$COMMENT_URL" > /dev/null

echo "Comment added to work item"
