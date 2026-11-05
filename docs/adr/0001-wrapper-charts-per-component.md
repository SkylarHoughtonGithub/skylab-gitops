# 0001. Wrapper chart per component instead of umbrella or kustomize

**Status:** Accepted
**Date:** 2026-11-05

## Context

Skylab deploys ~22 platform components to every cluster: Argo CD, cert-manager, External Secrets Operator, step-ca, trust-manager, Kyverno, Crossplane plus providers, KubeVela, Gitea, kube-prometheus-stack, Grafana, Loki, Alloy, Tempo, Sloth, Backstage, and more. Every component is an upstream Helm chart that also needs platform-specific wiring: a Namespace with a known label, ExternalSecrets, ClusterIssuers, trust-manager Bundles, custom RBAC bindings.

Three deployment models were on the table:

1. **One umbrella chart** that lists every upstream component as a subchart. One `helm install` per cluster.
2. **Kustomize overlays** with `helmCharts:` (or Argo CD's `--enable-helm`) that render upstream charts and patch them.
3. **One wrapper chart per component** that depends on the upstream chart and adds its own templates. One Argo CD Application per wrapper.

## Decision

**Adopt model 3.** Each `charts/<name>/Chart.yaml` lists the upstream chart as a dependency; the wrapper's `templates/` directory carries the platform-specific resources that upstream doesn't ship. Example shape:

```
charts/cert-manager/
├── Chart.yaml          # dependency: jetstack/cert-manager
├── values.yaml         # platform defaults for upstream + wrapper-specific toggles
├── values-homelab.yaml # per-env overrides
└── templates/
    ├── stepclusterissuer-bootstrap.yaml   # PostSync Job
    ├── clusterissuer-acme.yaml            # values-gated
    └── clusterissuer-step.yaml            # values-gated
```

Each wrapper is deployed as its own Argo CD Application, with its own sync wave, health, ignoreDifferences, and blast radius.

## Alternatives considered

**Umbrella chart.** Rejected because a single Helm release means a single health status: one failing component makes the whole release degraded, obscuring what actually broke. Upgrades touch every component at once, so a bad values bump anywhere is a bad values bump everywhere. Cross-subchart ordering is expressible only through `helm.sh/hook` annotations, which fight with Argo CD's own sync waves. Dependency graphs between subcharts (e.g. cert-manager must precede its ClusterIssuers) have no first-class representation.

**Kustomize with `helmCharts` or `--enable-helm`.** Rejected because it splits source of truth between kustomize overlay logic (patches, replacements) and Helm values. Argo CD renders Helm during sync, so the kustomize-renders-helm path requires either rendering kustomize client-side (committing generated YAML) or enabling Argo's helm integration (which doesn't compose well with multi-chart overlays). Helm's lifecycle hooks and chart versioning become second-class citizens next to kustomize's layering model.

## Consequences

**Positive.** Each component has independent health in the Argo UI, its own sync wave, its own `ignoreDifferences` rules, and its own set of wrapper-specific resources without cluttering a shared chart. `ct lint` enforces `Chart.yaml` version bumps per chart, so a cert-manager change is a cert-manager version bump and nothing more. OCI chart promotion (see [ADR-0004](0004-oci-chart-promotion.md)) operates at wrapper granularity, which is the right unit.

**Negative.** 22 `Chart.yaml` dependency entries to keep current. Renovate burden scales with chart count (though all 22 share one `renovate.json5` config). Patterns that recur across wrappers — the trust-manager Bundle source, the ClusterSecretStore template — get duplicated rather than centralized in a shared library chart.

**Neutral.** The wrapper model doesn't prevent a future shared library chart. If duplication becomes painful, a `charts/_lib/` dependency can be added without touching the per-wrapper model. The decision is about deployment units, not about template factoring.
