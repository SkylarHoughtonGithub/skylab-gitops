# cert-manager (wrapper)

Wave -1. Installs upstream cert-manager, a Namespace with Skylab labels, and (when enabled) ClusterIssuers for step-ca and ACME.

## ClusterIssuers

Both are default-off; the Application sits at wave -1 but each ClusterIssuer carries `argocd.argoproj.io/sync-wave: "1"` so Argo applies them only after step-ca and step-issuer are healthy.

### `clusterIssuers.step`

StepClusterIssuer that cert-manager uses to request certs from step-ca via step-issuer. Needs:

- step-ca reachable at `url` (defaults to the in-cluster Service).
- A JWK provisioner's KID (`step ca provisioner list` on the running CA).
- The provisioner password available as a Secret — see `charts/step-ca` `provisionerSecret`.

### `clusterIssuers.acme`

Standard cert-manager ClusterIssuer backed by ACME (Let's Encrypt by default). Caller supplies `email` and at least one solver (DNS01 or HTTP01).

## Upstream

- Chart: `jetstack/cert-manager`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
