# cert-manager (wrapper)

Wave -1. Installs upstream cert-manager plus a Namespace with Skylab labels.

Not yet included (follow-up PRs):

- ClusterIssuers (step-ca, ACME via Let's Encrypt) — wait for step-ca at wave 0
- `trust-manager` Bundle for CA trust distribution — wait for trust-manager at wave 0
- ExternalSecrets for ACME account secrets — wait for ESO ClusterSecretStores at wave 0

## Upstream

- Chart: `jetstack/cert-manager`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
