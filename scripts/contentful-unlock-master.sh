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

echo "Checking current environment behind alias 'master'..."
MASTER_ENV_ID=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.contentful.com/spaces/$SPACE_ID/environments/master" \
  | jq -r '.sys.id // "unknown"')

echo "Restoring roles to current master environment: $MASTER_ENV_ID "

cat "$BACKUP_FILE" | jq -c '.items[]' | while read -r role; do
  role_id=$(echo "$role" | jq -r '.sys.id')
  role_name=$(echo "$role" | jq -r '.name')
  role_version=$(echo "$role" | jq -r '.sys.version')

  echo "Restoring role: $role_name ($role_id, version $role_version)"
  
  response=$(curl -s -w "%{http_code}" -o /tmp/response.json -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/vnd.contentful.management.v1+json" \
    -H "x-contentful-version: $role_version" \
    -d "$role" \
    "https://api.contentful.com/spaces/$SPACE_ID/roles/$role_id")
  
  echo "Restored: $role_name"
done

echo "All roles restored successfully for environment: $MASTER_ENV_ID"
