# kube-prometheus-stack (wrapper)

Wave 5. Installs the Prometheus Operator, Prometheus, Alertmanager, node-exporter, and kube-state-metrics in the `monitoring` namespace.

Grafana ships from the separate `grafana` wrapper at the same wave; the bundled sub-chart is disabled here to avoid two Grafanas on the cluster.

## Selectors

Prometheus and the Operator discover ServiceMonitors, PodMonitors, Probes, and PrometheusRules fleet-wide (all `*SelectorNilUsesHelmValues` flags set to `false`). Component wrappers (cert-manager, external-secrets, etc.) ship their own ServiceMonitors next to the workloads they monitor; no extra labels required.

## Storage

Prometheus uses a 50 Gi `ReadWriteOnce` PVC on the default StorageClass. Override `kube-prometheus-stack.prometheus.prometheusSpec.storageSpec` per cluster to resize or pin a `storageClassName`.

## Follow-ups

- Alertmanager routing + receivers config (post Grafana wave 5, co-landed with SLO rules).
- Scraping config for the step-ca metrics endpoint once that port is exposed.
- A `values-homelab.yaml` once cluster resource shape is known.

## Upstream

- Chart: `prometheus-community/kube-prometheus-stack`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
