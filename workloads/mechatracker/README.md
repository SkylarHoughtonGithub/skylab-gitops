# mechatracker

Wave 10. First workload riding the Skylab `go-service` ComponentDefinition — the second real app in the fleet after `demo-service`, and the reference workload for golden-path items #1 (Go service template) and #2 (database template).

| Capability          | What this touches                                                      |
| ------------------- | ---------------------------------------------------------------------- |
| KubeVela            | `go-service` ComponentDefinition renders Deployment + Service          |
| OTel                | `OTEL_EXPORTER_OTLP_ENDPOINT` injected to the in-cluster Alloy         |
| Probes              | `/healthz` liveness + readiness (baked into the ComponentDefinition)   |
| Backstage           | Entity page resolves kubernetes-id `mechatracker`; argocd + grafana    |
| Postgres            | Sibling `mechatracker-db` Application via the `postgres` ComponentDef  |

## Phase 2 cutover — the interim Postgres is gone

The interim `postgres:17-alpine` StatefulSet + static-cred Secret are retired. Postgres now lives in the sibling `workloads/mechatracker-db/` Application, which uses the Skylab `postgres` ComponentDefinition — the shape the Backstage database template emits. The api component here `envFrom`'s the derived `db-url` Secret written by the compose Job in that Application.

**This file does not run on dev k3d.** The compose Job in `mechatracker-db` only completes once Crossplane (wave 1) is running with real AWS or GCP provider credentials and the XPostgres XR actually provisions a database. Dev k3d has none of that, so the `db-url` Secret never materializes and the api pod stays in `CreateContainerConfigError`. Expected until an EC2/EKS or GKE cluster lights up wave 1.

## Interim decisions

- **DEV_AUTH_BYPASS=true.** Lets the pod come up without wiring a Google OAuth client ID + session signing key. The config validator rejects this flag outside `ENV=development`, so both land together in the api component's `env`.
- **Migrations run manually.** The distroless API image doesn't bundle `migrate`. For first boot, exec a one-off against the derived `db-url` Secret:
  ```sh
  kubectl -n mechatracker run migrate --rm -it --restart=Never \
    --image=migrate/migrate:v4.18.1 \
    --overrides='{"spec":{"containers":[{"name":"migrate","image":"migrate/migrate:v4.18.1","envFrom":[{"secretRef":{"name":"db-url"}}],"args":["-path=/migrations","-database=$(DATABASE_URL)","up"]}]}}'
  ```
  A proper migrate Job tied to the `postgres` ComponentDefinition is a follow-up.
- **Dev-only hardcoded password.** `workloads/mechatracker-db/application.yaml` currently sets `password: mechatracker-dev-only` inline. Replace with an ESO-backed Secret once ClusterSecretStores are wired.

## Replacing this

Everything here regenerates from the Backstage `go-service` template once skylab-backstage + Gitea come up. This hand-written baseline exists so the template has a validated shape to emit — if KubeVela expands this Application cleanly, the template's output will too.
