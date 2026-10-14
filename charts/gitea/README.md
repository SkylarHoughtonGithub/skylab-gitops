# gitea (wrapper)

Wave 4. Installs Gitea on the hub with a bundled Postgres and Redis on PVCs. This is where scaffolder output (`platform/tenants`) and tenant repos live; a second `skylab-apps` ApplicationSet watches that Gitea org for KubeVela Applications.

## State

Operator-only. The following are intentionally deferred and will each land as values-gated opt-ins or follow-up PRs:

- **OIDC provider** — Gitea backs Backstage, Argo CD and Grafana SSO. Config lands with the Backstage work in `skylab-backstage`.
- **Ingress + step-ca TLS cert** — a Gateway API `HTTPRoute` with a cert-manager Certificate issued via `StepClusterIssuer`. Blocked on wave-0 wiring being flipped on at the cluster level and on choosing a Gateway implementation.
- **Admin credentials via ExternalSecret** — admin password and OAuth client secret pulled from the ESO AWS SM / GCP SM store. Blocked on wave-0 wiring and on populating the remote secret.
- **ServiceMonitor** — enabled in wave 5 once kube-prometheus-stack is up.
- **Crossplane-managed Postgres** — swap the bundled Postgres for a Cloud SQL / RDS instance via the `postgres` XR once `skylab-crossplane` ships.

## Upstream

- Chart: `gitea/gitea`
- Pinned via `Chart.yaml` `dependencies`; refresh with `helm dependency update` locally and in CI before `ct lint`.
