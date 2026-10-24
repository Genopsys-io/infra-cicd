# infra-cicd

Reusable GitHub Actions workflows and bootstrap tooling for Genopsys-io
projects.

## Astro deployment

The reusable workflow
`.github/workflows/astro-k8s-pvc-reusable.yml` builds an Astro site, uploads
`dist/` to a versioned directory on the shared Kubernetes PVC and switches the
site's `current` symlink.

Each project receives the caller in
`templates/astro-k8s-pvc-deploy.yml`. It deploys on pushes to `main` and can
also be started manually.

## Initialize a new Astro repository

Developers do not exchange or create a `github-variables.env` file. Shared
values live in GCP Secret Manager under:

```text
project: www-genopsys
secret: astro-cicd-github-variables
```

The payload contains only shared deployment values. `DEPLOY_ROOT` is excluded:
it is derived in each caller from the repository variable `ASTRO_SITE_ID`.

### Prerequisites

- access to the target GitHub repository;
- permission to update GitHub Actions variables and workflows;
- Secret Manager accessor permission on the shared secret;
- authenticated `gh` and `gcloud` CLIs.
- a committed `package-lock.json`, because the shared workflow uses `npm ci`.

```bash
gh auth status
gcloud auth login
gcloud config set project www-genopsys
```

### Bootstrap command

The shortest path does not require cloning this repository:

```bash
gh api repos/Genopsys-io/infra-cicd/contents/scripts/init-astro-repo.sh \
   --jq '.content' | base64 --decode | \
   bash -s -- Genopsys-io/<repository> <site-id>
```

Alternatively, from a clone of this repository:

```bash
./scripts/init-astro-repo.sh Genopsys-io/<repository> <site-id>
```

Example:

```bash
./scripts/init-astro-repo.sh Genopsys-io/astro-kannel kannel
```

The command:

1. reads the common configuration directly from Secret Manager in memory;
2. creates the required GitHub Actions repository variables;
3. sets `ASTRO_SITE_ID` for the project;
4. imports `.github/workflows/deploy.yml` from the shared template;
5. never creates or transfers a local environment file.

The site ID defaults to the repository name when omitted. It must contain only
lowercase letters, numbers and hyphens. The resulting deployment path is:

```text
/usr/share/nginx/html/<site-id>/current
```

The command refuses to replace an existing workflow. Review it first, then use
`--force` when replacement is intentional:

```bash
./scripts/init-astro-repo.sh Genopsys-io/<repository> <site-id> --force
```

With the one-line form, append `--force` after `<site-id>`.

### Give the internal team access

Do not grant Secret Manager access to the whole Google Workspace domain. Use a
dedicated Google group and grant it access only to this secret:

```bash
gcloud secrets add-iam-policy-binding astro-cicd-github-variables \
   --project=www-genopsys \
   --member='group:developers@kannel.io' \
   --role='roles/secretmanager.secretAccessor'
```

Replace `developers@kannel.io` with the actual internal development group. The
group also needs permission to update Actions variables and workflow files in
the target GitHub repositories.

### Variables installed in the project

Shared variables from Secret Manager:

- `K8S_NAMESPACE`
- `K8S_POD_LABEL`
- `K8S_CONTAINER`
- `RELEASES_TO_KEEP`
- `GKE_LOCATION`
- `GKE_CLUSTER_NAME`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`

Project-specific variable:

- `ASTRO_SITE_ID`

There is intentionally no `DEPLOY_ROOT` repository variable.

## First deployment checklist

1. Confirm the Nginx vhost serves
   `/usr/share/nginx/html/<site-id>/current`.
2. Confirm the GitHub repository is allowed to call workflows from
   `Genopsys-io/infra-cicd`.
3. Run the deployment manually from the Actions tab.
4. Verify the homepage, sitemap, robots file and a known nested route.
5. Keep automatic deployment on `main` only after the first run succeeds.

## Secret maintenance

To rotate shared values, create a new secret version. Do not edit every project
manually; rerun the bootstrap command for each repository after rotation.

The expected payload format is one assignment per line:

```dotenv
K8S_NAMESPACE=...
K8S_POD_LABEL=...
K8S_CONTAINER=...
RELEASES_TO_KEEP=5
GKE_LOCATION=...
GKE_CLUSTER_NAME=...
GCP_SERVICE_ACCOUNT_EMAIL=...
GCP_WORKLOAD_IDENTITY_PROVIDER=...
```

## Versioning policy

- Major stable aliases: `v1`, `v2`.
- Immutable releases: `v2.0.0`, `v2.1.0`, and so on.
- Move `v2` only for backward-compatible changes.
