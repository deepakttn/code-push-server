# Contentful CI/CD Automation

This repository contains a GitHub Actions workflow that automates cloning Contentful environments, running schema migrations, applying content changes, and safely switching the `master` alias. It includes two helper scripts that **lock** and **unlock** the master environment by modifying space roles to make the environment read-only during the deployment window.

---

## What this workflow does

* Creates a new versioned environment (e.g. `master-v8`) by cloning the current environment pointed to by the `master` alias.
* Locks the `master` environment (makes non-admin roles read-only) to prevent concurrent writes during the merge/apply stage.
* Adds the newly created environment to the existing CDA (CDA token) key for checking the conflicts and changeset.
* Runs Contentful migration scripts against the new environment.
* Bundles a backup of the space roles (artifact) for later restoration.
* Creates and applies a changeset (using `contentful-merge`) from a chosen source environment into the target environment.
* Updates the `master` alias to point to the new environment and unlocks the `master` environment (restores roles from backup).

## Workflow Steps

```
Contentful CI/CD Workflow
 ├── Set SPACE_ID based on brand input
 ├── Fetch current master alias (find source env)
 ├── Determine next eligible env name
 ├── Check for existing env (abort if exists)
 ├── Delete oldest env if exceeded max_env_count
 ├── Create & clone new env from master
 ├── Lock master environment roles (run contentful-lock-master.sh)
 ├── Add new env to CDA key
 ├── Wait for new env to be ready
 ├── Run migration scripts
 ├── Upload roles-backup.json
 ├── Wait for MANUAL APPROVAL (Prod/Env Promotion)
 ├── Download roles-backup.json artifact
 ├── Fetch latest target environment (master-vN)
 ├── Ensure target env exists (fail if missing)
 ├── Create changeset & check for conflicts
 │    └── Abort if conflicts found
 ├── Apply changeset to env (if no conflicts)
 ├── Update master alias to latest target env
 └── Unlock master environment roles (run contentful-unlock-master.sh)
```

---

## Workflow inputs & secrets

**Workflow inputs (workflow_dispatch):**

* `brand` — choice that maps to a Contentful space (e.g. `Fitness First`, `Dev R&D`, etc.)
* `base_env_name` — prefix for new env names (default: `master`)
* `max_env_count` — maximum number of versioned environments to retain (default: `3`)
* `source_env` — source environment for merge (checking the conflicts and merge changeset)

**Secrets / environment variables used in the workflow:**

* `CONTENTFUL_TOKEN` — management API token (used to create/delete envs, update roles, update API keys)
* `CONTENTFUL_CDA_TOKEN` — Content Delivery API token (CDA key used by `contentful-merge`)
* `CONTENTFUL_SPACE_ID` / `_DEV_RD` / `_FITNESS_FIRST` / `_GOODLIFE_WEBSITE` / `_GYM_WEBSITE` / `_JETTS_NEW_ZEALAND` / `_ZAP_FITNESS` — space IDs per brand

Make sure those secrets are configured in the repository or organization secrets.

---

## High-level flow

1. `prepare-env` job (creates clone, locks master, runs migrations, uploads backup artifact).
2. `apply-changes` job (requires `prepare-env`; awaits environment `prod` approval), creates changeset, checks conflicts, applies changes, updates `master` alias, and always unlocks master using the saved backup.

> `apply-changes` runs in the `prod` GitHub environment which allows for a manual approval gate before the job runs.

---

## prepare-env job — step-by-step

1. **Checkout & Node setup** — standard setup using `actions/checkout` and `actions/setup-node`.
2. **Install Contentful CLI tools** — `contentful-cli`, `contentful-migration`, and `contentful-merge` are installed globally.
3. **Set `SPACE_ID` from `brand` input** — the workflow maps the selected brand to the appropriate secret and exports `SPACE_ID`.
4. **Manage and clone environments** (`manage_envs` step):

   * Read the `master` alias to determine which environment it currently points to (ex: `master-v7`).
   * Compute the next version (`master-v8`) by incrementing the trailing number.
   * Fetch all environments and ensure the next numbered environment does not already exist.
   * Optionally delete the oldest versioned environment if the count of environments exceeds `max_env_count`.
5. **Clone environment** — use `contentful space environment create` to clone `CURRENT_MASTER_ENV` -> `NEW_ENV`.
6. **Lock master environment** — execute `./scripts/contentful-lock-master.sh $SPACE_ID $CONTENTFUL_TOKEN`.
7. **Add new env to existing CDA key** — update the CDA key to include the new environment.
8. **Wait for new environment to be ready** — poll Contentful environment status until `ready`.
9. **Run migration scripts** — run `contentful-migration` against the new environment (script path: `choose the correct path`).
10. **Upload roles backup artifact** — save `roles-backup.json` as an artifact so the next job can restore roles.

---

## apply-changes job — step-by-step

1. **Approval gate** — runs under GitHub `environment: prod`, which typically pauses for manual approval.
2. **Download roles backup artifact** — obtains `roles-backup.json` produced by `prepare-env`.
3. **Set `SPACE_ID` again** — maps brand input to space ID just like `prepare-env`.
4. **Fetch latest target environment** — chooses the latest `master-vN` (by `createdAt`) as `TARGET_ENV`, or falls back to `master`.
5. **Ensure source environment exists** — quick guard that `TARGET_ENV` exists before continuing.
6. **Create changeset & check conflicts** — `contentful-merge create` builds a `changeset.json`. If the file contains conflicts, the job fails and prints conflict details.
7. **Apply changeset** — if there are no conflicts, `contentful-merge apply` is run to apply changes into `TARGET_ENV`.
8. **Update master alias** — point `master` alias to the `TARGET_ENV`.
9. **Unlock master environment** — always-run step that calls `./scripts/contentful-unlock-master.sh $SPACE_ID $CONTENTFUL_TOKEN` to restore roles.

---

## Lock script (`contentful-lock-master.sh`) — explanation

**Purpose:** Temporarily restrict non-admin roles so that the environment behind `master` becomes effectively **read-only** during migration/merge operations.

**Key points:**

* The script finds which environment the `master` alias currently points to (e.g. `master-v7`).
* It downloads a full backup of space roles to `roles-backup.json` (this file is uploaded as an artifact so the restore step can use it).
* For each role in the backup (skipping `Admin`):

  * The script checks role policies and targets either global policies (no `.environments`) or policies that explicitly include the current master environment.
  * If a policy `effect` is `allow` and the policy applies to the master environment (or is global), the script sets `.actions = ["read"]` for that policy — effectively removing create/write/delete actions for that environment.
  * The modified role object is sent back to Contentful via `PUT` to update the role. The script uses `x-contentful-version` header (from the role metadata) to avoid conflicts.
* The script logs both the *before* and *after* policy expressions to help debugging.

**Why this approach:** locking at the role/policy level is reversible (we keep a backup) and affects all actors using those roles without having to change content API keys or user accounts.

**Caveats & recommendations:**

* The script uses the version number from the backup when calling the `PUT`. If someone else modified roles in parallel, you may receive a 409 or non-200 response. In that case, fetch the role's current `sys.version` and retry the update.
* The script intentionally **does not** modify the `Admin` role.
* Keep `roles-backup.json` safe — it contains your full roles configuration and is used by the unlock step to restore state.

---

## Unlock script (`contentful-unlock-master.sh`) — explanation

**Purpose:** Restore space roles from the `roles-backup.json` file to return permissions to their previous state once the deployment is done.

**Key points:**

* The script requires `roles-backup.json` to exist (it is downloaded in the `apply-changes` job by `actions/download-artifact`).
* For each role in the backup:

  * The script reads `sys.id` and attempts to PUT the full stored role object back to Contentful.
  * Before PUTting, it fetches the current role version using GET and uses that `sys.version` in the `x-contentful-version` header to minimize version conflicts.
  * The script reports success or prints response body if the update failed.
* Once complete, the `master` environment will have the original policies and actions restored.

**Caveats & recommendations:**

* If a role change fails due to version mismatch, the script prints the server response — manual intervention may be required (fetch role, resolve conflicts, retry).
* If the artifact with `roles-backup.json` is missing, the unlock step will fail — ensure `prepare-env` uploaded the artifact and the `apply-changes` job downloads it successfully.

