# mechatracker

Wave 10. First workload riding the Skylab `go-service` ComponentDefinition — the second real app in the fleet after `demo-service`, and the reference workload for golden-path items #1 (Go service template) and #2 (database template).

| Capability          | What this touches                                                    |
| ------------------- | -------------------------------------------------------------------- |
| KubeVela            | `go-service` ComponentDefinition renders Deployment + Service        |
| OTel                | `OTEL_EXPORTER_OTLP_ENDPOINT` injected to the in-cluster Alloy       |
| Probes              | `/healthz` liveness + readiness (baked into the ComponentDefinition) |
| Backstage           | Entity page resolves kubernetes-id `mechatracker`; argocd + grafana  |
| Postgres (interim)  | Dev-only StatefulSet in the same Application; retires in Phase 2     |

## Interim decisions

The three gaps the first revision of this file called out are now closed with pragmatic shortcuts. These are all dev-only and get replaced before anything stateful ships:

- **Dev-only Postgres.** A plain `postgres:17-alpine` StatefulSet with a 10Gi PVC and static credentials in `mechatracker-postgres` Secret. The password is in Git — fine inside an isolated dev namespace, wrong anywhere else. Phase 2 (database golden-path template) replaces this block with a Crossplane `postgres` XR; at that point the Secret, StatefulSet, Service, and PVC all come out and the `api` component's `envFrom` points at the XR's connection secret.
- **DEV_AUTH_BYPASS=true.** Lets the pod come up without wiring a Google OAuth client ID + session signing key. The config validator rejects this flag outside `ENV=development`, so both land together in the api component's `env`.
- **Migrations run manually.** The distroless API image doesn't bundle `migrate`. For first boot, exec a one-off:
  ```sh
  kubectl -n mechatracker run migrate \
    --rm -it --restart=Never --image=migrate/migrate:v4.18.1 \
    -- -path=/migrations -database "$DATABASE_URL" up
  ```
  (The migrations themselves aren't on-cluster yet; Phase 2's database template adds a migrate Job.)

Once the Phase 2 database template lands, these three shortcuts all retire in one PR.

## Replacing this

Everything here regenerates from the Backstage `go-service` template once skylab-backstage + Gitea come up. This hand-written baseline exists so the template has a validated shape to emit — if KubeVela expands this Application cleanly, the template's output will too.
