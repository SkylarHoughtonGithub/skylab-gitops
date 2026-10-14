# alloy (wrapper)

Wave 5. DaemonSet collector that ships pod logs to Loki. Replaces Promtail (EOL March 2026).

Metrics stay with kube-prometheus-stack's Prometheus scrapers; Alloy is purely for logs today, with traces + Kubernetes events to follow once Tempo and OTel-emitting workloads land.

## Config

The default River config in `alloy.alloy.configMap.content`:

- Discovers pods via the Kubernetes API.
- Relabels with `namespace`, `pod`, `container`, `node` and a static `cluster=$CLUSTER_NAME`.
- Writes to Loki at `$LOKI_URL` (default: `http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push`).

Per-cluster overlays override `LOKI_URL` (point at a gateway in scalable mode) and `CLUSTER_NAME` via `alloy.extraEnv`.

## Follow-ups

- Traces: add `otelcol.receiver.otlp` → `otelcol.exporter.otlphttp` → Tempo once Tempo lands.
- Kubernetes events: add `loki.source.kubernetes_events` once a dashboard needs them.
- Multi-cluster: use `cluster_name` + `cloud` labels (set per overlay) for fleet-wide Grafana queries.

## Upstream

- Chart: `grafana/alloy`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
