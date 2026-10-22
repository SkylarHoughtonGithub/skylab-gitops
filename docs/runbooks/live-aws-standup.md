# Live AWS standup

End-to-end checklist for bringing live AWS resources online for the first time. Covers Terraform apply, gitops values wiring, Crossplane wave flip-on, and the first XR provisioning.

Everything platform-side is scaffolded and merged — this is the external unblock. The default state of the repo is "charts and XRDs pinned, default-off, waiting on cloud identity." This runbook walks it on.

## Prerequisites

- An AWS account you own, with admin credentials for the one-time bootstrap.
- A **running step-ca** whose root cert you can export. Dev k3d's step-ca works for a one-shot proof, but every k3d destroy regenerates the root and invalidates the Roles Anywhere trust anchor. For anything persistent, run step-ca in a cluster with a PVC-backed root.
- Terraform installed locally, AWS creds configured.
- `kubectl` pointed at the cluster.

## 1. Terraform — bootstrap + Roles Anywhere

```sh
cd skylab-terraform

# One-time: OIDC trust + IAM roles for GH Actions.
( cd stacks/bootstrap && terraform init && terraform apply )
( cd stacks/identity  && terraform init && terraform apply )

# Export step-ca's root from the running cluster — Roles Anywhere's
# trust anchor. The root is published in the step-certificates
# `-certs` ConfigMap by the init Job.
kubectl -n step-ca get configmap step-ca-step-certificates-certs \
  -o jsonpath='{.data.root_ca\.crt}' > /tmp/step-ca-root.pem

# Register the root + create one profile+role per workload.
cd stacks/roles-anywhere
terraform init
terraform apply -var "step_ca_root_pem=$(cat /tmp/step-ca-root.pem)"

# Capture outputs. You'll paste three ARNs into gitops next.
terraform output
```

Keep `terraform output` open. You need:

| Terraform output | Lands in gitops at |
| --- | --- |
| `trust_anchor_arn` | `charts/aws-signing-helper/values-homelab.yaml` |
| `external_secrets_profile_arn` | same file |
| `external_secrets_role_arn` | same file |
| `crossplane_aws_profile_arn` | `charts/crossplane-providers` (follow-up) |
| `crossplane_aws_role_arn` | same |

## 2. gitops — seed values + flip on ESO + refresher

`charts/aws-signing-helper/values-homelab.yaml` ships with blank fields and inline Terraform-output comments. Fill in the three ARNs + the sha256 digest for `aws_signing_helper` 1.5.0 (grab from the release page).

Then in your cluster values file:

```yaml
# clusters/<name>.yaml
components:
  external-secrets:
    enabled: true
  aws-signing-helper:
    enabled: true
    extraValueFiles: [values-homelab.yaml]

external-secrets:
  clusterSecretStores:
    aws:
      enabled: true
```

Open a PR, merge, watch Argo CD. The CronJob fires every 10 minutes. Verify:

```sh
# Within 10 min of enable:
kubectl -n external-secrets get secret eso-aws-credentials -o json \
  | jq '.data | keys'
# → ["access_key_id","secret_access_key","session_token"]

kubectl get clustersecretstore aws-secrets-manager -o yaml | yq .status
# → ready
```

## 3. Seed a VPC + DB subnet group for Postgres

Two realistic paths:

- **Fast path (manual, for proof).** Create a VPC + two private subnets + a DB subnet group + a security group allowing 5432 from the cluster CIDR via the AWS console or a one-off Terraform snippet. Paste the DB subnet group name + SG ID into `workloads/mechatracker-db/application.yaml`'s `REPLACE-ME` fields. Open a PR.
- **Proper path.** Apply Crossplane's `Network` XR (`v0.2.0`, public-VPC) once wave 1 is up. Chicken-and-egg though — Crossplane needs the AWS credentials ESO provides, so the manual path is quicker for the first run. Migrate to the XR afterwards.

## 4. Flip on wave 1 (Crossplane) + wave 2 (Configuration package)

```yaml
# clusters/<name>.yaml
components:
  crossplane:
    enabled: true
  crossplane-providers:
    enabled: true
  skylab-crossplane:
    enabled: true
```

provider-aws needs the `crossplane_aws_*` Roles Anywhere outputs — follows the same values pattern as `aws-signing-helper`. Check `charts/crossplane-providers/values.yaml` for the exact field names.

## 5. Validate the full chain

```sh
# XR materializes in-cluster:
kubectl get xpostgres -A

# AWS Managed Resource composed by the XR:
kubectl get instance.rds.aws.upbound.io -A

# compose Job completes; db-url Secret written:
kubectl -n mechatracker get secret db-url -o json | jq '.data | keys'
# → ["DATABASE_URL"]

# api pod turns green:
kubectl -n mechatracker get pod -l app=mechatracker-api
kubectl -n mechatracker logs deploy/mechatracker-api | head -20
```

## Likely trip-ups

- **step-ca root rotation.** Rebuilding dev k3d regenerates the step-ca root; the trust anchor registered in AWS no longer matches and every Roles Anywhere auth fails. Either run step-ca somewhere persistent, or re-apply `stacks/roles-anywhere` with the new PEM.
- **Trust-policy Subject CN mismatch.** The chart defaults `certificate.commonName: aws-signing-helper`. Terraform's `external_secrets` module keys off this. If you've overridden either side, align them.
- **sha256 pin skipped.** Don't ship `awsSigningHelper.sha256: ""` to a flipped-on cluster. The chart warns loudly but doesn't block.
- **ESO before refresher.** If ESO's AWS ClusterSecretStore comes up before the first CronJob run completes, it logs auth errors for 1 cycle. Harmless — it retries. Just know the first ~10 min after flip-on isn't "clean."

## What this doesn't cover

- GCP side (`stacks/gcp-identity`, GKE, GCP Secret Manager). Mirror this runbook once the AWS leg is proven.
- `stacks/storage` buckets for Loki / Tempo / TechDocs. Needed before remote-writing observability data; local filesystem backends work meanwhile.
- `stacks/qdevice` — Proxmox-specific, orthogonal.
- Backstage env vars (OIDC/K8s/Argo/Grafana). Separate wiring, not blocked by Roles Anywhere.
