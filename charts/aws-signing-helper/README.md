# aws-signing-helper

Skylab wrapper for the AWS Roles Anywhere credential refresher. The chart ships a `CronJob` that presents an mTLS cert to Roles Anywhere every 10 minutes and writes the short-lived session credentials into `eso-aws-credentials` — the Secret `charts/external-secrets/templates/clustersecretstore-aws.yaml` reads.

Lands at sync wave `0` so the first write happens before wave 1's ESO AWS `ClusterSecretStore` starts pulling.

## Required inputs

Populate the three Roles Anywhere ARNs from Terraform's `stacks/roles-anywhere` outputs when enabling per cluster:

| values key | Terraform output |
| --- | --- |
| `rolesAnywhere.trustAnchorArn` | `trust_anchor_arn` |
| `rolesAnywhere.profileArn` | `external_secrets_profile_arn` |
| `rolesAnywhere.roleArn` | `external_secrets_role_arn` |
| `rolesAnywhere.region` | account region (`us-east-1` default) |

`certificate.commonName` must match the `Subject` condition on the external-secrets role's trust policy — Terraform's `external_secrets` module keys off this CN.

Pin a `awsSigningHelper.sha256` before enabling in prod. Blank skips the digest check, which the fetch init-container warns about loudly.

## Client cert

Two modes, controlled by `certificate.create`:

- **BYO Secret (default for live clusters)**: `certificate.create: false`. Pre-stage a `kubernetes.io/tls` Secret named `aws-signing-helper-client` in the chart's namespace with `tls.crt` + `tls.key`. The offline root CA produces these — see `skylab-terraform/scripts/skylab-ca.sh`.
- **cert-manager**: `certificate.create: true` plus a reachable `StepClusterIssuer` named `skylab-step`. The chart's `Certificate` requests the leaf from it; override `certificate.issuerRef` for a different issuer. Needs step-ca + step-issuer running.

## Prerequisites in-cluster

- A reachable `rolesanywhere.<region>.amazonaws.com` endpoint from the pod network.

## Enabling

A `values-homelab.yaml` overlay sits beside this file with the Terraform-output fields pre-stubbed and inline comments naming each `terraform output`. Fill in the three ARNs + the sha256 digest, then wire from the cluster file:

```yaml
# clusters/<name>.yaml
components:
  aws-signing-helper:
    enabled: true
    extraValueFiles: [values-homelab.yaml]
```

See `docs/runbooks/live-aws-standup.md` for the full cross-repo standup — Terraform apply → values seeding → ESO flip-on → Crossplane wave 1 → first XR provisioning.
