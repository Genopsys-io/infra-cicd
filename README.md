# infra-cicd

Reusable GitHub Actions workflows for Genopsys-io projects.

## Available workflows

- [.github/workflows/astro-k8s-pvc-reusable.yml](.github/workflows/astro-k8s-pvc-reusable.yml)

## Usage from an Astro project

Create a caller workflow in your project:

```yaml
name: Deploy Astro via Infra Reusable Workflow

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    uses: Genopsys-io/infra-cicd/.github/workflows/astro-k8s-pvc-reusable.yml@v1
    with:
      node_version: "22"
      build_dir: dist
      k8s_namespace: ${{ vars.K8S_NAMESPACE }}
      k8s_pod_label: ${{ vars.K8S_POD_LABEL }}
      k8s_container: ${{ vars.K8S_CONTAINER }}
      deploy_root: ${{ vars.DEPLOY_ROOT }}
      healthcheck_url: ${{ vars.HEALTHCHECK_URL }}
      releases_to_keep: ${{ vars.RELEASES_TO_KEEP || '5' }}
    secrets:
      kube_config_data: ${{ secrets.KUBE_CONFIG_DATA }}
```

## Required variables and secret in each project repository

Variables:

- K8S_NAMESPACE
- K8S_POD_LABEL
- K8S_CONTAINER
- DEPLOY_ROOT
- HEALTHCHECK_URL
- RELEASES_TO_KEEP (optional, default: 5)

Secret:

- KUBE_CONFIG_DATA (base64 kubeconfig)

## Versioning policy

- Tag major stable aliases: v1, v2
- Tag immutable releases: v1.0.0, v1.1.0
- Update v1 tag only for backward-compatible changes
