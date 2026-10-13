# crossplane-providers

Wave 1. Installs the Crossplane Provider CRs for Skylab.

| Family | Sub-providers | Why |
| --- | --- | --- |
| AWS | ec2, eks, iam, s3, rds | VPCs, EKS, IAM, S3 buckets, RDS Postgres |
| GCP | compute, container, storage, sql | VPCs, GKE, Cloud Storage, Cloud SQL |
| Kubernetes | provider-kubernetes | Writes the Argo CD cluster Secret during cluster handoff |

Only the sub-providers Skylab's XRDs reference are installed, to keep CRD count and memory down.

## Config

ProviderConfigs (credentials wiring) are not in this chart — they land in a follow-up once cloud identity exists in `skylab-terraform` (IAM Roles Anywhere for AWS, Workload Identity Federation for GCP).

## Bumping

Edit `providers[*].package` in `values.yaml` and bump the chart `version` in `Chart.yaml`.
