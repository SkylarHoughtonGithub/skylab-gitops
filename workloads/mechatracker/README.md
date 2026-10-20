# mechatracker

Wave 10. First workload riding the Skylab `go-service` ComponentDefinition — the second real app in the fleet after `demo-service`, and the reference workload for golden-path items #1 (Go service template) and #2 (database template).

| Capability          | What this touches                                                    |
| ------------------- | -------------------------------------------------------------------- |
| KubeVela            | `go-service` ComponentDefinition renders Deployment + Service        |
| OTel                | `OTEL_EXPORTER_OTLP_ENDPOINT` injected to the in-cluster Alloy       |
| Probes              | `/healthz` liveness + readiness (baked into the ComponentDefinition) |
| Backstage           | Entity page resolves kubernetes-id `mechatracker`; argocd + grafana  |

## Not running yet

This Application is a shape proof, not a running deployment. The `go-service` ComponentDefinition today only accepts `image` / `replicas` / `port` / `otelEndpoint` / `otelInsecure` parameters — it has no `env` or `envFrom` support. mechatracker needs `DATABASE_URL`, `SESSION_SIGNING_KEY`, and (`GOOGLE_CLIENT_ID` or `DEV_AUTH_BYPASS=true`) at startup; without them `config.validate()` fails and the pod `CrashLoopBackOff`s.

Three follow-up PRs make this actually run:

1. **`charts/kubevela-defs`**: extend `go-service` ComponentDefinition to accept `env: [...]` and `envFrom: [...]` parameters.
2. **Postgres in-cluster**: either a `postgres` XR via Crossplane (Phase 2) or a scaffolded StatefulSet while the XR waits for cloud credentials.
3. **mechatracker `web/`**: Clerk → Google OAuth migration lands separately in the mechatracker repo; once done, a second component block (frontend) joins this Application.

Until (1) lands, keeping `components.mechatracker.enabled: false` in `clusters/skylab-dev.yaml` is correct — turning it on now just produces a crashlooping pod.

## Replacing this

Everything here regenerates from the Backstage `go-service` template once skylab-backstage + Gitea come up. This hand-written baseline exists so the template has a validated shape to emit — if KubeVela expands this Application cleanly, the template's output will too.
