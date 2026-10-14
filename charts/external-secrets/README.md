# external-secrets (wrapper)

Wave -1. Installs the External Secrets Operator, a Namespace with Skylab labels, and (when enabled) ClusterSecretStores for AWS Secrets Manager and GCP Secret Manager.

## ClusterSecretStores

Both are default-off; the Application sits at wave -1 but each CSS carries `argocd.argoproj.io/sync-wave: "1"` so Argo applies them after step-ca / step-issuer / the credential helper are in place.

### `clusterSecretStores.aws`

AWS Secrets Manager, authenticated via a credentials Secret. ESO has no first-class Roles Anywhere auth, so a credential refresher (`aws_signing_helper` or equivalent) must run out of band:

- Mount a cert-manager Certificate from `StepClusterIssuer` with `commonName` matching the `allowed_subject_cns` on the role in `skylab-terraform/stacks/roles-anywhere`.
- Point `aws_signing_helper` at the profile + role ARNs from that stack.
- Write the resulting creds into `eso-aws-credentials` (keys default to `access_key_id`, `secret_access_key`, `session_token`).

### `clusterSecretStores.gcp`

GCP Secret Manager, authenticated via Workload Identity. For the hub (step-ca X.509 WIF pool, output `hub_wif_pool_name` in `skylab-terraform/stacks/gcp-identity`) or for GKE spokes.

## Follow-ups

- ServiceMonitor — wait for kube-prometheus-stack at wave 5.
- Ship the AWS credential refresher as a first-class component once a chosen implementation is pinned.

## Upstream

- Chart: `external-secrets/external-secrets`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
