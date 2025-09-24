#!/usr/bin/env bash
set -euo pipefail

SPACE_ID="$1"
TOKEN="$2"
API="https://api.contentful.com"
BACKUP_FILE="rollback/roles-backup.json"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file $BACKUP_FILE not found! Cannot unlock."
  exit 1
fi

echo "Restoring roles from $BACKUP_FILE..."

cat "$BACKUP_FILE" | jq -c '.items[]' | while read -r role; do
  role_id=$(echo "$role" | jq -r '.sys.id')

  curl -s -X PUT "$API/spaces/$SPACE_ID/roles/$role_id" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/vnd.contentful.management.v1+json" \
      -d "$role" >/dev/null

  role_name=$(echo "$role" | jq -r '.name')
  echo "Restored $role_name ($role_id)"
done

echo "Unlock complete"
