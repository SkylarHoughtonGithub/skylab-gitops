# step-ca (wrapper)

Wave 0. Internal certificate authority. Root of trust for:

- Internal TLS (via cert-manager + step-issuer)
- IAM Roles Anywhere trust anchor (AWS, in `skylab-terraform`)
- GCP Workload Identity Federation for hub workloads (X.509 pool)

## Not yet included

- Provisioner passwords + CA signing key via ExternalSecret — wait for ClusterSecretStores to be wired.
- StepClusterIssuer that cert-manager uses to request certs from this CA — follow-up once step-ca is reachable.
- Trust bundle distribution via trust-manager — follow-up.

## Upstream

- Chart: `smallstep/step-certificates`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
