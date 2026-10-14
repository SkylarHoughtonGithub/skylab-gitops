# tempo (wrapper)

Wave 5. SingleBinary Tempo with filesystem storage for dev. Shares the `monitoring` namespace with kube-prometheus-stack, Grafana, Loki and Alloy.

## Grafana wiring

A labeled ConfigMap (`grafana_datasource=1`) ships the Tempo datasource definition with cross-datasource links:

- **tracesToLogsV2** → Loki, keyed on `cluster` + `namespace` + `pod`
- **tracesToMetrics** → Prometheus
- **serviceMap** → Prometheus

Grafana's provisioning sidecar picks it up fleet-wide. Metrics-to-traces-to-logs correlation is wired without edits elsewhere.

## OTLP

The chart's defaults open gRPC/4317 and HTTP/4318 OTLP receivers on the Tempo Service. Alloy forwards traces here in a follow-up PR once a workload emits spans.

## Follow-ups

- Scalable mode via `grafana/tempo-distributed` once prod storage lands (S3 + roles).
- Add `otelcol.receiver.otlp` + exporter to Alloy's River config when a workload actually emits traces.
- Service graph metrics via Tempo's metrics generator (needs Prometheus remote-write).

## Upstream

- Chart: `grafana/tempo` (SingleBinary variant)
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
