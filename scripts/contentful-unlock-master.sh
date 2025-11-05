# #!/usr/bin/env bash
# set -euo pipefail

# SPACE_ID="$1"
# TOKEN="$2"
# BACKUP_FILE="roles-backup.json"

# if [[ ! -f "$BACKUP_FILE" ]]; then
#   echo "Backup file $BACKUP_FILE not found. Cannot restore roles."
#   exit 1
# fi

# echo "Restoring roles from backup..."
# cat "$BACKUP_FILE" | jq -c '.items[]' | while read role; do
#   role_id=$(echo "$role" | jq -r '.sys.id')
#   role_name=$(echo "$role" | jq -r '.name')
#   echo "Restoring role: $role_name ($role_id)"
#   curl -s -X PUT \
#     -H "Authorization: Bearer $TOKEN" \
#     -H "Content-Type: application/json" \
#     -d "$role" \
#     "https://api.contentful.com/spaces/$SPACE_ID/roles/$role_id" > /dev/null
# done

# echo "Roles restored from backup."


#!/usr/bin/env bash
set -euo pipefail

SPACE_ID="$1"
TOKEN="$2"
BACKUP_FILE="roles-backup.json"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file $BACKUP_FILE not found. Cannot restore roles."
  exit 1
fi

echo "Checking which environment 'master' alias currently points to..."
MASTER_ENV_ID=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.contentful.com/spaces/$SPACE_ID/environments/master" \
  | jq -r '.sys.id // "unknown"')

echo "Current master alias points to: $MASTER_ENV_ID"
echo "Restoring roles at the space level (affects all environments, including $MASTER_ENV_ID)..."

cat "$BACKUP_FILE" | jq -c '.items[]' | while read -r role; do
  role_id=$(echo "$role" | jq -r '.sys.id')
  role_name=$(echo "$role" | jq -r '.name')

  echo "Restoring role: $role_name ($role_id)"

  # Fetch latest version number from Contentful before restoring
  current_version=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "https://api.contentful.com/spaces/$SPACE_ID/roles/$role_id" \
    | jq -r '.sys.version // 1')

  echo "Current version on Contentful: $current_version"

  http_status=$(curl -s -w "%{http_code}" -o /tmp/response.json -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/vnd.contentful.management.v1+json" \
    -H "x-contentful-version: $current_version" \
    -d "$role" \
    "https://api.contentful.com/spaces/$SPACE_ID/roles/$role_id")

  if [[ "$http_status" == "200" || "$http_status" == "201" ]]; then
    echo "Successfully restored: $role_name"
  else
    echo "Failed to restore $role_name (HTTP $http_status)"
    cat /tmp/response.json
  fi
done

echo "All roles restored successfully for space: $SPACE_ID (current master: $MASTER_ENV_ID)"

