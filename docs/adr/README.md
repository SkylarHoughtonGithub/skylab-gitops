# Architecture Decision Records

Decisions that shape how this repo is laid out, deployed, and operated. Each ADR captures a decision at a moment in time — the context that forced the choice, what was picked, what was rejected, and what we gave up in the process.

Format follows [Michael Nygard's template](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions): Status / Context / Decision / Alternatives / Consequences. ADRs are immutable once Accepted; a later ADR supersedes an earlier one by title and link rather than editing the original.

## Index

| # | Title | Status |
| --- | --- | --- |
| [0001](0001-wrapper-charts-per-component.md) | Wrapper chart per component instead of umbrella or kustomize | Accepted |
| [0002](0002-sync-waves-with-application-health-check.md) | Sync waves with a restored Application health check | Accepted |
| [0003](0003-cluster-as-data.md) | Cluster-as-data instead of path-based environments | Accepted |
| [0004](0004-oci-chart-promotion.md) | Promotion by OCI chart version | Accepted |
| [0005](0005-layer-ownership.md) | Layer ownership: Argo CD, Crossplane, KubeVela | Accepted |
| [0006](0006-hub-and-spoke-fleet.md) | Hub-and-spoke fleet with cloud-agnostic APIs | Accepted |
| [0007](0007-one-gitops-repo-platform-vs-tenants.md) | One GitOps repo on GitHub; tenants live on Gitea | Accepted |
| [0008](0008-label-placement-now-ocm-later.md) | Label placement now, Open Cluster Management later | Accepted |

## Scope

This index covers decisions whose implementation lives in `skylab-gitops`. Sibling repos own their own ADRs:

- [`skylab-terraform`](https://github.com/SkylarHoughtonGithub/skylab-terraform) — Roles Anywhere trust anchor, step-ca federation into AWS + GCP identity
- [`skylab-crossplane`](https://github.com/SkylarHoughtonGithub/skylab-crossplane) — Crossplane hands clusters to Argo CD rather than deploying Helm releases
- [`skylab-backstage`](https://github.com/SkylarHoughtonGithub/skylab-backstage) — Discovery + generated Locations instead of manual catalog registration
