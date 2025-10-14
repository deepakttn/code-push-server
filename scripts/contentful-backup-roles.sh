#!/usr/bin/env bash
set -euo pipefail

SPACE_ID="$1"
TOKEN="$2"
BACKUP_FILE="roles-backup.json"

echo "Fetching roles..."
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/vnd.contentful.management.v1+json" \
  "https://api.contentful.com/spaces/$SPACE_ID/roles" \
  | jq '.' > "$BACKUP_FILE"

echo "Roles backup saved to $BACKUP_FILE"
