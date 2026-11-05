# 0006. Hub-and-spoke fleet with cloud-agnostic APIs

**Status:** Accepted
**Date:** 2026-11-05

## Context

Skylab is a multi-cluster platform: one homelab cluster for the management plane and an open-ended number of workload clusters on AWS (EKS) and GCP (GKE). The platform's goal is that a developer asks for a cluster, a database, or a bucket — and which cloud, which cluster, which credentials is a platform decision, not a developer decision.

Two dimensions to choose:

**Topology:**
1. **Full mesh.** Every cluster peers with every other; each cluster can target any other cluster.
2. **Hub-and-spoke.** One management cluster deploys to many; spokes never deploy back.
3. **Independent clusters.** Each cluster manages itself; no central control plane.

**API surface:**
1. **Cloud-native APIs.** Developer requests go to AWS or GCP directly (CloudFormation, Terraform per cloud).
2. **Cloud-agnostic APIs.** Developer requests go to a Kubernetes-native XRD (`KubernetesCluster`, `Postgres`, `Bucket`) that the platform composes into one cloud or the other.

## Decision

**Hub-and-spoke topology with cloud-agnostic APIs.**

**Hub** (homelab cluster) runs the management plane:
- Argo CD — delivery to itself and every spoke
- Crossplane — AWS, GCP, Kubernetes providers
- Backstage — front door
- Gitea — tenant Git, act-runner CI
- Observability backends — Prometheus, Loki, Tempo, Grafana, Alertmanager
- AI layer — model gateway, HolmesGPT, kagent, tack-ai

**Spokes** (EKS, GKE, optional second homelab) run workloads plus a lean profile: Alloy, External Secrets Operator, cert-manager, KubeVela, Kyverno. Each spoke is created on demand via the [`skylab-crossplane`](https://github.com/SkylarHoughtonGithub/skylab-crossplane) `KubernetesCluster` XRD; the composition writes an Argo CD cluster Secret on the hub so the new cluster is adopted automatically ([ADR-0003](0003-cluster-as-data.md)).

**APIs are cloud-agnostic.** The same XRD (`KubernetesCluster`, `Postgres`, `Bucket`, `Network`) has both AWS and GCP compositions. A developer's `Postgres` claim becomes RDS on AWS or Cloud SQL on GCP based on the composition selector — no app change.

## Alternatives considered

**Full mesh.** Rejected because N-to-N connectivity grows quadratically, each cluster needs enough RBAC to deploy to every other cluster, and there's no single "pane of glass" — every cluster is its own Argo CD, its own Grafana, its own catalog. Operational cost grows with cluster count; portfolio value does not.

**Independent clusters.** Rejected because it defeats the point of a platform: each cluster would be hand-maintained, promotion between dev and prod would be manual, and fleet-wide policy changes would require touching every cluster. The homelab-only prototype would work, but nothing beyond.

**Cloud-native APIs.** Rejected because it forces the developer to make the cloud choice. Portfolio value here is proving that a workload moves between AWS and GCP by changing a placement label — that story requires the cloud-agnostic layer.

## Consequences

**Positive.** One Argo CD to inspect, one Backstage catalog, one Grafana to see every cluster. Fleet-wide policy (Kyverno rules, Renovate PRs, OCI version bumps) lands everywhere through one path. Spokes stay cheap: a lean profile is ~5 charts. Cluster lifecycle is Git-driven — the XR lives in a tenant repo; delete the XR and Crossplane tears the cluster down.

**Negative.** The hub is a single point of failure for the control plane. If the hub Argo CD is down, no new deployments reach any spoke; spokes keep running what they already have. Hub-to-spoke networking must be solved: the spoke API server either accepts authorized public endpoints or is reached through a Tailscale operator connection. Both have operational cost.

**Neutral.** Cross-cluster service traffic (east-west) is **not** governed by this ADR. The hub-and-spoke model is for control plane only. Data-plane mesh (Istio ambient multicluster, Cilium Cluster Mesh) is a separate decision, deferred until two or more spokes actually host communicating services.
