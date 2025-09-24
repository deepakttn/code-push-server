#!/usr/bin/env bash
set -euo pipefail

SPACE_ID="$1"
TOKEN="$2"
MASTER_ALIAS="master"
BACKUP_FILE="roles-backup.json"

echo "Resolving current master environment behind alias '$MASTER_ALIAS'..."
MASTER_ENV=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.contentful.com/spaces/$SPACE_ID/environment_aliases/$MASTER_ALIAS" \
  | jq -r '.environment.sys.id')

echo "Current master env: $MASTER_ENV"

# Fetch all roles
echo "Fetching roles..."
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.contentful.com/spaces/$SPACE_ID/roles" \
  | jq '.' > "$BACKUP_FILE"

echo "Roles backup saved to $BACKUP_FILE"

# Iterate roles and patch them
cat "$BACKUP_FILE" | jq -c '.items[]' | while read role; do
  role_id=$(echo "$role" | jq -r '.sys.id')
  role_name=$(echo "$role" | jq -r '.name')

  # Skip Admin
  if [[ "$role_name" == "Admin" ]]; then
    echo "Skipping Admin role ($role_id)"
    continue
  fi

  echo "Processing role: $role_name ($role_id)"

  # Show policies before modification for this env
  echo "$role" | jq --arg env "$MASTER_ENV" '
    .policies[] 
    | select((.environments // []) | index($env)) 
    | {policy: ., note:"Before"}'

  # Update only policies that target this env
  updated_role=$(echo "$role" | jq \
    --arg env "$MASTER_ENV" '
    .policies |= map(
      if (.environments // [] | index($env)) and (.effect == "allow") then
        if (.actions | index("*") or index("write")) then
          .actions = ["read"]
        else
          .
        end
      else
        .
      end
    )')

  # Show policies after modification
  echo "$updated_role" | jq --arg env "$MASTER_ENV" '
    .policies[] 
    | select((.environments // []) | index($env)) 
    | {policy: ., note:"After"}'

  # PUT updated role
  curl -s -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$updated_role" \
    "https://api.contentful.com/spaces/$SPACE_ID/roles/$role_id" > /dev/null

  echo "Role $role_name updated (env $MASTER_ENV now read-only)."
done

echo "Master environment $MASTER_ENV locked (non-admin roles are read-only)."
