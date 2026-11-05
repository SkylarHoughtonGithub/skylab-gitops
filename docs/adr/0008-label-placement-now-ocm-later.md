# 0008. Label placement now, Open Cluster Management later

**Status:** Accepted
**Date:** 2026-11-05

## Context

Tenant applications need to land on the right clusters. "Right" depends on the app: a prod app wants a prod cluster; a GPU-dependent app wants a GPU-having cluster; an AWS-tied integration wants AWS. The fleet starts small (one homelab) and will grow (EKS + GKE spokes created on demand per [ADR-0006](0006-hub-and-spoke-fleet.md)), so the placement model needs to work at 1 cluster and still work at 10.

Two placement models in the Argo CD / multi-cluster ecosystem:

1. **Labels on Argo CD cluster Secrets, matched by an ApplicationSet cluster generator.** Zero new control plane. Match is `key=value` set membership. No scoring, no scheduling, no capacity awareness.

2. **Open Cluster Management (OCM).** Each cluster is a `ManagedCluster` CR; placement is expressed as a `Placement` CR with selectors, tolerations, scoring. Argo CD consumes the result via the Cluster Decision Resource generator. Real multi-cluster scheduling: capacity-aware, affinity/anti-affinity, pluggable scorers.

## Decision

**Start with labels. Adopt OCM once three or more spokes exist.**

Today, each tenant application carries a placement file (`env: prod`, `cloud: any`, `role: workload`). The tenants ApplicationSet ([ADR-0007](0007-one-gitops-repo-platform-vs-tenants.md)) is a matrix of a git-files generator (over placement files in `platform/tenants`) and a cluster generator whose selector consumes those labels. Clusters self-describe via labels on their Argo CD cluster Secret ([ADR-0003](0003-cluster-as-data.md)): `cloud`, `region`, `env`, `role`.

When the fleet reaches three or more spokes, migrate to OCM: register each cluster as a `ManagedCluster`, write `Placement` CRs per app, and switch the tenants ApplicationSet from the cluster generator to the Cluster Decision Resource generator. Tenant application specs don't change — only the selector-matching layer changes underneath.

## Alternatives considered

**OCM from day one.** Rejected because OCM is not free operationally: a hub-side control plane, cluster registration flows, placement authoring to learn. At one cluster, the overhead buys nothing — there's nothing to schedule. The complexity is justified only when the number of candidate clusters for any given app exceeds one.

**Manual placement — per-cluster ApplicationSets.** Rejected because it folds the placement decision into the Git structure (one ApplicationSet per cluster, listing the apps it should run). It works at any scale but makes promotion a two-file edit (add to new cluster's set, remove from old cluster's set) and removes the opportunity for policy-driven placement later.

**Round-robin / random distribution.** Not a real alternative for a production platform, but worth noting: without scoring, random placement would eventually land an AWS-tied app on a GCP cluster. Labels prevent that even without full scheduling.

## Consequences

**Positive.** Zero new infrastructure. Placement is expressible in two readable files per tenant (the placement.yaml and the cluster's Secret labels). A new cluster joins the fleet by applying a labeled Secret — no OCM registration. Fleet-wide placement policy (e.g. "all `env: prod` apps go to `env: prod` clusters") is a selector in one file.

**Negative.** No scoring. Multiple matching clusters mean Argo picks all of them — a tenant Application with `env: prod` and three prod clusters deploys three times. If that's not wanted, the tenant must narrow the match further. No capacity awareness: a saturated cluster still matches. No automatic rebalancing on cluster loss.

**Neutral.** The migration path is incremental. OCM can be introduced in stages: first install the hub components and register ManagedClusters while leaving the tenants ApplicationSet unchanged (for observability); then migrate placement one app at a time by switching its generator. No forced big-bang cutover. The decision records *when* to migrate (≥3 spokes) rather than committing to a date — the trigger is fleet shape, not calendar.
