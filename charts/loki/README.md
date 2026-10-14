# loki (wrapper)

Wave 5. Shares the `monitoring` namespace with kube-prometheus-stack and Grafana. Monolithic (SingleBinary) with filesystem persistence in dev; production overlays switch to `SimpleScalable` + S3 once `skylab-terraform` publishes bucket + Roles Anywhere ARNs via the terraform-outputs contract.

## Grafana wiring

A labeled ConfigMap (`grafana_datasource=1`) ships the Loki datasource definition. Grafana's provisioning sidecar discovers it fleet-wide — no edits in `charts/grafana` needed.

## Push endpoint

`http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push`

Alloy (DaemonSet) is the default sender; see `charts/alloy`.

## Follow-ups

- S3-backed storage via a `values-<cluster>.yaml` overlay that overrides `loki.deploymentMode`, `loki.loki.storage`, and the replica counts for `backend`/`read`/`write`.
- Retention tuning per environment (dev stays at 72h to keep PVC size predictable).
- Alloy integration — see `charts/alloy`.

## Upstream

- Chart: `grafana/loki`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
