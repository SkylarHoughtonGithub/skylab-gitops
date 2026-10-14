# step-ca (wrapper)

Wave 0. Internal certificate authority. Root of trust for:

- Internal TLS (via cert-manager + step-issuer)
- IAM Roles Anywhere trust anchor (AWS, in `skylab-terraform/stacks/roles-anywhere`)
- GCP Workload Identity Federation for hub workloads (X.509 pool, in `skylab-terraform/stacks/gcp-identity`)

## Provisioner password

Default-off ExternalSecret pulls the admin provisioner password from a `ClusterSecretStore`. Enable per cluster once an ESO store is up:

```yaml
provisionerSecret:
  enabled: true
  remoteRef:
    key: skylab/step-ca/admin-provisioner-password
```

The resulting Secret is what `charts/cert-manager`'s `clusterIssuers.step.provisioner.passwordRef` points at by default. The ExternalSecret carries `argocd.argoproj.io/sync-wave: "2"` so Argo applies it after the ClusterSecretStore.

## Follow-ups

- CA signing key via ExternalSecret (once we commit to a signing-key rotation story).
- Trust bundle distribution via trust-manager — shipped in `charts/trust-manager` under `bundles.stepCA`.
- StepClusterIssuer — shipped in `charts/cert-manager` under `clusterIssuers.step`.

## Upstream

- Chart: `smallstep/step-certificates`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
