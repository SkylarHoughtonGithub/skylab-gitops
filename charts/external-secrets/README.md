# external-secrets (wrapper)

Wave -1. Installs the External Secrets Operator plus a Namespace with Skylab labels.

Not yet included (follow-up PRs):

- ClusterSecretStores for AWS Secrets Manager and GCP Secret Manager — wait for cloud identity (Roles Anywhere + GCP WIF) at wave 0
- ServiceMonitor — wait for kube-prometheus-stack at wave 5

## Upstream

- Chart: `external-secrets/external-secrets`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
