# 0002. Sync waves with a restored Application health check

**Status:** Accepted
**Date:** 2026-11-05

## Context

Platform components have strict ordering requirements that aren't expressible as pod-level readiness probes:

- cert-manager must be healthy before any ClusterIssuer CRD exists.
- ClusterIssuers must exist before cert-manager can serve Certificates.
- External Secrets Operator must be healthy before ClusterSecretStore CRDs can be created.
- Crossplane providers must be healthy before the `skylab-platform` Configuration package can install compositions.
- KubeVela must be healthy before ComponentDefinitions apply cleanly.
- Workloads must wait on all of the above.

With one Argo CD Application per wrapper chart ([ADR-0001](0001-wrapper-charts-per-component.md)), the delivery system needs a way to order those Applications.

Argo CD's **sync waves** are the native primitive: a `argocd.argoproj.io/sync-wave: "<N>"` annotation on a resource makes Argo apply all resources with the same N, wait for them to become healthy, then move to N+1. Lower N (including negatives) applies first.

But there's a catch. Argo CD 1.8 removed the built-in health check for `argoproj.io/Application` resources — a parent Application sees its child Applications as "always healthy" regardless of whether the child's own resources are healthy. Without a custom health check, waves of Applications apply but never actually wait on each other.

## Decision

**Use sync waves for ordering, with a custom Lua health check registered in `argocd-cm` that re-assesses `argoproj.io/Application` health.** `charts/skylab-apps/` emits one Application per enabled component carrying its wave annotation; the Argo CD installation ships the Lua hook so waves actually wait.

The wave assignment reflects the dependency graph:

| Wave | Why this wave |
| --- | --- |
| -2 | Argo CD (self-managed) — must exist before anything else can be an Application |
| -1 | cert-manager, ESO — CRDs other components consume |
| 0 | step-ca, step-issuer, trust-manager, ClusterSecretStores, Kyverno, aws-signing-helper — identity + policy layer |
| 1 | Crossplane and providers — infrastructure API |
| 2 | `skylab-crossplane` Configuration — compositions |
| 3 | KubeVela, kubevela-defs — application API |
| 4 | Gitea, act-runner — developer self-service |
| 5 | Alloy, Prometheus, Loki, Tempo, Grafana, Sloth — observability |
| 6 | Backstage — front door |
| 7 | Model gateway, HolmesGPT, kagent, MCP servers, tack-ai — AI layer |
| 10 | Workloads |

## Alternatives considered

**Multiple ApplicationSets with manual ordering.** Rejected because "the order in which ApplicationSets are applied" is not a first-class Argo concept — it's an artifact of when a human ran `kubectl apply`. Reproducibility suffers; a reinstall produces different behavior than the original bootstrap.

**Resource-level sync waves inside a single Application.** Rejected because it forces an umbrella chart ([ADR-0001](0001-wrapper-charts-per-component.md) already rejected that) and because resource-level waves can't express "wait until this whole subsystem is healthy" — they only express "apply this before that."

**Argo CD's `dependsOn` field on Applications.** Rejected because it's not a built-in Argo CD feature; several third-party projects simulate it, but none is stable enough to adopt. Sync waves solve the same problem with a core primitive.

## Consequences

**Positive.** Single source of truth for ordering (the annotation on each rendered Application), visible in the Argo UI as the wave progresses. First-time bootstrap is deterministic: a fresh cluster brings up Argo CD, then `-1`, then `0`, and so on. Components can be moved between waves by changing a single value in `charts/skylab-apps/values.yaml` — no re-structuring, no new ApplicationSets.

**Negative.** The Lua health hook lives in `argocd-cm` as external configuration — if Argo CD changes its internal health-check plumbing again (as happened at 1.8), the hook needs re-verification. Wave boundaries are coarse integers rather than DAG edges, so unrelated components in the same wave install in parallel; a dependency between two same-wave components must be solved at wave-assignment time, not expressed in the graph.

**Neutral.** Wave numbers are not contiguous (we use -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 10). The gap between 7 and 10 leaves room for additional platform tiers (e.g. an ingress layer) without renumbering workloads. The gap is a convention, not a constraint.
