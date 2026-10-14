# sloth (wrapper)

Wave 5. Picked over Pyrra because Sloth ships an official helm chart (`sloth/sloth`) and Pyrra doesn't — tradeoff is losing Pyrra's UI; SLO visibility comes from the generated PrometheusRules + Grafana dashboards. See `plan.md` decision table.

## Model

Workload wrappers (or Backstage-scaffolded tenant repos) create `PrometheusServiceLevel` CRs. Sloth watches them cluster-wide and emits burn-rate `PrometheusRule` objects (14d SLO window with multi-window multi-burn-rate alerts by default). Prometheus (from kube-prometheus-stack) picks them up through the fleet-wide ruleSelector.

Every generated rule carries `skylab.io/generated-by: sloth` so Grafana / Alertmanager can filter on it.

## No SLOs yet

The controller is deployed but there are no `PrometheusServiceLevel` CRs in the repo yet. First SLO lands with the first golden-path workload in `skylab-backstage`.

## Follow-ups

- Alertmanager routing for Sloth-generated alerts (ntfy / Discord / HolmesGPT).
- A Grafana dashboard JSON for burn-rate + error-budget views (shipped as a `grafana_dashboard=1` ConfigMap from this chart).

## Upstream

- Chart: `sloth/sloth`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
