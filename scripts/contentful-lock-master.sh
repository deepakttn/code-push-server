#!/usr/bin/env bash
set -euo pipefail

SPACE_ID="${1:-}"
TOKEN="${2:-}"
API="https://api.contentful.com"
MASTER_ENV="master"

echo "Locking $MASTER_ENV environment..."

# Fetch all roles and save backup
backup_file="roles-backup.json"
curl -s -H "Authorization: Bearer $TOKEN" "$API/spaces/$SPACE_ID/roles" \
  > "$backup_file"
echo "Backup saved to $backup_file"

# Loop through roles and lock them
cat "$backup_file" | jq -c '.items[]' | while read -r role; do
  role_id=$(echo "$role" | jq -r '.sys.id')
  role_name=$(echo "$role" | jq -r '.name')

  # Skip admins
  if [[ "$role_name" =~ admin ]]; then
    echo "Skipping $role_name (admin)"
    continue
  fi

  # Override environments to allow only read on master
  body=$(jq -n \
    --arg name "$role_name" \
    --arg desc "Locked $MASTER_ENV version of $role_name" \
    --arg env "$MASTER_ENV" \
    '{
      name: $name,
      description: $desc,
      policies: [{ "effect":"allow", "actions":["read"] }],
      environments: { ($env): { "permissions":["read"] } }
    }')

  curl -s -X PUT "$API/spaces/$SPACE_ID/roles/$role_id" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/vnd.contentful.management.v1+json" \
      -d "$body" >/dev/null

  echo "Locked $role_name ($role_id) for $MASTER_ENV"
done
