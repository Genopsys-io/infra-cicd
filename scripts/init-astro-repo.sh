#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: init-astro-repo.sh <owner/repo> [site-id] [--force]

Initializes an Astro repository with the shared Kubernetes PVC deployment.
The site ID defaults to the repository name and determines:
  /usr/share/nginx/html/<site-id>

Required local authentication:
  gh auth login
  gcloud auth login

Examples:
  ./scripts/init-astro-repo.sh Genopsys-io/astro-kannel kannel
  ./scripts/init-astro-repo.sh Genopsys-io/new-site
EOF
}

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  usage >&2
  exit 1
fi

repo="$1"
site_id="${2:-${repo##*/}}"
force="${3:-}"

if [ "$site_id" = "--force" ]; then
  force="$site_id"
  site_id="${repo##*/}"
fi

if [ -n "$force" ] && [ "$force" != "--force" ]; then
  usage >&2
  exit 1
fi

if ! [[ "$site_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "site-id must contain only lowercase letters, numbers and hyphens" >&2
  exit 1
fi

for command in gh gcloud base64; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required" >&2
    exit 1
  fi
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
template="$repo_root/templates/astro-k8s-pvc-deploy.yml"

secret_project="${ASTRO_CICD_SECRET_PROJECT:-www-genopsys}"
secret_name="${ASTRO_CICD_SECRET_NAME:-astro-cicd-github-variables}"
workflow_path=".github/workflows/deploy.yml"

gh repo view "$repo" --json nameWithOwner >/dev/null

if ! gh api "repos/$repo/contents/package.json" --silent >/dev/null 2>&1; then
  echo "$repo does not contain package.json" >&2
  exit 1
fi

if ! gh api "repos/$repo/contents/package-lock.json" --silent >/dev/null 2>&1; then
  echo "$repo does not contain package-lock.json; commit it before initializing CI/CD" >&2
  echo "The shared workflow installs dependencies with npm ci." >&2
  exit 1
fi

existing_sha="$(gh api "repos/$repo/contents/$workflow_path" --jq '.sha' 2>/dev/null || true)"
if [ -n "$existing_sha" ] && [ "$force" != "--force" ]; then
  echo "$repo already contains $workflow_path; use --force to replace it" >&2
  exit 1
fi

secret_payload="$(gcloud secrets versions access latest \
  --project="$secret_project" \
  --secret="$secret_name")"

required_vars=(
  K8S_NAMESPACE
  K8S_POD_LABEL
  K8S_CONTAINER
  RELEASES_TO_KEEP
  GKE_LOCATION
  GKE_CLUSTER_NAME
  GCP_SERVICE_ACCOUNT_EMAIL
  GCP_WORKLOAD_IDENTITY_PROVIDER
)

for variable in "${required_vars[@]}"; do
  value="$(printf '%s\n' "$secret_payload" | sed -n "s/^${variable}=//p")"
  if [ -z "$value" ]; then
    echo "Missing $variable in Secret Manager secret $secret_name" >&2
    exit 1
  fi
  gh variable set "$variable" --repo "$repo" --body "$value"
done
gh variable set ASTRO_SITE_ID --repo "$repo" --body "$site_id"

unset secret_payload value

content="$(base64 < "$template" | tr -d '\n')"
args=(
  --method PUT
  "repos/$repo/contents/$workflow_path"
  -f "message=ci: initialize Astro production deployment"
  -f "content=$content"
)
if [ -n "$existing_sha" ]; then
  args+=( -f "sha=$existing_sha" )
fi
gh api "${args[@]}" --silent

echo "Initialized $repo"
echo "Site ID: $site_id"
echo "Deploy root: /usr/share/nginx/html/$site_id"
echo "Workflow: $workflow_path"
echo "Next: open the repository Actions tab and run the workflow manually."