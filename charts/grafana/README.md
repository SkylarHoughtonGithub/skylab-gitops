# grafana (wrapper)

Wave 5. Shares the `monitoring` namespace with kube-prometheus-stack. Pre-wires Prometheus as a default datasource. Loki and Tempo datasources ship from their own wrapper charts as labeled ConfigMaps picked up by Grafana's provisioning sidecar — no edits here needed when the backends land.

## Access

```sh
kubectl -n monitoring port-forward svc/grafana 3000:80
```

Default admin login is `admin` / `admin` (dev only). Production overlays point `admin.existingSecret` at an ExternalSecret-backed Secret and remove `grafana.adminPassword`.

## Follow-ups

- OIDC login (Dex or external IdP) once the identity layer is wired.
- Pre-ship a cluster-overview + SLO dashboard from this chart's values.
- Ingress with step-ca cert once the gateway choice is made.

## Upstream

- Chart: `grafana/grafana`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
